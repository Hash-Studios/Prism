/// A quick reason an admin can pick when rejecting a wallpaper. [text] is what the creator reads.
class RejectReason {
  const RejectReason(this.label, this.text);

  final String label;
  final String text;
}

const List<RejectReason> rejectReasons = <RejectReason>[
  RejectReason('Low resolution', 'The resolution is too low. Upload an image with at least 1080 px on the short side.'),
  RejectReason('Watermark', 'The image has a watermark. Upload a version without it.'),
  RejectReason('Blurry', 'The image is blurry or heavily compressed. Upload a sharper version.'),
  RejectReason(
    'Copyright',
    'This image may be the work of someone else. Upload only wallpapers you made or have the rights to.',
  ),
  RejectReason('Duplicate', 'This wallpaper is a duplicate of one that is already on Prism.'),
  RejectReason(
    'Not a wallpaper',
    'This image does not work as a phone wallpaper. Use a portrait image that fills the screen.',
  ),
  RejectReason('Other', ''),
];
