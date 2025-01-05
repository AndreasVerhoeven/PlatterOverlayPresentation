//
//  PlatterView.swift
//  dptest
//
//  Created by Andreas Verhoeven on 02/01/2025.
//

import UIKit
import AutoLayoutConvenience

final class PlatterView: UIView {
	let shadowView = CutoutShadowView()
	let clipView = UIView()
	let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
	let contentView = UIView()

	let collapsedHeight = CGFloat(50)
	let collapsedScale = CGFloat(0.2)

	func collapse(animated: Bool, completion: (() -> Void)? = nil) {
		animateIfNeeded(animated: animated, animations: {
			self.clipView.activeConditionalConstraintsConfigurationName = .collapsed
			self.transform = CGAffineTransform(scaleX: self.collapsedScale, y: self.collapsedScale)
			self.shadowView.alpha = 0
			self.alpha = 0
		}, completion: completion)
	}

	func expand(animated: Bool, completion: (() -> Void)? = nil) {
		animateIfNeeded(animated: animated, animations: {
			self.clipView.activeConditionalConstraintsConfigurationName = .expanded
			self.transform = .identity
			self.shadowView.alpha = self.alphaForShadowViewWhenExpanded
			self.alpha = 1
		}, completion: completion)
	}

	// MARK: - Privates
	private func animateIfNeeded(animated: Bool, animations: @escaping () -> Void, completion: (() -> Void)? = nil) {
		if animated == true {
			UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut, animations: animations, completion: { _ in
				completion?()
			})
		} else {
			animations()
			completion?()
		}
	}

	private var alphaForShadowViewWhenExpanded: CGFloat {
		switch traitCollection.userInterfaceStyle {
			case .unspecified: return 0.21
			case .light: return 0.21
			case .dark: return 0.6
			@unknown default: return 0.21
		}
	}

	// MARK: - UIView
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)

		guard shadowView.alpha != 0 else { return }
		shadowView.alpha = alphaForShadowViewWhenExpanded
	}

	override init(frame: CGRect) {
		super.init(frame: frame)

		constrain(widthAndHeight: .atLeast(shadowView.minimumSize))

		clipView.clipsToBounds = true
		clipView.layer.cornerRadius = shadowView.cornerRadius
		clipView.layer.cornerCurve = .circular

		addSubview(NonAutoLayoutWrappingView(view: shadowView), filling: .superview, insets: .all(-shadowView.shadowSize))

		addSubview(clipView, filling: .superview)
		clipView.addSubview(blurView, filling: .superview)

		blurView.contentView.addSubview(contentView, pinnedTo: .top)

		UIView.addNamedConditionalConfiguration(.expanded) {
			clipView.constrain(height: .exactly(sameAs: contentView))
		}

		UIView.addNamedConditionalConfiguration(.collapsed) {
			clipView.constrain(height: collapsedHeight)
		}

		expand(animated: false)

		//collapse(animated: false)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
