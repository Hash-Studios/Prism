# Live Photo walls (iOS)

iOS does not let an app set a wallpaper. iOS can use a Live Photo from Photos as a Lock Screen wallpaper, and the Lock Screen plays its motion. Prism renders a wall in a live style to a short video, pairs the video with a key photo, and saves the pair to Photos as one Live Photo. Then Prism shows the user how to set it.

Android keeps Make it live (see [live-wallpapers.md](live-wallpapers.md)). This page is about iOS only.

## Research

We did this research before we built the feature. Sources are at the end of this section.

### How Photos pairs a photo and a video

A Live Photo is two files with one shared identifier. Both files must carry the same UUID string:

| File | Where the identifier goes |
|---|---|
| Key photo (HEIC or JPEG) | MakerApple dictionary (`kCGImagePropertyMakerAppleDictionary`), key `"17"`. |
| Paired video (QuickTime `.mov`) | Top-level QuickTime metadata item `com.apple.quicktime.content.identifier` (key space `mdta`, UTF-8). In AVFoundation this is `AVMetadataIdentifier.quickTimeMetadataContentIdentifier`. |

The video also needs a timed metadata track with one item, `com.apple.quicktime.still-image-time` (key space `mdta`, data type `com.apple.metadata.datatype.int8`, value `0`). Its presentation time marks the frame that the key photo shows. Write it with an `AVAssetWriterInputMetadataAdaptor` whose format description comes from `CMMetadataFormatDescriptionCreateWithMetadataSpecifications`.

To save, use one `PHAssetCreationRequest`. Add the photo with resource type `.photo` and the video with `.pairedVideo`, in the same `performChanges` block. When the identifiers do not match, Photos refuses the request or saves a still photo only.

To check the result, fetch the new asset by its local identifier and check that `mediaSubtypes` contains `.photoLive`. This read needs read access to the library. The add-only level (`PHAccessLevel.addOnly`) cannot fetch assets.

### Lock Screen motion

| Item | What we found |
|---|---|
| iOS versions | iOS 16 removed Live Photo motion from the Lock Screen. iOS 17 added it again. iOS 17, 18 and 26 support it. Home Screen wallpapers do not play motion. |
| When it plays | The Lock Screen plays the motion one time when the user wakes the iPhone. Then it shows the key photo. |
| Low Power Mode | Most sources say Low Power Mode stops the motion. Apple does not document it. The iOS 26 Spatial Scene wallpaper also has no motion in Low Power Mode. |
| Reduce Motion | Some sources say Reduce Motion stops the motion. |
| Length | Camera Live Photos are about 3 seconds, with the key photo near the middle. One report says clips shorter than 1 second fail. No source gives an official limit. |
| Frame rate | Camera Live Photos use up to 30 frames per second. No source gives an official limit. |

### The main risk

Apple DTS said in the Developer Forums (thread 798044, 2025) that wallpaper eligibility has requirements that Apple does not document. In that thread, a developer wrote the identifier, the MakerApple key and the still-image-time track. The Live Photo played in Photos, but the Lock Screen said "Motion not available". Apple said that this is not a bug, and asked for an enhancement request.

Some open-source tools get motion on the Lock Screen. They copy timed metadata tracks (`com.apple.quicktime.live-photo-info` and `com.apple.quicktime.live-photo-still-image-transform`) from a real camera Live Photo into the new video. These tracks are not documented. Apple DTS advises against this. We do not do it.

Result: Prism writes the documented pairing only. The Live Photo saves, shows the LIVE badge, and plays in Photos. Lock Screen motion is not guaranteed. Only a real iPhone can show if iOS accepts it. The guide tells the user what to do when iOS says "Motion not available".

### Sources

- Apple Developer Forums, "Live Photos created with PHLivePhoto API show Motion not available when setting as wallpaper": https://developer.apple.com/forums/thread/798044
- Apple Developer Forums, "Motion not available ios 17 live photo": https://developer.apple.com/forums/thread/745694
- LimitPoint/LivePhoto issue 10: https://github.com/LimitPoint/LivePhoto/issues/10
- Apple PhotoKit reference: `PHAssetCreationRequest`, `PHAssetResourceType.pairedVideo`, `PHAssetMediaSubtype.photoLive`.
- Apple AVFoundation reference: `AVMetadataIdentifier.quickTimeMetadataContentIdentifier`, `AVAssetWriterInputMetadataAdaptor`.
