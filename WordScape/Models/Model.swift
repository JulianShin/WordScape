/// 게임 상태
enum GameStatus {
	case playing, pause, stop, end
}

/// 게임 난이도
enum Difficulty {
	case easy, normal, hard
	
	var wordSpeed: Double {
		switch self {
		case .easy: return 8
		case .normal: return 4
		case .hard: return 2
		}
	}
	
	var generationInterval: Double {
		switch self {
		case .easy: return 1
		case .normal: return 0.5
		case .hard: return 0.25
		}
	}
}
