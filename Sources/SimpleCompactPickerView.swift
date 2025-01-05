//
//  SimpleCompactPickerView.swift
//  PlatterPresentationTest
//
//  Created by Andreas Verhoeven on 05/01/2025.
//

import UIKit

/// This is a control that is a compact picker, like the compact `UIDatePicker` style:
/// it shows a button with the current selection and if tapped, will show an overlay with a
/// `UIPickerView` with all the options.
/// It's a generic class: the items you provide can be anything - you only need to provide a stringProvider
/// to turn them into strings.
public class SimpleCompactPickerView<Item>: UIControl, UIPickerViewDataSource, UIPickerViewDelegate {
	let contentView = UIView()
	let backgroundView = UIView(backgroundColor: .secondarySystemFill)
	let titleLabel = UILabel(font: UIFont.preferredFont(forTextStyle: .body), alignment: .center, numberOfLines: 1)
	let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.up.chevron.down"), contentMode: .scaleAspectFit)

	/// if true, we'll show a chevron next to the title
	public var showsChevron: Bool {
		get { chevronImageView.isHidden == false }
		set { chevronImageView.isHidden = (newValue == false) }
	}

	/// the items the user can pick from
	public var items: [Item] {
		get { _items }
		set {  setItems(newValue, animated: false) }
	}

	/// the selectedIndex of the item - if `nil` there's no selection.
	public 	var selectedIndex: Int? {
		get { _selectedIndex }
		set {
			setItems(_items, selectedIndex: newValue, animated: false)
		}
	}

	/// turns items into strings. If not provided, will try to display a string
	/// version of the item by looking if the items are `String` or `CustomStringConvertible`.
	public var stringProvider: ((Item) -> String)?

	/// the title that is shown when there's no selection
	public var noSelectionTitle = " " {
		didSet {
			update(animated: false)
		}
	}

	/// helper that returns the select item
	public var selectedItem: Item? {
		guard let selectedIndex else { return nil }
		return items[selectedIndex]
	}

	/// Sets new items - will keep the `selectedIndex` the same, unless it's out of bounds.
	public func setItems(_ items: [Item], animated: Bool) {
		setItems(items, selectedIndex: selectedIndex, animated: animated)
	}

	/// Sets new items and a new `selectedIndex` at the same time.
	public func setItems(_ items: [Item], selectedIndex: Int?, animated: Bool) {
		var newSelectedIndex = selectedIndex
		if let selectedIndex {
			if items.isEmpty == true {
				newSelectedIndex = nil
			} else {
				newSelectedIndex = min(max(0, selectedIndex), items.count - 1)
			}
		}

		_items = items
		_selectedIndex = newSelectedIndex
		update(animated: animated)

		if presentation?.isPresented == true {
			guard let pickerView = presentation?.sourceView as? UIPickerView else { return }
			pickerView.reloadAllComponents()
			if let newSelectedIndex {
				pickerView.selectRow(newSelectedIndex, inComponent: 0, animated: animated)
			}
		}
	}

	/// triggers the overlay to show
	public func showOverlay(animated: Bool) {
		guard (presentation?.isPresented ?? false) == false else { return }
		presentOverlay(animated: animated)
	}

	/// hides any visible overlays
	public func hideOverlay(animated: Bool) {
		dismissOverlay(animated: animated)
	}

	// MARK: - UIPickerViewDataSource
	public func numberOfComponents(in pickerView: UIPickerView) -> Int {
		return 1
	}

	public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return items.count
	}

	public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return stringForItemAtIndex(row)
	}

	// MARK: - UIPickerViewDelegate
	public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		_selectedIndex = row
		update(animated: false)
		sendActions(for: .valueChanged)
	}

	// MARK: - Internal
	internal var updateCallback: ((Bool) -> Void)?

	// MARK: - Privates
	private var presentation: PlatterOverlayPresentation?
	private var _items = [Item]()
	private var _selectedIndex: Int?

	private func updateColors() {
		if isEnabled == true {
			backgroundView.alpha = (isHighlighted == true ? 0.5 : 1)
			titleLabel.textColor = ((isSelected == true || presentation?.isPresented == true) ? tintColor : .label)
		} else {
			backgroundView.alpha = 0.25
			titleLabel.textColor = .label
		}
	}

	private func stringForItemAtIndex(_ index: Int) -> String? {
		let item = items[index]
		
		if let stringProvider {
			return stringProvider(item)
		} else if let string = item as? String {
			return string
		} else {
			return (item as? CustomStringConvertible)?.description
		}
	}

	private func update(animated: Bool) {
		let newLabel: String?
		if let selectedIndex {
			let string = stringForItemAtIndex(selectedIndex)
			newLabel = string
			accessibilityLabel = string
		} else {
			newLabel = noSelectionTitle
			accessibilityLabel = nil
		}

		guard newLabel != titleLabel.text else { return }
		if animated == true {
			UIView.transition(with: titleLabel, duration: 0.25, options: .transitionCrossDissolve) {
				self.titleLabel.text = newLabel
			}
		} else {
			titleLabel.text = newLabel
		}

		updateCallback?(animated)
	}

	private func presentOverlay(animated: Bool) {
		let pickerView = UIPickerView().constrain(width: 240)
		pickerView.delegate = self
		pickerView.dataSource = self
		if let selectedIndex {
			pickerView.selectRow(selectedIndex, inComponent: 0, animated: false)
		}

		// when nothing is selected, showing the overlay selects the first item
		if selectedIndex == nil, items.isEmpty == false {
			_selectedIndex = 0
			sendActions(for: .valueChanged)
			update(animated: false)
		}

		presentation = PlatterOverlayPresentation.present(pickerView, from: self, animated: true) { [weak self] in
			self?.presentation = nil
			self?.updateColors()
		}
		updateColors()
	}

	private func dismissOverlay(animated: Bool) {
		presentation?.dismiss(animated: true)
	}

	// MARK: - UIControl
	public override var isHighlighted: Bool {
		didSet {
			updateColors()
		}
	}

	public override var isSelected: Bool {
		didSet {
			updateColors()
		}
	}

	// MARK: - UIView
	public override init(frame: CGRect) {
		super.init(frame: frame)

		accessibilityTraits.insert(.button)

		contentView.isUserInteractionEnabled = false
		backgroundView.layer.cornerRadius = 6
		chevronImageView.tintColor = .tertiaryLabel
		chevronImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)

		addSubview(contentView, filling: .superview)
		contentView.addSubview(backgroundView, filling: .superview)
		contentView.addSubview(
			.horizontallyStacked(
				titleLabel.verticallyCentered(),
				chevronImageView.verticallyCentered(),
				spacing: 8
			),
			filling: .superview,
			insets: .horizontally(12, vertically: 7)
		)

		updateColors()
		update(animated: false)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("not implemented")
	}

	// MARK: - UIResponder
	public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesEnded(touches, with: event)

		if presentation?.isPresented == true {
			dismissOverlay(animated: true)
		} else {
			presentOverlay(animated: true)
		}
	}
}

extension SimpleCompactPickerView {
	/// A TableViewCell that shows the picker as an accessory
	public class TableViewCell: UITableViewCell {
		/// the picker that is shown as accessoryView
		public let picker = SimpleCompactPickerView<Item>()

		/// callback that will be called when the pickers selection did change
		public var selectionDidChangeCallback: ((Item?) -> Void)?

		/// if `true`, tapping the cell also triggers the overlay of the picker to show
		public var shouldAlsoShowOverlayOnCellTap = true

		// MARK: - Privates
		@objc private func selectionDidChange(_ sender: Any) {
			updatePickerAccessory()
			selectionDidChangeCallback?(picker.selectedItem)
		}

		private func updatePickerAccessory() {
			picker.bounds.size = picker.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
			accessoryView = picker
			setNeedsLayout()
		}

		// MARK: - UITableViewCell
		override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
			super.init(style: style, reuseIdentifier: reuseIdentifier)

			picker.addTarget(self, action: #selector(selectionDidChange(_:)), for: .valueChanged)
			picker.updateCallback = { [weak self] animated in self?.updatePickerAccessory() }
			updatePickerAccessory()
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("not implemented")
		}

		// MARK: - UIResponder
		public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
			super.touchesEnded(touches, with: event)

			if shouldAlsoShowOverlayOnCellTap == true {
				picker.showOverlay(animated: true)
			}
		}
	}
}
