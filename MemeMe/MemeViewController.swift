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

class MemeViewController: UIViewController {
    
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
    @IBOutlet weak var saveButtonItem: UIBarButtonItem!
    @IBOutlet weak var cameraButtonItem: UIBarButtonItem!
    @IBOutlet weak var albumButtonItem: UIBarButtonItem!
    @IBOutlet weak var topTextField: UITextField!
    @IBOutlet weak var bottomTextField: UITextField!
    @IBOutlet weak var memeImageView: UIImageView!
    @IBOutlet weak var imageContainerView: UIView!
    @IBOutlet weak var topToolbarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomToolbarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var heightConstraint : NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint : NSLayoutConstraint!

    @IBAction func onCameraAction(_ sender: Any) {
        importImage(from: .camera)
    }
    
    @IBAction func onAlbumAction(_ sender: Any) {
        importImage(from: .photoLibrary)
    }

    @IBAction func onSaveAction(_ sender: Any) {
        saveImage()
    }
    
    @IBAction func onShareAction(_ sender: Any) {
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
        updateLayout(traits: traitCollection)
        observeKeyboardNotifications()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unobserveKeyboardNotifications()
    }
    
//    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//        coordinator.animate(alongsideTransition: { _ in
//            self.updateLayout()
//        }, completion: nil)
//    }
    
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
        
        let regularToolbarSize: CGFloat = 44
        let compactToolbarSize: CGFloat = 34
        let toolbarSize: CGFloat
        let inset: CGFloat
        let height: CGFloat
        let availableHeight: CGFloat = view.bounds.size.height
        
        if traits.verticalSizeClass == .compact {
            toolbarSize = compactToolbarSize
            if contentInsetRequired && (contentInset > 0) {
                inset = contentInset
            }
            else {
                inset = toolbarSize
            }
            height = availableHeight - toolbarSize * 2
        }
        else {
            toolbarSize = regularToolbarSize
            if contentInset > 0 {
                inset = contentInset
            }
            else {
                inset = toolbarSize
            }
            height = availableHeight - inset - toolbarSize
        }
        bottomConstraint.constant = inset
        heightConstraint.constant = height
        topToolbarHeightConstraint.constant = toolbarSize
        bottomToolbarHeightConstraint.constant = toolbarSize
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
    }
    
    private func importImage(from source : UIImagePickerControllerSourceType) {
        let viewController = UIImagePickerController()
        viewController.sourceType = source
        viewController.delegate = self
        present(viewController, animated: true, completion: nil)
    }
    
    private func saveImage() {
        let meme = makeMeme()
    }
    
    private func makeMeme() -> Meme? {
        guard let topText = topTextField.text, !topText.isEmpty else {
            return nil
        }
        
        guard let bottomText = bottomTextField.text, !bottomText.isEmpty else {
            return nil
        }
        
        guard let originalImage = memeImageView.image else {
            return nil
        }
        
        guard let memedImage = captureMemeImage() else {
            return nil
        }
        
        return Meme(
            topText: topText,
            bottomText: bottomText,
            originalImage: originalImage,
            memedImage: memedImage
        )
    }
    
    private func exportImage() {
        guard let image = captureMemeImage() else {
            return
        }
        resignResponders()
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
    }
}

