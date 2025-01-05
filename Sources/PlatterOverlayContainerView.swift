//
//  PlatterContainerView.swift
//  dptest
//
//  Created by Andreas Verhoeven on 03/01/2025.
//

import UIKit

/// This view is the work-horse of our platter presentation: it hosts the platter,
/// determines where it comes and does hit-testing for pass thru.
///
/// We use AutoLayout, so that we can respond to changes in the `presentedView` size.
/// However, AutoLayout and AnchorPoints don't work nicely together (AutoLayout sets bounds
/// and center, which are affected by anchorPoints - frames do the calculation to fix this up).
///
/// The `platterView` has a custom anchor point set, so that the animation appears
/// from the right point. We need to manually compensate for this.
///
/// The way we do this currently is as follows (finding an easier set up would be nice)
///
/// - `platterView` is added and centered inside `contentView` using AutoLayout.
/// - in `layoutSubviews()` we calculate the position the platter __should__ be in
///   and the `anchorPoint` it should be using
/// - we then transform the `contentView` so that the `platterView` (still being centered in the `contentView`)
///   appears at the right position visually
/// - finally, we force the `platterView` to be in the center of the view because it's anchorPoint has been changed
///   and AutoLayout doesn't compensate for that.
///
/// Another approach we could use is to pin the `platterView` to its correct fixed position (taking everything into account)
/// using `AutoLayout`, but that quickly causes recursive layout cycles, because we do this in `layoutSubviews()`.
/// It's worth exploring in the future perhaps.
final class PlatterOverlayContainerView: UIView {
	let contentView = UIView()
	let platterView = PlatterView()
	let screenMargins = CGFloat(16)

	weak var presentation: PlatterOverlayPresentation?

	init(presentation: PlatterOverlayPresentation?) {
		self.presentation = presentation
		super.init(frame: .zero)

		addSubview(contentView, filling: .superview)
		contentView.addSubview(platterView, centeredIn: .superview)

		platterView.constrain(width: .atMost(sameAs: self, constant: -screenMargins), height: .atMost(sameAs: self, constant: -screenMargins))

		if let presentedView = presentation?.presentedView {
			platterView.contentView.addSubview(presentedView, filling: .superview)
		}

		NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func changePlatterContentView(from oldView: UIView, to newView: UIView, animated: Bool) {
		if animated == true {
			// animated: we need to take some measures to animate nicely:
			// we want to have the old view fade out and the new view fade it, while
			// the platter resizes to the new size. In order for the old view to not jump around,
			// we pin to the to top-leading of the blur-view so that it doesn't impact
			// the `contentView`s sizing and also is stable during animation.
			platterView.blurView.contentView.addSubview(oldView, pinnedTo: .topLeading)
			platterView.contentView.addSubview(newView, filling: .superview)

			// ensure layout is set
			platterView.contentView.layoutIfNeeded()
			platterView.blurView.contentView.layoutIfNeeded()

			newView.alpha = 0
			UIView.animate(withDuration: 0.35, animations: {
				oldView.alpha = 0
				newView.alpha = 1

				// we should not update the anchorpoint, because it messes up
				// the animation, because the new position will be a moving target due to
				// the anchorPoint changing - it's okay not to set it, because we'll
				// set it again during dismissal.
				self.canUpdateAnchorPoint = false
				self.setNeedsLayout()
				self.layoutIfNeeded()
				self.canUpdateAnchorPoint = true

			}, completion: { [weak self] _ in
				// animation done, remove the old view, but only if we're not
				// currently presenting it yet again.
				if self?.presentation?.presentedView !== oldView {
					oldView.removeFromSuperview()
				}
			})
		} else {
			// no animation, simply replace the view
			oldView.removeFromSuperview()
			platterView.contentView.addSubview(newView, filling: .superview)
		}
	}

	// MARK: - Privates
	private var canUpdateAnchorPoint = true
	var keyboardScreenFrame: CGRect?

	private var sourceViewFrame: CGRect {
		guard let sourceView = presentation?.sourceView else { return bounds }
		return sourceView.convert(presentation?.sourceRect ?? sourceView.bounds, to: self)
	}

	private var alignmentViewFrame: CGRect {
		guard let alignmentView = presentation?.alignmentView else { return sourceViewFrame }
		return alignmentView.convert(presentation?.alignmentRect ?? alignmentView.bounds, to: self)
	}

	private func adjustForSourceView() {
		if presentation?.sourceView == nil && presentation?.alignmentView == nil {
			// no source view, try to present in the middle of the screen
			platterView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
			contentView.transform = .identity

		} else {
			switch traitCollection.verticalSizeClass {
				case .unspecified: adjustForSourceViewVerticalRegular()
				case .compact: adjustForSourceViewVerticalCompact()
				case .regular: adjustForSourceViewVerticalRegular()
				@unknown default: adjustForSourceViewVerticalRegular()
			}
		}
	}

	private func adjustForSourceViewVerticalRegular() {
		guard let presentation else { return }

		let sourceViewFrame = self.sourceViewFrame
		let alignmentViewFrame = self.alignmentViewFrame
		let insettedBounds = bounds.inset(by: safeAreaInsets).insetBy(dx: screenMargins, dy: screenMargins)
		let platterHeight = platterView.contentView.bounds.height
		let platterWidth = platterView.contentView.bounds.width

		// our new center and anchor point, will be modified by the code below
		var newCenter = contentView.center
		var newAnchorPoint = CGPoint(x: 0.5, y: 0.5)

		// determine the horizontal center and anchor point based on settings
		let horizontalAlignmentViewFrame = alignmentViewFrame

		func trailing() -> CGFloat { horizontalAlignmentViewFrame.maxX - platterWidth * 0.5 }
		func leading() -> CGFloat { horizontalAlignmentViewFrame.minX + platterWidth * 0.5 }
		func center() -> CGFloat { horizontalAlignmentViewFrame.midX }

		newCenter.x = switch presentation.alignment {
			case .automatic: horizontalAlignmentViewFrame.midX <= bounds.width * 0.5 ? leading() : trailing()
			case .start: leading()
			case .center: center()
			case .end: trailing()
		}
		
		newCenter.x = max(newCenter.x, insettedBounds.minX + platterWidth * 0.5)
		newCenter.x = min(newCenter.x, insettedBounds.maxX - platterWidth * 0.5)
		newAnchorPoint.x = (sourceViewFrame.midX - (newCenter.x - platterWidth * 0.5)) / max(1, platterWidth)

		// determine the vertical center and anchor point based on where we have space to go to
		let verticalAlignmentViewFrame = alignmentViewFrame.insetBy(dx: -8, dy: -8) // add some spacing, so we don't "hug" the source view

		// these are possible locations of edges of the platter if we would extend the platter downwards or upwards
		let downwardsBottomPlatterEdge = verticalAlignmentViewFrame.maxY + platterHeight
		let upwardsTopPlatterEdge = verticalAlignmentViewFrame.minY - platterHeight

		// check what fits
		let fitsDownwards = (downwardsBottomPlatterEdge <= insettedBounds.maxY)
		let fitsUpwards = (upwardsTopPlatterEdge >= insettedBounds.minY)
		let isInUpperHalfOfScreen = sourceViewFrame.midY <= insettedBounds.midY

		// determine if we should go downwards. If it fits we go downwards, otherwise we go upwards if that fits.
		// If neither fits, then go downwards if we're in the upper half of the screen, otherwise upwards.
		let shouldGoDownwards = (fitsDownwards == true || (fitsUpwards == false && isInUpperHalfOfScreen == true))

		// calculate our new position and anchor point
		if shouldGoDownwards == true {
			let bottomEdge = min(downwardsBottomPlatterEdge, insettedBounds.maxY)
			newCenter.y = bottomEdge - platterHeight * 0.5
			newAnchorPoint.y = 0
		} else {
			let topEdge = max(upwardsTopPlatterEdge, insettedBounds.minY)
			newCenter.y = topEdge + platterHeight * 0.5
			newAnchorPoint.y = 1
		}

		if canUpdateAnchorPoint == false {
			newAnchorPoint = platterView.layer.anchorPoint
		}

		// adjust for keyboard if needed
		newCenter = adjustNewCenterForKeyboardAvoidance(newCenter, platterHeight: platterHeight)

		// set values - adjust the center to the new anchor point, since
		// we use a custom anchor point for the animation, our position
		// is also adjusted by that - so we take that into account
		newCenter.x -= (0.5 - newAnchorPoint.x) * platterWidth
		newCenter.y -= (0.5 - newAnchorPoint.y) * platterHeight

		contentView.transform = CGAffineTransform(translationX: newCenter.x - bounds.width * 0.5, y: newCenter.y - bounds.height * 0.5)
		platterView.layer.anchorPoint = newAnchorPoint
	}

	private func adjustNewCenterForKeyboardAvoidance(_ newCenter: CGPoint, platterHeight: CGFloat) -> CGPoint {
		guard let keyboardScreenFrame else { return newCenter }
		guard presentation?.shouldAvoidKeyboard == true else { return newCenter }
		guard presentation?.containerViewController?.isBeingDismissed == false else { return newCenter }

		let keyboardInOurFrame = convert(keyboardScreenFrame, from: nil)
		guard newCenter.y + platterHeight * 0.5 > keyboardInOurFrame.minY else { return newCenter }

		return CGPoint(x: newCenter.x, y: keyboardInOurFrame.minY - screenMargins - platterHeight * 0.5)

	}

	private func adjustForSourceViewVerticalCompact() {
		// THIS IS ESSENTIALLY A CLONE OF `adjustForSourceViewVerticalRegular` just with the
		// vertical and horizontal calculations inverted. Would be nice to consolidate this in the future.
		guard let presentation else { return }

		let sourceViewFrame = self.sourceViewFrame
		let alignmentViewFrame = self.alignmentViewFrame
		let insettedBounds = bounds.inset(by: safeAreaInsets).insetBy(dx: screenMargins, dy: screenMargins)
		let platterHeight = platterView.contentView.bounds.height
		let platterWidth = platterView.contentView.bounds.width

		// our new center and anchor point, will be modified by the code below
		var newCenter = contentView.center
		var newAnchorPoint = CGPoint(x: 0.5, y: 0.5)

		// determine the vertical center and anchor point based on settings
		let verticalAlignmentViewFrame = alignmentViewFrame

		func top() -> CGFloat { verticalAlignmentViewFrame.minY + platterHeight * 0.5 }
		func bottom() -> CGFloat { verticalAlignmentViewFrame.maxY - platterHeight * 0.5 }
		func center() -> CGFloat { verticalAlignmentViewFrame.midY }

		newCenter.y = switch presentation.alignment {
			case .automatic: verticalAlignmentViewFrame.midY <= bounds.height * 0.5 ? top() : bottom()
			case .start: top()
			case .center: center()
			case .end: bottom()
		}

		newCenter.y = max(newCenter.y, insettedBounds.minY + platterHeight * 0.5)
		newCenter.y = min(newCenter.y, insettedBounds.maxY - platterHeight * 0.5)
		newAnchorPoint.y = (sourceViewFrame.midY - (newCenter.y - platterHeight * 0.5)) / max(1, platterHeight)

		// determine the horizontal center and anchor point based on where we have space to go to
		let horizontalAlignmentViewFrame = alignmentViewFrame.insetBy(dx: -8, dy: -8) // add some spacing, so we don't "hug" the source view

		// these are possible locations of edges of the platter if we would extend the platter trailing or leading
		let trailingPlatterEdge = horizontalAlignmentViewFrame.maxX + platterWidth
		let leadingPlatterEdge = horizontalAlignmentViewFrame.minX - platterWidth

		// check what fits
		let fitsTrailing = (trailingPlatterEdge <= insettedBounds.maxX)
		let fitsLeading = (leadingPlatterEdge >= insettedBounds.minX)
		let isInLeadingHalfOfScreen = sourceViewFrame.midX <= insettedBounds.midX

		// determine if we should go trailing. If it fits we go trailing, otherwise we go leading if that fits.
		// If neither fits, then go trailing if we're in the leading half of the screen, otherwise leading.
		let shouldGoTrailing = (fitsTrailing == true || (fitsLeading == false && isInLeadingHalfOfScreen == true))

		// calculate our new position and anchor point
		if shouldGoTrailing == true {
			let trailingEdge = min(trailingPlatterEdge, insettedBounds.maxX)
			newCenter.x = trailingEdge - platterWidth * 0.5
			newAnchorPoint.x = 0
		} else {
			let leadingEdge = max(leadingPlatterEdge, insettedBounds.minX)
			newCenter.x = leadingEdge + platterWidth * 0.5
			newAnchorPoint.x = 1
		}

		if canUpdateAnchorPoint == false {
			newAnchorPoint = platterView.layer.anchorPoint
		}

		// adjust for keyboard if needed
		newCenter = adjustNewCenterForKeyboardAvoidance(newCenter, platterHeight: platterHeight)

		// set values - adjust the center to the new anchor point, since
		// we use a custom anchor point for the animation, our position
		// is also adjusted by that - so we take that into account
		newCenter.x -= (0.5 - newAnchorPoint.x) * platterWidth
		newCenter.y -= (0.5 - newAnchorPoint.y) * platterHeight

		contentView.transform = CGAffineTransform(translationX: newCenter.x - bounds.width * 0.5, y: newCenter.y - bounds.height * 0.5)
		platterView.layer.anchorPoint = newAnchorPoint
	}

	// MARK: Notifications
	@objc private func keyboardFrameWillChange(_ notification: Notification) {
		keyboardScreenFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero

		if presentation?.shouldAvoidKeyboard == true {
			let animationCurve = UIView.AnimationCurve(rawValue: (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? 0) ?? .easeInOut
			let animationDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0
			let animationCurveOptions = UIView.AnimationOptions(rawValue: UInt(animationCurve.rawValue) << 16)
			UIView.animate(withDuration: animationDuration, delay: 0, options: animationCurveOptions, animations: {
				self.setNeedsLayout()
				self.layoutIfNeeded()
			})
		}
	}

	// MARK: - UIView
	override func layoutSubviews() {
		super.layoutSubviews()

		platterView.layoutIfNeeded()
		adjustForSourceView()

		// override the center to always be in the middle - we use a transform on the contentview
		// to place it in the correct spot
		UIView.performWithoutAnimation {
			self.platterView.center = CGPoint(x: bounds.width * 0.5, y: bounds.height * 0.5)
		}
	}

	override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		guard
			let presentation,
			let presentingView = presentation.presentingView
		else {
			return super.hitTest(point, with: event)
		}

		// when the user taps on us (the transparent background view), we have three cases:
		// - it's inside of the platter view -> handle normally
		// - it's on the pass thru view location -> make it go to the pass thru view
		// - it's on us our our contentView -> handle like it's us
		let hitView = super.hitTest(point, with: event)
		guard hitView === contentView || hitView === self else {
			// we've hit something not us our the contentview, must be the platter view
			// so let the hit go there
			return hitView
		}

		// ask the presenting view what was hit
		let convertedPoint = presentingView.convert(point, from: self)
		guard let presentingViewHitView = presentingView.hitTest(convertedPoint, with: event) else {
			return self
		}

		// and if it's __not__ in the pass thru view, just assume it's us
		guard presentation.allPassThruViews.contains(where: { presentingViewHitView.isDescendant(of: $0) }) == true else {
			return self
		}

		// it's inside of the pass thrue view, let it go there
		return presentingViewHitView
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesEnded(touches, with: event)

		// someone touches the (transparent) background of our presentation, dismiss it!
		presentation?.dismiss(animated: true)
	}
}
