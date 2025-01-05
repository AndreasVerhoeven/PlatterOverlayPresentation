# PlatterPresentation
Present views in an overlay platter easily, such as the inline UIDatePicker does.

## Summary

Starting in iOS 14, UIKit has slowly been moving to have more controls "in line": controls show in a small overlay in the current view controller, instead of being presented in a fully modal new view controller. This gives the user more context and feels faster.

For example, the new compact UIDatePicker controls show a small button, that, when tapped, show a full picker with wheels or a calendar in an overlay.

Such an overlay is called a "platter" inside UIKit. It shows a view in a round rectangle with a heavy shadow, on top of the current view: tapping the background dismisses the view with a nice animation.

Unfortunately, this is all internal to iOS. This small library mimicks that overlay UI with an easy to use interface.

## Screenshot

<img width="382" alt="Screenshot of the Platter" src="https://github.com/user-attachments/assets/4c2e4f5b-b06e-4042-a2c0-cd35c506f0f7" />

## How to Use

You use a `PlatterPresentation` object to show a UIView presented in an overlay platter. There's a convenience method to quickly show something - but if you need more control, you can also instantiate a `PlatterPresentation` yourself and keep on using that.

### Quick presentation

```
let myView = ....
let myControl = ...

PlatterPresentation.present(myView, from: myControl, animated: true)
```

That's all! The presentation will automatically figure out where to show close to the `from` view 
and when to dismiss the platter. There are a few more options (`rect`, `alignment`) to better control where the platter overlay is shown. If you want to get notified when the platter is dismissed, there's also a `callback` property:

```
myControl.isHiglighted = true
PlatterPresentation.present(myView, from: myControl, animated: true, callback: {
	// platter is no longer presented, update highlighting
	myControl.isHiglighted = false
})
```

### More Advanced usages

If you've seen UIDatePicker with date/time buttons, you'll notice that it switches the 
overlay platter content between a calendar view and a time picker, without presenting a new platter. That's also possible! You can keep a reference to a `platterPresentation` and update it or present new views on it, while it is already presenting something:

```
let platterPresentation = PlatterPresentation(sourceView: myControl)

func onTimeTapped() {
	// if nothing is presented, we present the time picker - if the date picker
	// is already presented, we smoothly animate the current platter to the time picker
	platterPresentation.present(timePicker, animated: true)
}

func onDateTapped() {
	// if nothing is presented, we present the date picker - if the time picker
	// is already presented, we smoothly animate the current platter to the date picker
	platterPresentation.present(datePicker, animated: true)
}
```

In this case we keep a platterPresentation around and call `present(:animated:)` on it
with different views. If the platter is already visible, it will smoothly animate to the new
view.

#### More Properties

There are also a few more properties you can configure on a `PlatterPresentation` object:

- `sourceView` / `sourceRect` - defines where the platter is presented from
- `alignment` - defines how the platter is aligned to the `sourceView`
- `shouldAvoidKeyboard` - if `true`, the platter avoids the keyboard (defaults to `true`)
- `dismissalCallback` - called when the platter is dismissed
- `isSourceViewPassThru` - if  `true`, taps on the `sourceView` will still be sent to the `sourceView`. If `false`, taps will be eaten and dismiss the platter. (default to`true`)
- `additionalPassThruViews` - additional views where taps will be passed thru, instead of dismissing the platter.
- `isPresented` - `true` if the platter is being presented. Read-only.
- `presentedView` - the view being presented currently. Read-only.


## How does it work

When you present a view, the presentation finds the nearest `UIViewController` and present another `ViewController` on top of it that holds the platter view and does it animation.

There's some magic to make the animation easily cancellable, without using the complex and buggy `UIViewControllerTransitioning` machinery: we mimick what UIKit does internally:
- we present a `UIViewController` that doesn't animate
- inside `viewDidAppear(:)` we start our animation
- on dismissal, we hide without animation
- inside `viewWillDissappear(:)` we take the platter view and put it on the window and do the "hide" animation
 
