//
//  ContentView.swift
//  WordScape
//
//  Created by ChoongWhan Shin on 1/18/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()  // 뷰모델 인스턴스 생성
    @Environment(\.scenePhase) private var scenePhase  // 앱의 현재 상태를 추적
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 상단 바: 최고 점수와 일시정지 버튼
                HStack(alignment: .center, spacing: 51) {
					HStack {
						Text("Best")
							.font(Font.custom("Press Start 2P", size: 12))
							.foregroundColor(Color(red: 0.22, green: 0.29, blue: 0.32))
						Spacer()
						Text("\(UserDefaults.standard.integer(forKey: "BestScore"))")
							.font(Font.custom("Press Start 2P", size: 12))
							.foregroundColor(Color(red: 0.22, green: 0.29, blue: 0.32))
					}
					.frame(maxWidth: 120)
                    Button {
						withAnimation(.easeOut(duration: 0.3)) {
							viewModel.showPauseScreen = true
							viewModel.gameController.pauseGame()
						}
                    } label: {
						Image("pause")
                    }
                    .frame(width: 44, height: 44)
					Spacer()
						.frame(maxWidth: 120)
                }
                .padding(.horizontal, 16)
                .frame(height: 60, alignment: .leading)
                
                // 현재 점수와 생명력 표시
                HStack(alignment: .center, spacing: 0) {
					Text("\(viewModel.score)")
						.font(Font.custom("Press Start 2P", size: 12))
						.foregroundColor(Color(red: 0.22, green: 0.29, blue: 0.32))
						.frame(maxWidth: 120, alignment: .leading)
					Spacer()
					HStack {
						ForEach(0..<5, id: \.self) { index in
							Image("heart")
								.frame(width: 24, height: 24)
								.opacity(viewModel.lives < (5 - index) ? 0.5 : 1.0)
							if index < 4 {
								Spacer()
									.frame(width: 4)
							}
						}
					}
                }
                .padding(.horizontal, 16)
                .frame(height: 40, alignment: .center)
                
                // 게임 메인 화면
                ZStack {
                    GameViewControllerRepresentable(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.25))
                
                // 하단 바: 획득한 단어와 놓친 단어 표시
                HStack(spacing: 0) {
                    // 획득한 단어 영역
                    ZStack {
						CaptureWordsViewControllerRepresentable(viewModel: viewModel)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 197)
                    .background(Color(red: 0.5, green: 0.66, blue: 0.61))
                    
                    // 놓친 단어 영역
                    ZStack {
						LostWordsViewControllerRepresentable(viewModel: viewModel)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 197)
                    .background(Color(red: 0.99, green: 0.77, blue: 0.48))
                }
                .frame(height: 197)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.98, green: 0.95, blue: 0.84))
        }
        // 점수 변경 시 최고 점수 업데이트
        .onChange(of: viewModel.score) { newScore in
            let bestScore = UserDefaults.standard.integer(forKey: "BestScore")
            if newScore > bestScore {
                UserDefaults.standard.set(newScore, forKey: "BestScore")
            }
        }
        // 앱 상태 변경 감지 (백그라운드 전환 등)
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .inactive, .background:
				if !viewModel.showPauseScreen &&
					!viewModel.showStartScreen &&
					viewModel.lives > 0 &&
					viewModel.gameStatus != .end{
					viewModel.showPauseScreen = true
					viewModel.gameController.pauseGame()
				}
            default:
                break
            }
        }
		// 시작 화면 오버레이
		.overlay {
			if viewModel.showStartScreen {
				overlayView(title: "Word Scape", buttonImage: "play") {
					viewModel.showStartScreen = false
					viewModel.gameController.resetGame()
				}
			}
		}
		// 일시정지 화면 오버레이
		.overlay {
			if viewModel.showPauseScreen {
				VStack(alignment: .center, spacing: 100) {
					Spacer()
					Button {
						withAnimation(.easeOut(duration: 0.3)) {
							viewModel.showPauseScreen = false
							viewModel.gameController.resumeGame()
						}
					} label: {
						Image("play")
							.resizable()
							.frame(width: 100, height: 100)
					}
					
					Button {
						withAnimation(.easeOut(duration: 0.3)) {
							viewModel.showPauseScreen = false
							viewModel.gameController.resetGame()
						}
					} label: {
						Image("replay")
							.resizable()
							.frame(width: 100, height: 100)
					}
					Spacer()
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Color(red: 0.99, green: 0.77, blue: 0.48))
			}
		}
		// 게임 오버 화면 오버레이
		.overlay {
			if viewModel.lives <= 0 {
				overlayView(title: "Game Over", buttonImage: "replay") {
					viewModel.gameController.resetGame()
				}
			}
		}
		// 게임 종료 화면 오버레이
		.overlay {
			if viewModel.gameStatus == .end {
				overlayView(title: "End", buttonImage: "replay") {
					viewModel.gameController.resetGame()
				}
			}
		}
    }
	
	// 오버레이 뷰를 생성하는 헬퍼 함수
	private func overlayView(title: String?, buttonImage: String, action: @escaping () -> Void) -> some View {
		VStack(alignment: .center, spacing: 100) {
			if let title = title {
				Text(title)
					.font(Font.custom("Press Start 2P", size: 30))
					.foregroundColor(Color(red: 0.22, green: 0.29, blue: 0.32))
			}
			
			Button {
				withAnimation(.easeOut(duration: 0.3)) {
					action()
				}
			} label: {
				Image(buttonImage)
					.resizable()
					.frame(width: 100, height: 100)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(red: 0.99, green: 0.77, blue: 0.48))
	}
}

// UIKit의 GameViewController를 SwiftUI에서 사용하기 위한 래퍼
struct GameViewControllerRepresentable: UIViewControllerRepresentable {
	let viewModel: ViewModel
    
    func makeUIViewController(context: Context) -> GameViewController {
        return viewModel.gameController
    }
    
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {
    }
}

// 획득한 단어를 표시하는 BasketViewController를 SwiftUI에서 사용하기 위한 래퍼
struct CaptureWordsViewControllerRepresentable: UIViewControllerRepresentable {
	let viewModel: ViewModel
	
	func makeUIViewController(context: Context) -> BasketViewController {
		return viewModel.captureWordsController
	}
	
	func updateUIViewController(_ uiViewController: BasketViewController, context: Context) {
	}
}

// 놓친 단어를 표시하는 BasketViewController를 SwiftUI에서 사용하기 위한 래퍼
struct LostWordsViewControllerRepresentable: UIViewControllerRepresentable {
	let viewModel: ViewModel
	
	func makeUIViewController(context: Context) -> BasketViewController {
		return viewModel.lostWordsController
	}
	
	func updateUIViewController(_ uiViewController: BasketViewController, context: Context) {
	}
}
