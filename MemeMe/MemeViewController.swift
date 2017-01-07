//
//  ViewController.swift
//  MemeMe
//
//  Created by Luke Van In on 2017/01/01.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit

//
//  Delegate for MemeViewController. 
//  To be implemented by calling classes.
//
protocol MemeViewControllerDelegate: class {
    
    // Notify the receiver when a meme is created.
    func memeController(_ controller: MemeViewController, createdMeme: Meme)
}

class MemeViewController: UIViewController, UIBarPositioningDelegate {
    
    weak var delegate: MemeViewControllerDelegate?
    
    let defaultTopText = "Top Text"
    let defaultBottomText = "Bottom Text"
    
    lazy var memeTextAttributes : [String : Any] = {
        return [
            NSForegroundColorAttributeName: UIColor.white,
            NSStrokeColorAttributeName: UIColor.black,
            NSStrokeWidthAttributeName: -3.0,
            NSFontAttributeName: UIFont(name: "Impact", size: 40)!
        ]
    }()
    
    lazy var topTextFieldDelegate: MemeTextFieldDelegate = { [unowned self] in
        let delegate = MemeTextFieldDelegate(defaultText: self.defaultTopText)
        delegate.onEditing = self.onTextFieldEdit
        return delegate
    }()
    
    lazy var bottomTextFieldDelegate: MemeTextFieldDelegate = { [unowned self] in
        let delegate = MemeTextFieldDelegate(defaultText: self.defaultBottomText)
        delegate.onEditing = self.onTextFieldEdit
        return delegate
    }()
    
    // Amount to shift the image to accomodate the keyboard.
    var contentInset: CGFloat = 0 {
        didSet {
            updateLayout(animated: true)
        }
    }
    
    // Stipulate that the content inset needs to be applied. Content inset is only applied if editing the bottom 
    // textfield in landscape mode.
    var contentInsetRequired: Bool = false {
        didSet {
            updateLayout(animated: true)
        }
    }

    @IBOutlet weak var shareButtonItem: UIBarButtonItem!
    @IBOutlet weak var cancelButtonItem: UIBarButtonItem!
    @IBOutlet weak var cameraButtonItem: UIBarButtonItem!
    @IBOutlet weak var albumButtonItem: UIBarButtonItem!
    @IBOutlet weak var topTextField: UITextField!
    @IBOutlet weak var bottomTextField: UITextField!
    @IBOutlet weak var memeImageView: UIImageView!
    @IBOutlet weak var imageContainerView: UIView!
    @IBOutlet weak var imageAspectConstraint: NSLayoutConstraint!
    
    // Using strong references to constraints since the constraint can be disabled at runtime, which would result in the 
    // constraint being deallocated.
    @IBOutlet var offsetConstraint: NSLayoutConstraint!
    @IBOutlet var centerConstraint: NSLayoutConstraint!

    //
    //  Camera toolbar button item tapped. Import an image from the camera.
    //
    @IBAction func onCameraAction(_ sender: Any) {
        resignResponders()
        importImage(from: .camera)
    }
    
    //
    //  Album toolbar button item tapped. Import image from library.
    //
    @IBAction func onAlbumAction(_ sender: Any) {
        resignResponders()
        importImage(from: .photoLibrary)
    }
    
    //
    //  Image content area tapped. Behaviour depends on location of tap.
    //  If text field is tapped, then begin editing the text field, otherwise show an activity sheet to import an image.
    //
    //  The app needs to manually manage text field interaction as a workaround to the problem where the text fields 
    //  interfere with the underlying scroll view. Text fields which are placed over the scroll view intercept some of
    //  the gestures, which interferes with the pinch and pan gestures used for scaling and scrolling the scroll view.
    //
    //  The problem:
    //      - Text fields are intentionally placed over the image so that they can be included in the generated meme.
    //      - The image can be scaled and cropped by using pinch and pan gestures.
    //      - If the gesture is initiated over a text field then the gesture is not recognized.
    //      - The result that the app appears unresponsive if the gesture is initiate over a text field.
    //
    //  The solution used here is:
    //      1. Disable interaction on the text fields by setting isUserInteractionEnabled = false. This allows pinch and
    //          pan gestures to be recognized even the gesture is initiated over a text field. A side effect is that 
    //          taps on the text field are not recognized.
    //      2. Add a tap gesture recognizer to the view which contains the scroll view and text fields.
    //      3. When handling the tap gesture, check if the tap originated over a text field. 
    //      4. If the tap occurred on a text field then enabled interaction on the text field, otherwise import an 
    //          image.
    //
    //
    @IBAction func onImageAction(_ sender: UIGestureRecognizer) {
        if sender.isContained(in: topTextField) {
            // Top text field tapped.
            topTextField.isUserInteractionEnabled = true
            topTextField.becomeFirstResponder()
        }
        else if sender.isContained(in: bottomTextField) {
            // Bottom text field tapped.
            bottomTextField.isUserInteractionEnabled = true
            bottomTextField.becomeFirstResponder()
        }
        else {
            // No text field tapped - import image.
            resignResponders()
            showImageSourceSelection(from: sender.view)
        }
    }

    //
    //  Share meme.
    //
    @IBAction func onShareAction(_ sender: Any) {
        resignResponders()
        exportImage()
    }
    
    //
    //  Reset meme to default state.
    //
    @IBAction func onClearAction(_ sender: Any) {
        // TODO: Show prompt to clear
        resignResponders()
        resetContent()
    }
    
    
    // MARK: View life cycle
    
    override var prefersStatusBarHidden: Bool {
        // Hide status bar to provide more visual space for editing.
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        listInstalledFonts()
        configureTextFields()
        resetContent()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureButtons()
        updateButtons()
        updateLayout()
        observeKeyboardNotifications()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unobserveKeyboardNotifications()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // Adjust the layout when the device is rotated.
        coordinator.animate(alongsideTransition: { _ in
            self.updateLayout()
        }, completion: nil)
    }
    
    //
    //  Show a list of the fonts installed in the device.
    //  Used during development to try some font variations.
    //
    private func listInstalledFonts() {
        print("")
        print("==========")
        print("Installed fonts:")
        for familyName in UIFont.familyNames {
            let fontNames = UIFont.fontNames(forFamilyName: familyName)
            for fontName in fontNames {
                print("\(familyName).\(fontName)")
            }
        }
        print("==========")
        print("")
    }

    
    // MARK: Keyboard
    
    private func observeKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: .UIKeyboardWillShow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: .UIKeyboardWillHide,
            object: nil
        )
    }
    
    private func unobserveKeyboardNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: .UIKeyboardWillShow,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: .UIKeyboardWillHide,
            object: nil
        )
    }
    
    func keyboardWillShow(_ notification: Notification) {
        guard let frame = getFrameForKeyboardNotification(notification) else {
            return
        }
        
        // Calculate the space required to by the keyboard. See updateLayout() functions.
        contentInset = frame.height
    }
    
    func keyboardWillHide(_ notification: Notification) {
        // Keyboard is hidden, no content inset is required. See updateLayout() functions.
        contentInset = 0
    }
    
    private func getFrameForKeyboardNotification(_ notification: Notification) -> CGRect? {
        let frameValue = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue
        return frameValue?.cgRectValue
    }
    
    
    // MARK: UI
    
    private func onTextFieldEdit(_ textField: UITextField) {
        // If the bottom text field is being edited then apply the content inset for the keyboard. See updateLayout() functions.
        if bottomTextField.isFirstResponder {
            contentInsetRequired = true
        }
        else {
            contentInsetRequired = false
        }
        updateButtons()
    }

    //
    //  Update the UI layout, optionally animated.
    //
    private func updateLayout(animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.5) { [unowned self] in
                self.updateLayout()
            }
        }
        else {
            updateLayout()
        }
    }
    
    //
    //  Adjusts the UI layout to compensate for the device orientation as defined by the traits collection, and the 
    //  keyboard visibility.
    //
    //  Vertical aspect (portrait mode): 
    //  Image fits to width of screen, centered vertically in the available space. The image is always visible in its
    //  entirety, and moves vertically as the keyboard appearance changes.
    //
    //  Horizontal aspect (landscape mode):
    //  Image is resized to fit the available height. When the keyboard appears and the bottom tet fiels is being 
    //  edited, the image is shifted upwards to show the text field.
    //
    //  Note: The image maintains an aspect ration of 4:3. The example app shows using a unconstrained aspect ratio, 
    //  relying on the device screen size to drive the layout. I found a fixed aspect ratio was more intuitive to use 
    //  (ie users do not need to rotate the device to position text), and aesthetically pleasing (imho).
    //
    private func updateLayout() {
        
        if contentInsetRequired && (contentInset > 0) {
            // Editing bottom textfield.
            // Shift content to accomodate keyboard.
            centerConstraint.isActive = false
            offsetConstraint.isActive = true
            offsetConstraint.constant = contentInset
        }
        else {
            // Editing top textfield.
            // Leave content aligned to center.
            centerConstraint.isActive = true
            offsetConstraint.isActive = false
        }

        view.layoutIfNeeded()
    }
    
    //
    //  Determine if the device is in landscape mode.
    //
    private func isLandscape() -> Bool {
        let size = view.bounds.size
        return size.width > size.height
    }

    //
    //  Enable buttons depending on feature availability.
    //  E.g. Camera is unavailable on simulator, and so the camera button is disabled.
    //
    private func configureButtons() {
        cameraButtonItem.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
        albumButtonItem.isEnabled = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
    }
    
    //
    //  Apply default text attributes (stroke and colour), and setup text field delegates for editing.
    //
    private func configureTextFields() {
        configureTextField(textField: topTextField, withDelegate: topTextFieldDelegate)
        configureTextField(textField: bottomTextField, withDelegate: bottomTextFieldDelegate)
    }
    
    //
    //
    //
    private func configureTextField(textField: UITextField, withDelegate delegate: MemeTextFieldDelegate) {
        textField.defaultTextAttributes = memeTextAttributes
        textField.textAlignment = .center
        textField.delegate = delegate
    }
    
    //
    //  Resigns the current first responder and dismiss the keyboard.
    //
    private func resignResponders() {
        topTextField.resignFirstResponder()
        bottomTextField.resignFirstResponder()
    }
    
    //
    //  Calculate the minimum and maximum scale factors for the scroll view.
    //
    //  The minimum scale factor ensures that the image can never be scaled below a size which would allow the 
    //  background to show through. If the image overflows the available area then then image is cropped on export.
    //
    //  The maximum scale factor is set so that the image can never exceed a 1:1 scale. The maximum scale is always 
    //  larger than the minimum scale.
    //
//    fileprivate func configureImageZoom() {
//        guard let image = memeImageView.image else {
//            return
//        }
//
//        let imageSize = image.size
//        let containerSize = scrollView.bounds.size
//        
//        let imageAspect = imageSize.width / imageSize.height
//        let containerAspect = containerSize.width / containerSize.height
//        let minimumScale: CGFloat
//        let maximumScale: CGFloat
//        
//        if imageAspect > containerAspect {
//            // Image aspect ratio is wider than container. Fit vertically.
//            minimumScale = containerSize.height / imageSize.height
//        }
//        else {
//            // Image aspect ratio is narrower than container. Fit horizontally.
//            minimumScale = containerSize.width / imageSize.width
//        }
//        
//        // Ensure maximum zoom is always same as or greater than minimum zoom.
//        maximumScale = max(1.0, minimumScale)
//        
//        // Calculate minimum zoom level so that image fits entirely in available space without any gaps.
//        scrollView.minimumZoomScale = minimumScale
//        
//        // Calculate maximum zoom level so that image is not scaled past a maximum size.
//        scrollView.maximumZoomScale = maximumScale
//        
//        // Ensure current zoom is within bounds.
//        let currentScale = min(max(scrollView.zoomScale, minimumScale), maximumScale)
//        scrollView.zoomScale = currentScale
//    }
    
    
    
    // MARK: Meme
    
    //
    //  Remove any existing edits and set the content to a default state (ie create a new meme).
    //
    private func resetContent() {
        memeImageView.image = nil
        topTextField.text = defaultTopText
        bottomTextField.text = defaultBottomText
        setImageConstraintWithAspectRatio(1.0)
        resignResponders()
        updateButtons()
    }
    
    //
    //
    //
    func setImageConstraintWithAspectRatio(_ aspect: CGFloat) {
        if let constraint = imageAspectConstraint {
            memeImageView.removeConstraint(constraint)
        }
        imageAspectConstraint = memeImageView.widthAnchor.constraint(equalTo: memeImageView.heightAnchor, multiplier: aspect)
        if let constraint = imageAspectConstraint {
            memeImageView.addConstraint(constraint)
        }
    }
    
    //
    //  Updates the enabled/disabled state for the share and cancel buttons.
    //
    func updateButtons() {
        updateShareButton()
        updateCancelButton()
    }
    
    //
    //  Enable share button if enough content is provided to create a meme. Disable the button if the meme is 
    //  incomplete.
    //
    private func updateShareButton() {
        if isCompleted() {
            shareButtonItem.isEnabled = true
        }
        else {
            shareButtonItem.isEnabled = false
        }
    }
    
    //
    //  Enable the cancel button if any content is provided. Disable the button if the meme is in the default (new) 
    //  state.
    //
    private func updateCancelButton() {
        if hasContent() {
            cancelButtonItem.isEnabled = true
        }
        else {
            cancelButtonItem.isEnabled = false
        }
    }
    
    //
    //  Determine if the meme is in a complete state. 
    //  An image must be provided, and both text fields must contain text.
    //
    private func isCompleted() -> Bool {
        if getTopText() == nil {
            return false
        }
        
        if getBottomText() == nil {
            return false
        }
        
        if memeImageView.image == nil {
            return false
        }
        
        return true
    }
    
    //
    //  Determine if the meme contains any content.
    //  An image is provided, or either of the text fields contains text.
    //
    private func hasContent() -> Bool {
        if getTopText() != nil {
            return true
        }
        
        if getBottomText() != nil {
            return true
        }
        
        if memeImageView.image != nil {
            return true
        }
        
        return false
    }
    
    //
    //  Show a choice of source to import an image from. 
    //  Displayed when tapping on the image area.
    //
    private func showImageSourceSelection(from sender: UIView?) {
        let controller = UIAlertController(title: "Select Image", message: nil, preferredStyle: .actionSheet)
        
        // Add Album option if photo library is available.
        if let action = makeAction(caption: "Album", sourceType: .photoLibrary) {
            controller.addAction(action)
        }
        
        // Add Camera option if camera is available.
        if let action = makeAction(caption: "Camera", sourceType: .camera) {
            controller.addAction(action)
        }
        
        // Add default dimiss action.
        controller.addAction(
            UIAlertAction(
                title: "Dismiss",
                style: .cancel,
                handler: nil
            )
        )
        
        // Setup presentation controller for showing action sheet on iPad.
        if let presentationController = controller.popoverPresentationController {
            presentationController.sourceView = sender
            
            if let rect = sender?.bounds {
                presentationController.sourceRect = rect
            }
        }
        
        // Show action sheet.
        present(controller, animated: true, completion: nil)
    }
    
    //
    //
    //
    private func makeAction(caption: String, sourceType: UIImagePickerControllerSourceType) -> UIAlertAction? {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            return nil
        }
        return UIAlertAction(
            title: caption,
            style: .default,
            handler: { [weak self] (action) in
                self?.importImage(from: sourceType)
        })
    }
    
    //
    //  Show an image picker to import an image.
    //
    private func importImage(from source : UIImagePickerControllerSourceType) {
        let viewController = UIImagePickerController()
        viewController.sourceType = source
        viewController.delegate = self
        present(viewController, animated: true, completion: nil)
    }
    
    //
    //  Export the current meme image using an activity controller.
    //
    private func exportImage() {
        guard let image = captureMemeImage() else {
            return
        }
        showExportViewController(image: image)
    }
    
    //
    //  Show an activity controller to export the image. 
    //  Save the meme on completion, or show an error.
    //
    private func showExportViewController(image: UIImage) {
        let viewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        viewController.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, activityError in
            if let error = activityError {
                // An error occurred. Show an alert.
                self?.showAlert(for: error)
            }
            else if completed {
                // The activity controller completed without an error, save the meme.
                self?.saveMeme(image)
            }
            else {
                // ... The activity controller was cancelled
            }
        }
        present(viewController, animated: true, completion: nil)
    }
    
    //
    //  Composes a flattened meme image from the composer view.
    //
    //  TODO: Create an offscreen view with larger dimensions in order to obtain a higher fidelity result.
    //
    private func captureMemeImage() -> UIImage? {
        guard let sourceView = imageContainerView else {
            return nil
        }
        let viewArea = sourceView.bounds
        UIGraphicsBeginImageContext(viewArea.size)
        sourceView.drawHierarchy(in: viewArea, afterScreenUpdates: true)
        let outputImage : UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return outputImage
    }
    
    //
    //  "Save" the meme image. 
    //  Create an instance of a Meme model from the current state if possible. 
    //  The model is passed to the view controller's delegate (to handle persistence etc).
    //
    private func saveMeme(_ image: UIImage) {
        // Create meme object and pass to delegate.
        guard let meme = makeMeme(image: image) else {
            return
        }
        delegate?.memeController(self, createdMeme: meme)
    }
    
    //
    //  Create a meme model from the current editor's state if possible.
    //
    private func makeMeme(image: UIImage) -> Meme? {
        guard let topText = getTopText() else {
            return nil
        }
        
        guard let bottomText = getBottomText() else {
            return nil
        }
        
        guard let originalImage = memeImageView.image else {
            return nil
        }
        
        return Meme(
            topText: topText,
            bottomText: bottomText,
            originalImage: originalImage,
            memedImage: image
        )
    }
    
    //
    //  Get the text entered in the top text field. 
    //  If the text field contains the default placeholder text then return nothing.
    //
    private func getTopText() -> String? {
        guard let text = topTextField.text, text != defaultTopText, !text.isEmpty else {
            return nil
        }
        return text
    }

    //
    //  Get the text entered in the top text field.
    //  If the text field contains the default placeholder text then return nothing.
    //
    private func getBottomText() -> String? {
        guard let text = bottomTextField.text, text != defaultBottomText, !text.isEmpty else {
            return nil
        }
        return text
    }
    
    //
    //  Show an error alert.
    //
    private func showAlert(for error: Error) {
        print("Cannot save meme > \(error)")
        let title = "Oops, something went wrong."
        let message = "The meme could not be saved."
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
}

extension MemeViewController: UIScrollViewDelegate {
 
    //
    //  Required to enable zooming in the scroll view.
    //
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        //  Use the image view as the content to zoom for the scroll view.
        return memeImageView
    }
}

extension MemeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    //
    //  User cancelled picker. Just dismiss the picker.
    //
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("Image picker cancelled")
        dismiss(animated: true, completion: nil)
    }

    //
    //  Handle image picked by the user.
    //      - Set the image on the view.
    //      - Calculate the minimum and maximum zoom scale, and zoom to the minimum size.
    //      - Configure the share/cancel buttons.
    //      - Dismiss the picker.
    //
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        defer {
            dismiss(animated: true, completion: nil)
        }
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            return;
        }
        print("picked image: \(image)")
        memeImageView.image = image
        let size = image.size
        let aspect = size.width / size.height
        setImageConstraintWithAspectRatio(aspect)
        updateButtons()
    }
}

