/// A quick reason an admin can pick when rejecting a wallpaper.
enum RejectReason { lowResolution, watermark, blurry, copyright, duplicate, notWallpaper, other }

const List<RejectReason> rejectReasons = RejectReason.values;
