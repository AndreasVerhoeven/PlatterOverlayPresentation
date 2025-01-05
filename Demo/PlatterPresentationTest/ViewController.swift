//
//  ViewController.swift
//  ScrollerTest
//
//  Created by Andreas Verhoeven on 08/03/2021.
//

import UIKit
import AutoLayoutConvenience

class ViewController: UIViewController {
	let dateButton = UIButton()
	let timeButton = UIButton()

	var isShowingTimePicker = false
	var date = Date()

	/// this is our platter presentation: we keep a reference to it, since we want to change the presented
	/// view in an existing presentation (switch from a date picker to a time picker).
	let platterPresentation = PlatterPresentation()

	func presentPicker(_ datePicker: UIDatePicker) {
		datePicker.date = date
		datePicker.addAction(UIAction(handler: { [weak self, weak datePicker] _ in
			guard let self, let datePicker else { return }

			date = datePicker.date
			updateButtonTitles()
		}), for: .valueChanged)

		// the source view is our combined background - don't accept touches there
		platterPresentation.sourceView = dateButton.superview
		platterPresentation.isSourceViewPassThru = false

		// do accept touches on the buttons
		platterPresentation.additionalPassThruViews = [timeButton, dateButton]

		// when we are dismissed, update our highlighting
		platterPresentation.dismissalCallback = { [weak self] in self?.updateButtonHighlighting() }

		// actually present the date picker - full AutoLayout support, as you can see
		platterPresentation.present(datePicker.wrapped(in: .layoutMargins), animated: true)

		// update the button highlighting now that we have presented something
		updateButtonHighlighting()
	}

	@objc func showDateControl() {
		guard platterPresentation.isPresented == false || isShowingTimePicker == true else {
			return platterPresentation.dismiss(animated: true)
		}

		let datePicker = UIDatePicker()
		datePicker.datePickerMode = .date
		datePicker.preferredDatePickerStyle = .inline

		isShowingTimePicker = false
		presentPicker(datePicker)
	}

	@objc func showTimeControl() {
		guard platterPresentation.isPresented == false || isShowingTimePicker == false else {
			return platterPresentation.dismiss(animated: true)
		}

		let timePicker = UIDatePicker()
		timePicker.constrainedFixedWidth = 220
		timePicker.datePickerMode = .time
		timePicker.preferredDatePickerStyle = .wheels

		isShowingTimePicker = true
		presentPicker(timePicker)
	}

	// MARK: - Privates
	private func updateButtonTitles() {
		dateButton.configuration?.title = date.formatted(date: .abbreviated, time: .omitted)
		timeButton.configuration?.title = date.formatted(date: .omitted, time: .shortened)
	}

	private func updateButtonHighlighting() {
		if platterPresentation.isPresented == true {
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

		view.addSubview(.horizontallyStacked(dateButton, timeButton, distribution: .fillProportionally, spacing: 8), pinnedTo: .topCenter, of: .layoutMargins)
	}
}
