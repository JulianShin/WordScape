//
//  BasketViewController.swift
//  WordScape
//
//  Created by ChoongWhan Shin on 1/20/25.
//

import UIKit

/// 단어들이 중력에 의해 떨어지는 애니메이션을 구현하는 뷰 컨트롤러 (캡쳐 및 탈출 단어 표시용)
class BasketViewController: UIViewController {
	/// 화면에 표시되는 단어 레이블들을 저장하는 배열
	var words: [UILabel] = []
	
	/// UIKit Dynamics 애니메이션을 관리하는 객체
	var itemsAnimator: UIDynamicAnimator?

	/// 중력 효과를 적용하는 behavior
	var gravityBehavior = UIGravityBehavior()
	
	/// 경계면과의 충돌을 처리하는 behavior
	var collisionBehavior: UICollisionBehavior = {
		let collisionBehavior = UICollisionBehavior()
		collisionBehavior.translatesReferenceBoundsIntoBoundary = true // 뷰의 경계를 충돌 경계로 설정
		return collisionBehavior
	}()
	   
	/// 물리적 속성(탄성)을 정의하는 behavior
	var dynamicItemBehavior: UIDynamicItemBehavior = {
		let dynamicItemBehavior = UIDynamicItemBehavior()
		dynamicItemBehavior.elasticity = 0.2
		return dynamicItemBehavior
	}()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.clipsToBounds = true
		// 애니메이터 초기화 및 behavior 추가
		itemsAnimator = UIDynamicAnimator(referenceView: view)
		itemsAnimator?.addBehavior(gravityBehavior)
		itemsAnimator?.addBehavior(collisionBehavior)
		itemsAnimator?.addBehavior(dynamicItemBehavior)
	}
	
	/// 새로운 단어들을 화면에 추가하는 메서드
	/// - Parameter words: 추가할 단어 문자열 배열
	func addWords(_ words: [String]) {
		// 빈 배열이 전달되면 모든 단어를 제거 (초기화용)
		if words.isEmpty {
			self.words.forEach {
				gravityBehavior.removeItem($0)
				collisionBehavior.removeItem($0)
				dynamicItemBehavior.removeItem($0)
				$0.removeFromSuperview()
			}
			self.words = []
			return
		}
		
		// 새로운 단어들을 추가
		for word in words {
			// 이미 존재하는 단어는 건너뜀
			if !self.words.map({ $0.text }).contains(word) {
				// 단어를 표시할 레이블 생성 및 설정
				let label = UILabel()
				label.backgroundColor = .white
				label.font = UIFont.systemFont(ofSize: 10)
				label.textColor = .black
				label.textAlignment = .center
				label.text = word
				label.layer.cornerRadius = 4
				label.layer.masksToBounds = true
				
				// 레이블 크기 계산 및 위치 설정
				let size = label.intrinsicContentSize
				label.frame = CGRect(
					origin: CGPoint(x: CGFloat.random(in: 0...(view.frame.width - size.width + 4)), y: 0),
					size: CGSizeMake(size.width + 4, size.height + 4)
				)
				
				// 레이블을 뷰에 추가하고 애니메이션 behavior 적용
				view.addSubview(label)
				self.words.append(label)
				
				gravityBehavior.addItem(label)
				collisionBehavior.addItem(label)
				dynamicItemBehavior.addItem(label)
			}
		}
	}
}
