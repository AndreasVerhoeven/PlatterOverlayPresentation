//
//  PlatterPresentation.swift
//  dptest
//
//  Created by Andreas Verhoeven on 03/01/2025.
//

import UIKit

/// A platter presentation presents another view on top of the current UI
/// inside a "platter", a rounded rect shadowed box.
///
/// The regular use case is to show larger inline controls from a smaller
/// control, such as a date-label that opens up a larger date picker.
///
/// The platter takes care of presentation and dismissal. You can get
/// notified when the platter has been dismissed by using the
/// `dismissalCallback`.
///
/// A platter presents the `presentedView` from the `sourceView`:
/// the platter will be below or above to the `sourceView`, depending
/// on available size. You can control the horizontal alignment with the
/// `alignment` parameter. In vertically small environments, the
/// platter is presented from the left or right of the `sourceView`
/// and the alignment option control the horizontal alignment.
///
/// For simple use cases use the static `present(_:from:animated:)`
/// to just present a view with a platter presentation.
///
/// For more complex use cases, you can also instantiate a
/// `PlatterPresentation` yourself and then call the
/// instance method `present(_:animated:)`. You can
/// call this even when the platter is presenting already, to change
/// the presented view in an animated fashion. You can use this to
/// switch between date and time pickers for example.
///
/// By default, the `sourceView` will be pass-thru:
/// taps on it will still be delivered even when the platter is
/// presented. You can control this with `isSourceViewPassThru`.
///
/// You can also register additional passthru views with `additionalPassThruViews`:
/// taps on these views will be delivered to the view itself, instead of dismissing the platter.
public final class PlatterPresentation {
	/// the view that's currently being presented.
	public private(set) var presentedView: UIView?

	/// the view were we are presenting from - weakly held. The presentation tries to present
	/// the platter closely to this view. If `nil` the platter will be presented in the middle of the screen.
	public weak var sourceView: UIView?

	/// the rect in sourceView coordinates we are presenting from - if nil, the bounds of
	/// sourceView will be used.
	public var sourceRect: CGRect?

	/// Alignment of the platter to the source view
	public enum Alignment {
		case automatic /// based on screen position
		case start /// align to the start - leading horizontally, top vertically
		case center /// align to the center
		case end /// align to the end - trailing horizontally, bottom vertically

		public static var leading: Self { .start }
		public static var trailing: Self { .end }

		public static var top: Self { .start }
		public static var bottom: Self { .end }
	}

	/// Determines how the platter is aligned to the source view:
	/// In a vertically compact environment (e.g. a rotated iPhone) - the platter will be presented
	/// horizontally next to the `sourceView` and the alignment determines if we align to the top, center or bottom
	/// edge vertically.
	/// In a vertical regular environment the platter will be presented vertically above/below the `sourceView`
	/// and the alignment determines if we align to the leading, center or trailing edge vertically.
	/// If no `sourceView` is set, the platter will be center presented.
	public var alignment = Alignment.automatic

	/// if `true` the platter position is adjusted to avoid the keyboard
	public var shouldAvoidKeyboard = true

	/// Callback that will be called when the platter is dismissed
	public var dismissalCallback: (() -> Void)?

	/// if `true`, the source view will receive touches
	public var isSourceViewPassThru = true

	/// Additional views (in the presenting views hierarchy) that should receive touches
	public var additionalPassThruViews = [UIView]()

	/// true if the platter is being presented.
	public var isPresented: Bool { containerViewController != nil }

	/// This is a helper function that quickly presents a view as a platter.
	///
	/// - Parameters:
	/// - view: the view
	///
	/// - Return: the `PlatterPresentation` doing the presenting if something is presented. Can safely be ignored if you don't need it
	@discardableResult public static func present(
		_ view: UIView,
		from: UIView?,
		rect: CGRect? = nil,
		alignment: Alignment = .automatic,
		animated: Bool,
		callback: (() -> Void)? = nil
	) -> PlatterPresentation? {
		let presentation = PlatterPresentation(sourceView: from, sourceRect: rect)
		presentation.alignment = alignment
		presentation.dismissalCallback = callback
		presentation.present(view, animated: animated)
		return presentation.isPresented ? presentation : nil
	}

	/// Presents a view using the `PlatterPresentation`'s configuration. If a view is already being presented,
	/// the current platter will be reused and - in case `animated == true`, smoothly animate to the new view.
	public func present(_ presentedView: UIView, animated: Bool) {
		if isPresented == true {
			guard let oldPresentedView = self.presentedView else { return }
			containerViewController?.changePlatterContentView(from: oldPresentedView, to: presentedView, animated: animated)
			self.presentedView = presentedView
		} else {
			guard let nearestViewController = sourceView?.nearestViewController else {
				assert(false, "Cannot present platter: sourceView needs to be part of a view controller hierarchy")
				// fire the dismissal callback, so caller can do UI clean up if needed (e.g. reset highlighting)
				dismissalCallback?()
				return
			}

			self.presentedView = presentedView

			let controller = PlatterContainerViewController(platterPresentation: self)
			controller.modalPresentationStyle = .overFullScreen
			controller.transitioningDelegate = controller
			containerViewController = controller
			nearestViewController.present(controller, animated: animated)

		}
	}

	/// dismisses a presentation. If there's no active presentation, does nothing.
	public func dismiss(animated: Bool) {
		guard isPresented == true else { return }
		containerViewController?.dismiss(animated: animated)
	}

	/// Creates a new PlatterPresentation
	public convenience init(sourceView: UIView? = nil, sourceRect: CGRect? = nil) {
		self.init()
		self.sourceView = sourceView
		self.sourceRect = sourceRect
	}

	// MARK: - UIViewController
	internal var containerViewController: PlatterContainerViewController? {
		didSet {
			if containerViewController == nil {
				presentedView = nil
			}
		}
	}

	internal var presentingView: UIView? {
		return containerViewController?.presentingViewController?.view
	}

	internal var allPassThruViews: [UIView] {
		guard isSourceViewPassThru == true else { return additionalPassThruViews }
		guard let sourceView else { return additionalPassThruViews }
		return additionalPassThruViews + [sourceView]
	}
}

fileprivate extension UIResponder {
	var nearestViewController: UIViewController? {
		var responder = next
		while let current = responder, (current is UIViewController) == false {
			responder = current.next
		}
		return responder as? UIViewController
	}
}
