# MemeMe
MemeMe iOS app for Udacity nanodegree

Luke Van In 2016-01-01

![Take my money](Images/meme-03.JPG)

Make memes. Supports portrait and landscape mode on iPhone and iPad.

![Portrait](Images/preview-portrait.png)
![Portrait](Images/preview-landscape.png)

## Notes:

![Take my money](Images/meme-04.JPG)

- Tap on text field to enter/edit text. Text fields display placeholder text if no text is entered.
- Tap on image area, or Camera / Album buttons, to select an image from the device or camera. Camera and Album button become disabled if the feature is not available on the device (ie no camera on the simulator).
- Pinch and pan on the image to adjust image cropping. The cropped sections are shown with a greyed out effect.
- Share button becomes enabled when meme is complete (image and both text fields are filled). Tap on the share button to show the activity controller for sharing the image. The image is sent to the view controller delegate on completion.
- Cancel button becomes enabled when any content is provided (image or either text field). Tap cancel button to clear content and revert to default state.
- Meme image maintains 4:3 aspect ratio independently of device size and orientation. Image is scaled to fit screen width in portrait mode, and screen height in landscape mode.

## Known issues:

![Take my money](Images/meme-01.JPG)

- Launching the app in landscape mode on iPad results in the image view not being shown too large. Rotating the iPad to portrait and back to landscape resolves the issue.
- Loading an image in landscape mode on iPhone causes the image to be resized incorrectly once loaded. Pinch and pan to scale and move the image.
- The scroll/crop position of the image is not retained when switching between landscape and portrait mode.

## TODO:

![Take my money](Images/meme-13.JPG)

- Export images at higher resolution. Currently uses the default view size, which is device dependent, and does not account for retina scale.
- Maintain relative scale and offset for image when the device is rotated. Currently uses absolute point offset which does not account for difference in view size.
- Allow user to select a different font.
