import Foundation
import Combine

class ViewModel: ObservableObject {
	@Published var gameStatus: GameStatus = .stop
	@Published var score: Int = 0
	@Published var lives: Int = 5
	@Published var capturedWords: [String] = []
	@Published var lostWords: [String] = []
	@Published var showStartScreen: Bool = true
	@Published var showPauseScreen: Bool = false
	
	let gameController = GameViewController()
	let captureWordsController = BasketViewController()
	let lostWordsController = BasketViewController()
	
	private var cancellables = Set<AnyCancellable>()
	
	init() {
		setupSubscriptions()
	}
	
	private func setupSubscriptions() {
		// 게임 상태 관련 구독 설정
		// GameViewController의 상태 변경사항을 메인 스레드에서 처리
		gameController.statusPublisher
			.receive(on: DispatchQueue.main)
			.assign(to: \.gameStatus, on: self)
			.store(in: &cancellables)
			
		// 점수 업데이트 구독 설정
		gameController.scorePublisher
			.receive(on: DispatchQueue.main)
			.assign(to: \.score, on: self)
			.store(in: &cancellables)
			
		// 남은 생명 업데이트 구독 설정
		gameController.livesPublisher
			.receive(on: DispatchQueue.main)
			.assign(to: \.lives, on: self)
			.store(in: &cancellables)
			
		// 포획한 단어 목록 업데이트 및 BasketViewController에 추가
		gameController.capturedWordsPublisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self] words in
				self?.capturedWords = words
				self?.captureWordsController.addWords(words)
			}
			.store(in: &cancellables)
			
		// 놓친 단어 목록 업데이트 및 BasketViewController에 추가
		gameController.lostWordsPublisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self] words in
				self?.lostWords = words
				self?.lostWordsController.addWords(words)
			}
			.store(in: &cancellables)
	}
}
