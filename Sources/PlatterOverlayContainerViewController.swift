//
//  PlatterOverlayContainerViewController.swift
//  dptest
//
//  Created by Andreas Verhoeven on 03/01/2025.
//

import UIKit

/// This view controller is presented "with" animation, so that keyboards are
/// properly animated, but it's duration is 0, so that we immediately get displayed.
/// We drive the animation in viewDidAppear() and viewWillDisappear(),
/// so that we can actually have easily interruptable animations - when disappearing,
/// we move the "animation" view to the window while it animates the disappearance.
final class PlatterOverlayContainerViewController: UIViewController {
	private(set) lazy var platterView = PlatterView()
	private let presentation: PlatterOverlayPresentation

	init(presentation: PlatterOverlayPresentation) {
		self.presentation = presentation
		super.init(nibName: nil, bundle: nil)
	}
	
	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func changePlatterContentView(from oldView: UIView, to newView: UIView, animated: Bool) {
		containerView.changePlatterContentView(from: oldView, to: newView, animated: animated)
	}

	// MARK: - Privates
	private var containerView: PlatterOverlayContainerView! { view as? PlatterOverlayContainerView }

	// MARK: - UIViewController
	override func loadView() {
		view = PlatterOverlayContainerView(presentation: presentation)
	}

	override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		guard isBeingPresented == false else { return }

		// new size: dismiss
		presentation.dismiss(animated: false)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		// we're there - start of collapsed and layout, then expand
		containerView.platterView.collapse(animated: false)
		containerView.layoutIfNeeded()
		containerView.platterView.expand(animated: animated)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		if animated == true, let window = view.window {
			// we are disappearing - get the contentView from our container
			// and move that to the window, so we can animate the disappearance
			// while this controller is already gone: this way
			// we have easy interruptable animations
			containerView.setNeedsLayout()
			containerView.layoutIfNeeded()

			let contentView = containerView.contentView
			contentView.isUserInteractionEnabled = false
			window.addSubview(containerView.contentView, filling: .superview)
			containerView.platterView.collapse(animated: true) {
				contentView.removeFromSuperview()
			}
		}
		
		presentation.containerViewController = nil
		presentation.dismissalCallback?()
	}

	// MARK: - UIResponder
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		if presses.contains(where: { $0.key?.keyCode == .keyboardEscape }) {
			presentation.dismiss(animated: true)
		}
	}
}


extension PlatterOverlayContainerViewController: UIViewControllerTransitioningDelegate {
	func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
		return self
	}

	func animationController(forDismissed dismissed: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
		return self
	}
}

extension PlatterOverlayContainerViewController: UIViewControllerAnimatedTransitioning {
	func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
		if let view = transitionContext.view(forKey: .to), let controller = transitionContext.viewController(forKey: .to) {
			view.frame = transitionContext.finalFrame(for: controller)
			transitionContext.containerView.addSubview(view)
		}
		transitionContext.completeTransition(true)
	}

	func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
		return 0
	}
}
