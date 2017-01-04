//
//  ViewController.swift
//  MemeMe
//
//  Created by Luke Van In on 2017/01/01.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit

struct Meme {
    let topText : String
    let bottomText : String
    let originalImage : UIImage
    let memedImage : UIImage
}

class MemeTextFieldDelegate: NSObject, UITextFieldDelegate {
    
    typealias EditingHandler = (UITextField) -> Void

    var onEditing : EditingHandler?

    private let defaultText : String
    
    init(defaultText: String) {
        self.defaultText = defaultText
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.text == defaultText {
            textField.text = nil
        }
        onEditing?(textField)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text?.isEmpty ?? true {
            textField.text = defaultText
        }
        onEditing?(textField)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

protocol MemeViewControllerDelegate: class {
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
    
    var contentInset: CGFloat = 0 {
        didSet {
            updateLayout(animated: true)
        }
    }
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
    @IBOutlet weak var heightConstraint : NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint : NSLayoutConstraint!

    @IBAction func onCameraAction(_ sender: Any) {
        importImage(from: .camera)
    }
    
    @IBAction func onAlbumAction(_ sender: Any) {
        importImage(from: .photoLibrary)
    }

    @IBAction func onShareAction(_ sender: Any) {
        resignResponders()
        exportImage()
    }
    
    @IBAction func onClearAction(_ sender: Any) {
        // TODO: Show prompt to clear
        resetContent()
    }
    
    
    // MARK: View life cycle
    
    override var prefersStatusBarHidden: Bool {
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
        updateLayout(traits: traitCollection)
        observeKeyboardNotifications()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unobserveKeyboardNotifications()
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { _ in
            self.updateLayout(traits: newCollection)
        }, completion: nil)
    }
    
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
        contentInset = UIScreen.main.bounds.size.height - frame.minY
    }
    
    func keyboardWillHide(_ notification: Notification) {
        contentInset = 0
    }
    
    private func getFrameForKeyboardNotification(_ notification: Notification) -> CGRect? {
        let frameValue = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue
        return frameValue?.cgRectValue
    }
    
    
    // MARK: UI
    
    private func onTextFieldEdit(_ textField: UITextField) {
        if bottomTextField.isFirstResponder {
            contentInsetRequired = true
        }
        else {
            contentInsetRequired = false
        }
        updateButtons()
    }

    private func updateLayout(animated: Bool) {
        updateLayout(animated: animated, traits: traitCollection)
    }

    private func updateLayout(animated: Bool, traits: UITraitCollection) {
        if animated {
            UIView.animate(withDuration: 0.5) { [weak self] in
                self?.updateLayout(traits: traits)
            }
        }
        else {
            updateLayout(traits: traits)
        }
    }
    
    private func updateLayout(traits: UITraitCollection) {
        
        let inset: CGFloat
        let height: CGFloat
        let topBarHeight: CGFloat = topLayoutGuide.length
        let bottomBarHeight: CGFloat = bottomLayoutGuide.length
        let availableHeight: CGFloat = view.bounds.size.height
        
        if traits.verticalSizeClass == .compact {
            if contentInsetRequired && (contentInset > 0) {
                inset = contentInset
            }
            else {
                inset = bottomBarHeight
            }
            height = availableHeight - topBarHeight - bottomBarHeight
        }
        else {
            if contentInset > 0 {
                inset = contentInset
            }
            else {
                inset = bottomBarHeight
            }
            height = availableHeight - inset - topBarHeight
        }
        bottomConstraint.constant = inset
        heightConstraint.constant = height
        view.layoutIfNeeded()
    }
    
    private func configureButtons() {
        // Enable buttons depending on feature availability.
        // E.g. Camera is unavailable on simulator, and so the camera button is disabled.
        cameraButtonItem.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
        albumButtonItem.isEnabled = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
    }
    
    private func configureTextFields() {
        
        // Configure top text field
        topTextField.defaultTextAttributes = memeTextAttributes
        topTextField.textAlignment = .center
        topTextField.delegate = topTextFieldDelegate
        
        // Configure bottom text field
        bottomTextField.defaultTextAttributes = memeTextAttributes
        bottomTextField.textAlignment = .center
        bottomTextField.delegate = bottomTextFieldDelegate
    }
    
    
    // MARK: Meme
    
    private func resetContent() {
        memeImageView.image = nil
        topTextField.text = defaultTopText
        bottomTextField.text = defaultBottomText
        resignResponders()
        updateButtons()
    }
    
    func updateButtons() {
        updateShareButton()
        updateCancelButton()
    }
    
    private func updateShareButton() {
        if isCompleted() {
            shareButtonItem.isEnabled = true
        }
        else {
            shareButtonItem.isEnabled = false
        }
    }
    
    private func updateCancelButton() {
        if hasContent() {
            cancelButtonItem.isEnabled = true
        }
        else {
            cancelButtonItem.isEnabled = false
        }
    }
    
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
    
    private func importImage(from source : UIImagePickerControllerSourceType) {
        let viewController = UIImagePickerController()
        viewController.sourceType = source
        viewController.delegate = self
        present(viewController, animated: true, completion: nil)
    }
    
    private func exportImage() {
        guard let image = captureMemeImage() else {
            return
        }
        showExportViewController(image: image)
    }
    
    private func resignResponders() {
        topTextField.resignFirstResponder()
        bottomTextField.resignFirstResponder()
    }
    
    private func showExportViewController(image: UIImage) {
        let viewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        viewController.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, activityError in
            if let error = activityError {
                self?.showAlert(for: error)
            }
            else if completed {
                self?.saveMeme(image)
            }
        }
        present(viewController, animated: true, completion: nil)
    }
    
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
    
    private func saveMeme(_ image: UIImage) {
        // Create meme object and pass to delegate.
        guard let meme = makeMeme(image: image) else {
            return
        }
        delegate?.memeController(self, createdMeme: meme)
    }
    
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
    
    private func getTopText() -> String? {
        guard let text = topTextField.text, text != defaultTopText, !text.isEmpty else {
            return nil
        }
        return text
    }
    
    private func getBottomText() -> String? {
        guard let text = bottomTextField.text, text != defaultBottomText, !text.isEmpty else {
            return nil
        }
        return text
    }
    
    private func showAlert(for error: Error) {
        print("Cannot save meme > \(error)")
        let title = "Oops, something went wrong."
        let message = "The meme could not be saved."
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
}

extension MemeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("Image picker cancelled")
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        defer {
            dismiss(animated: true, completion: nil)
        }
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            return;
        }
        print("picked image: \(image)")
        memeImageView.image = image
        updateButtons()
    }
}

