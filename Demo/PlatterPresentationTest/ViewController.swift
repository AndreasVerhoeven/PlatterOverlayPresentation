//
//  ViewController.swift
//  ScrollerTest
//
//  Created by Andreas Verhoeven on 08/03/2021.
//

import UIKit
import AutoLayoutConvenience

/// This example mimicks a compact UIDatePicker by using a `PlatterOverlayPresentation`
class ViewController: UIViewController {
	let simplePicker = SimpleCompactPickerView<String>()

	let dateButton = UIButton()
	let timeButton = UIButton()

	var isShowingTimePicker = false
	var date = Date()

	/// this is our platter presentation: we keep a reference to it, since we want to change the presented
	/// view in an existing presentation (switch from a date picker to a time picker).
	let platterOverlayPresentation = PlatterOverlayPresentation()

	func presentPicker(_ datePicker: UIDatePicker, from: UIView) {
		datePicker.date = date
		datePicker.addAction(UIAction(handler: { [weak self, weak datePicker] _ in
			guard let self, let datePicker else { return }

			date = datePicker.date
			updateButtonTitles()
		}), for: .valueChanged)

		// the source view is our combined background - don't accept touches there
		platterOverlayPresentation.sourceView = from
		platterOverlayPresentation.isSourceViewPassThru = false

		platterOverlayPresentation.alignment = .trailing
		platterOverlayPresentation.alignmentView = from.superview

		// do accept touches on the buttons
		platterOverlayPresentation.additionalPassThruViews = [timeButton, dateButton]

		// when we are dismissed, update our highlighting
		platterOverlayPresentation.dismissalCallback = { [weak self] in self?.updateButtonHighlighting() }

		// actually present the date picker - full AutoLayout support, as you can see
		platterOverlayPresentation.present(datePicker.wrapped(in: .layoutMargins), animated: true)

		// update the button highlighting now that we have presented something
		updateButtonHighlighting()
	}

	@objc func showDateControl() {
		guard platterOverlayPresentation.isPresented == false || isShowingTimePicker == true else {
			return platterOverlayPresentation.dismiss(animated: true)
		}

		let datePicker = UIDatePicker()
		datePicker.datePickerMode = .date
		datePicker.preferredDatePickerStyle = .inline

		isShowingTimePicker = false
		presentPicker(datePicker, from: dateButton)
	}

	@objc func showTimeControl() {
		guard platterOverlayPresentation.isPresented == false || isShowingTimePicker == false else {
			return platterOverlayPresentation.dismiss(animated: true)
		}

		let timePicker = UIDatePicker()
		timePicker.constrainedFixedWidth = 220
		timePicker.datePickerMode = .time
		timePicker.preferredDatePickerStyle = .wheels

		isShowingTimePicker = true
		presentPicker(timePicker, from: timeButton)
	}

	// MARK: - Privates
	private func updateButtonTitles() {
		dateButton.configuration?.title = date.formatted(date: .abbreviated, time: .omitted)
		timeButton.configuration?.title = date.formatted(date: .omitted, time: .shortened)
	}

	private func updateButtonHighlighting() {
		if platterOverlayPresentation.isPresented == true {
			dateButton.configuration?.baseForegroundColor = (isShowingTimePicker == false ? .tintColor : .label)
			timeButton.configuration?.baseForegroundColor = (isShowingTimePicker == true ? .tintColor : .label)
		} else {
			dateButton.configuration?.baseForegroundColor = .label
			timeButton.configuration?.baseForegroundColor = .label
		}
	}

	// MARK: - UIViewController
	override func viewDidLoad() {
		super.viewDidLoad()

		view.backgroundColor = .systemBackground

		dateButton.configuration = .filled()
		dateButton.configuration?.baseBackgroundColor = .secondarySystemFill
		dateButton.addTarget(self, action: #selector(showDateControl), for: .primaryActionTriggered)

		timeButton.configuration = .filled()
		timeButton.configuration?.baseBackgroundColor = .secondarySystemFill
		timeButton.addTarget(self, action: #selector(showTimeControl), for: .primaryActionTriggered)
		updateButtonHighlighting()
		updateButtonTitles()

		view.addSubview(.horizontallyStacked(dateButton, timeButton, distribution: .fillProportionally, spacing: 8), pinnedTo: .topLeading, of: .layoutMargins)

		simplePicker.items = (1..<21).map { "Item \($0)" }
		simplePicker.selectedIndex = 1
		view.addSubview(simplePicker, pinnedTo: .leadingCenter, of: .layoutMargins)

		let cell = SimpleCompactPickerView<String>.TableViewCell(style: .default, reuseIdentifier: nil)
		cell.textLabel?.text = "Drink"
		cell.picker.showsChevron = false
		cell.picker.noSelectionTitle = "Pick..."
		cell.picker.setItems(["Cola", "Beer", "Wine", "Root-beer", "Water"], selectedIndex: nil, animated: false)

		cell.frame = CGRect(x: 16, y: 140, width: 300, height: 44)
		view.addSubview(cell)
	}
}
