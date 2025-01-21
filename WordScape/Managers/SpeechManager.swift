import Speech
import AVFoundation
import Combine

class SpeechManager: NSObject, @unchecked Sendable {
    // MARK: - Properties
     private let recognizedWordSubject = PassthroughSubject<String, Never>()
    var recognizedWordPublisher: AnyPublisher<String, Never> {
        recognizedWordSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Speech Recognition 관련 프로퍼티
    // 텍스트를 음성으로 변환하는 신디사이저
    private let synthesizer = AVSpeechSynthesizer()
    // 영어(미국) 음성 인식기 초기화
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    // 음성 인식 요청 객체
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    // 음성 인식 작업 객체
    private var recognitionTask: SFSpeechRecognitionTask?
    // 오디오 처리를 위한 엔진
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    override init() {
        super.init()
        synthesizer.delegate = self
        startTTS() // TTS(Text-to-Speech) 초기화
        startSTT() // STT(Speech-to-Text) 초기화
    }
    
    // MARK: - TTS Methods
    // TTS 시스템 초기화 (무음으로 시작하여 시스템 준비)
    private func startTTS() {
        let utterance = AVSpeechUtterance(string: "initialize")
        utterance.volume = 0.0
        synthesizer.speak(utterance)
    }
    
    // 주어진 단어를 음성으로 변환하여 재생
    func speakWord(_ word: String) {
        guard !word.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 1.0
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
    
    // MARK: - STT Methods
    // 음성 인식 시작 및 권한 요청
    private func startSTT() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            switch status {
            case .authorized:
                do {
                    try self.startRecording()
                } catch {
                    print("Speech recognition failed to start: \(error.localizedDescription)")
                }
            case .denied:
                print("Speech recognition permission denied")
            case .restricted:
                print("Speech recognition restricted on this device")
            case .notDetermined:
                print("Speech recognition not yet authorized")
            @unknown default:
                print("Unknown authorization status")
            }
        }
    }
    
    // 실제 음성 인식 녹음 시작
    private func startRecording() throws {
        stopRecording() // 기존 녹음 중지
        
        // 오디오 세션 설정
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
        try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
        
        // 음성 인식 요청 객체 생성
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // 오디오 입력 노드 설정
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // 오디오 엔진 시작
        audioEngine.prepare()
        try audioEngine.start()
        
        // 음성 인식 작업 시작
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if error != nil {
                self?.stopRecording()
                return
            }
            
            // 인식된 단어를 Publisher를 통해 전달
            if let word = result?.bestTranscription.segments.last?.substring {
                self?.recognizedWordSubject.send(word)
            }
        }
    }
    
    // 녹음 중지 및 리소스 정리
    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension SpeechManager: AVSpeechSynthesizerDelegate {
    // TTS 발화 시작 시 음성 인식 일시 중지
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        audioEngine.pause()
    }
    
    // TTS 발화 완료 시 음성 인식 재개
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        do {
            try audioEngine.start()
        } catch {
            print("Failed to restart audio engine: \(error.localizedDescription)")
        }
    }
} 
