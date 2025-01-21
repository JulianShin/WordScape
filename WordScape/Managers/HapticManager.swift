import UIKit

/// 햅틱 피드백을 관리하는 싱글톤 클래스
class HapticManager {
    static let shared = HapticManager()
    
    /// 가벼운 햅틱 피드백을 위한 제너레이터
    private let lightFeedbackGenerator = UIImpactFeedbackGenerator(style: .soft)
    /// 강한 햅틱 피드백을 위한 제너레이터
    private let heavyFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    private init() {
        lightFeedbackGenerator.prepare()
        heavyFeedbackGenerator.prepare()
    }
    
    /// 가벼운 햅틱 피드백을 재생
    func playLightHaptic() {
        lightFeedbackGenerator.impactOccurred()
    }
    
    /// 강한 햅틱 피드백을 재생
    func playHeavyHaptic() {
        heavyFeedbackGenerator.impactOccurred()
    }
} 
