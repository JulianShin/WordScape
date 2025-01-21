import UIKit
import Combine

class GameViewController: UIViewController {
    // MARK: - Properties
    // 게임의 상태를 관리하는 Subject들
	// 게임 상태
    private let status = CurrentValueSubject<GameStatus, Never>(.stop)
	// 난이도
    private let difficulty = CurrentValueSubject<Difficulty, Never>(.easy)
	// 점수
    private let score = CurrentValueSubject<Int, Never>(0)
	// 라이프
    private let lives = CurrentValueSubject<Int, Never>(5)
	// 캡처된 단어
    private let capturedWords = CurrentValueSubject<[String], Never>([])
	// 탈출한 단어
    private let lostWords = CurrentValueSubject<[String], Never>([])
	
	// Public read-only publishers
	var statusPublisher: AnyPublisher<GameStatus, Never> { status.eraseToAnyPublisher() }
	var scorePublisher: AnyPublisher<Int, Never> { score.eraseToAnyPublisher() }
	var livesPublisher: AnyPublisher<Int, Never> { lives.eraseToAnyPublisher() }
	var capturedWordsPublisher: AnyPublisher<[String], Never> { capturedWords.eraseToAnyPublisher() }
	var lostWordsPublisher: AnyPublisher<[String], Never> { lostWords.eraseToAnyPublisher() }
	
	// 단어 배열
	private var words: [String] = []
	// 레인 배열
	private var lanes: [UIView] = []
	// 이동 중인 레이블 배열
	private var movingLabels: [UIView] = []
	// 게임 타이머
	private var gameTimer: Timer?
	
	// 음성 인식 관리자
	private let speechManager = SpeechManager()
	// 구독 관리자
	private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSpeechSubscription()
    }
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		// 레인이 아직 설정되지 않았을 때만 setupLanes 호출
		if lanes.isEmpty {
			setupLanes()
		}
	}
    
	// 뷰의 높이에 따라 가능한 레인 개수 계산 후 설정
    private func setupLanes() {
		let availableHeight = view.bounds.height
		let laneHeight = 70.0
		let numberOfLanes = max(3, Int(floor(availableHeight / laneHeight)))
		
        // 계산된 레인 개수만큼 생성
        for i in 0..<numberOfLanes {
            let lane = UIView()
            lane.backgroundColor = .clear
            view.addSubview(lane)
            lanes.append(lane)
            
            lane.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                lane.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                lane.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                lane.heightAnchor.constraint(equalToConstant: 60),
                lane.topAnchor.constraint(equalTo: view.topAnchor, constant: CGFloat(i) * laneHeight)
            ])
        }
    }
	
	// MARK: - Game Setup
	/// 게임을 초기 상태로 리셋하는 메서드
	func resetGame() {
		words = [
			"Apple", "Ball", "Cat", "Dog", "Fish",
			"Sun", "Moon", "Star", "Book", "Chair",
			"Duck", "Frog", "King", "Queen", "Milk",
			"Bread", "Egg", "Tree", "Cloud", "Rain",
			"Snow", "Grass", "Fire", "Water", "Rock",
			"Bird", "Goat", "Sheep", "Horse", "Lion",
			"Tiger", "Mouse", "Bee", "Ant", "Crab",
			"Wolf", "Snake", "Train", "Plane", "Boat",
			"House", "Door", "Window", "Road", "River",
			"Park", "Beach", "Hill", "Light", "Night"
		]
		capturedWords.send([])
		lostWords.send([])
		score.send(0)
		lives.send(5)
		difficulty.send(.easy)
		
		movingLabels.forEach { $0.removeFromSuperview() }
		movingLabels = []
		
		changeGameState(.playing)
	}
	
	// MARK: - Game Control
	/// 게임을 일시정지하고 현재 진행 중인 애니메이션의 상태를 저장
	private struct AnimationState {
		let translateX: CGFloat
		let remainingTime: TimeInterval
	}
	
	private var animationStates: [UIView: AnimationState] = [:]
	
	func pauseGame() {
		changeGameState(.pause)
		
		for label in movingLabels {
			if let presentation = label.layer.presentation() {
				// CATransform3D를 CGAffineTransform으로 변환
				let transform = CATransform3DGetAffineTransform(presentation.transform)
				let translateX = transform.tx
				
				// 남은 시간 계산
				let remainingDistance = view.frame.width + label.frame.width - translateX
				let fullDistance = view.frame.width + label.frame.width
				let remainingTime = (remainingDistance / fullDistance) * difficulty.value.wordSpeed
				
				// 상태 저장
				animationStates[label] = AnimationState(translateX: translateX,
														remainingTime: remainingTime)
				
				// 현재 애니메이션 중지
				label.layer.removeAllAnimations()
				// 현재 위치 유지
				label.transform = CGAffineTransform(translationX: translateX, y: 0)
			}
		}
	}
	
	/// 저장된 애니메이션 상태를 기반으로 게임을 재개
	func resumeGame() {
		changeGameState(.playing)
		
		for label in movingLabels {
			// 이미 애니메이션이 있다면 건너뛰기
			guard label.layer.animation(forKey: "transform") == nil,
				  let state = animationStates[label] else { continue }
			
			// 저장된 transform 위치 적용
			label.transform = CGAffineTransform(translationX: state.translateX, y: 0)
			
			// 새 애니메이션 시작
			UIView.animate(withDuration: state.remainingTime, delay: 0, options: .curveLinear) {
				label.transform = CGAffineTransform(translationX: self.view.frame.width + label.frame.width, y: 0)
			} completion: { [weak self] success in
				guard let self = self,
					  success else { return }
				self.escapedWord(label as! UILabel)
			}
		}
		
		animationStates.removeAll()
	}
	
	/// 게임 상태를 변경하고 단어 생성 타이머 시작 여부 결정
	func changeGameState(_ status: GameStatus) {
		self.status.send(status)
		
		if status == .playing {
			startWordGeneration()
		} else {
			gameTimer?.invalidate()
		}
	}
	
	// MARK: - Word Generation
	/// 설정된 난이도에 따라 단어 생성 타이머 시작
	private func startWordGeneration() {
		gameTimer?.invalidate()
		gameTimer = Timer.scheduledTimer(withTimeInterval: difficulty.value.generationInterval, repeats: true) { [weak self] timer in
			guard let self = self else { return }
			generateWord()
		}
	}
	
	/// 새로운 단어를 생성하고 화면에 표시
	private func generateWord() {
		guard let randomWord = words.randomElement(),
			  let randomLane = lanes.filter({ $0.subviews.isEmpty }).randomElement() else { return }
		
		words.removeAll { word in
			word == randomWord
		}
		
		let label = UILabel()
		label.text = randomWord
		label.textAlignment = .center
		label.backgroundColor = .white
		label.isUserInteractionEnabled = false
		label.clipsToBounds = true
		label.layer.cornerRadius = 10
		randomLane.addSubview(label)
		
		let width = label.intrinsicContentSize.width + 20
		
		label.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			label.widthAnchor.constraint(equalToConstant: width),
			label.heightAnchor.constraint(equalToConstant: 30),
			label.centerYAnchor.constraint(equalTo: randomLane.centerYAnchor),
			label.leadingAnchor.constraint(equalTo: randomLane.leadingAnchor, constant: -width)
		])
		
		movingLabels.append(label)
		
		// 화면 왼쪽 끝에서 오른쪽으로 이동하는 애니메이션 시작
		UIView.animate(withDuration: difficulty.value.wordSpeed, delay: 0, options: .curveLinear) {
			label.transform = CGAffineTransform(translationX: self.view.frame.width + width, y: 0)
		} completion: { [weak self] success in
			guard let self = self, success else { return }
			escapedWord(label)
		}
	}
	
	/// 터치시 뷰의 서브뷰 중 터치된 레이블을 캡처
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = touches.first else { return }
		
		let location = touch.location(in: view)
		
		for label in movingLabels {
			guard let label = label as? UILabel,
				  let lane = label.superview,
				  let presentationLayer = label.layer.presentation() else { continue }
			
			let layerFrame  = presentationLayer.frame
			let frame = lane.convert(layerFrame, to: view)
			
			if frame.contains(location) {
				captureWord(label)
				break
			}
		}
	}
	
	// MARK: - Word Handling
	/// 사용자가 성공적으로 단어를 캡처했을 때 호출
	private func captureWord(_ label: UILabel) {
		HapticManager.shared.playLightHaptic()
		
		guard let word = label.text else { return }
		capturedWords.send(capturedWords.value + [word])
		
		updateScore()
		
		UIView.animate(withDuration: 0.3) {
			label.alpha = 0
		} completion: { [weak self] success in
			guard let self = self, success else { return }
			checkWordIsLeft(label)
		}
	}
	
	/// 단어가 화면을 벗어났을 때 호출
	private func escapedWord(_ label: UILabel) {
		HapticManager.shared.playHeavyHaptic()
		
		guard let word = label.text, movingLabels.contains(label) else { return }
		lostWords.send(lostWords.value + [word])
		
		speechManager.speakWord(word)
		loseLife()
		checkWordIsLeft(label)
	}
	
	// MARK: - Life Management
	/// 라이프를 1 감소시키고 게임 오버 조건을 확인
	private func loseLife() {
		lives.send(lives.value - 1)
		if lives.value <= 0 {
			gameOver()
		}
	}
	
	// MARK: - Game Over
	/// 게임 오버 상태로 전환하고 현재 진행 중인 애니메이션을 일시정지
	private func gameOver() {
		changeGameState(.stop)
		
		for label in movingLabels {
			let pausedTime = label.layer.convertTime(CACurrentMediaTime(), from: nil)
			label.layer.speed = 0.0
			label.layer.timeOffset = pausedTime
		}
	}
	
	// MARK: - Score Management
	/// 점수를 10점 증가시키고 난이도를 업데이트
	private func updateScore() {
		score.send(score.value + 10)
		updateDifficulty()
	}
	
	// MARK: - Difficulty Management
	/// 점수에 따라 난이도를 업데이트
	private func updateDifficulty() {
		switch score.value {
		case 100...:
			difficulty.send(.hard)
		case 50...:
			difficulty.send(.normal)
		default:
			difficulty.send(.easy)
		}
	}
	
	// MARK: - Word Removal
	/// 화면에서 단어를 제거하고 게임 종료 조건을 확인
	private func checkWordIsLeft(_ label: UILabel) {
		label.removeFromSuperview()
		movingLabels.removeAll { removeLabel in
			removeLabel == label
		}
		
		if movingLabels.isEmpty && words.isEmpty {
			changeGameState(.end)
		}
	}
	
	// MARK: - Speech Subscription
	/// 음성 인식 결과 처리용 구독 설정
    private func setupSpeechSubscription() {
        speechManager.recognizedWordPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] word in
                self?.handleRecognizedSpeech(word)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Speech Recognition
    /// 음성 인식 결과를 처리하는 메서드
    private func handleRecognizedSpeech(_ text: String) {
        for label in movingLabels {
            guard let label = label as? UILabel,
                  let word = label.text?.lowercased(),
                  text.lowercased() == word else { continue }
            captureWord(label)
        }
    }
}
