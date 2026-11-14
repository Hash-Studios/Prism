import 'dart:math' as math;
import 'dart:typed_data';

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';

/// What AI does to the photo.
enum PhotoJobMode {
  /// Fills in the edges so the photo takes the target shape.
  extend('fal-ai/bria/expand'),

  /// Adds detail so a small photo is sharp at the target size.
  upscale('fal-ai/seedvr/upscale/image'),

  /// Redraws the photo in an AI style at the target size.
  restyle('fal-ai/bytedance/seedream/v4/edit');

  const PhotoJobMode(this.model);

  /// The fal model the server runs. Shown in no UI; it is part of the job record.
  final String model;

  PhotoJobModeValue get analytics => switch (this) {
    PhotoJobMode.extend => PhotoJobModeValue.extend,
    PhotoJobMode.upscale => PhotoJobModeValue.upscale,
    PhotoJobMode.restyle => PhotoJobModeValue.restyle,
  };
}

/// What the user asks for. Fit lets the planner pick Extend or Upscale; Restyle always runs.
enum PhotoTool { fit, restyle }

enum PhotoJobTarget {
  phone,

  /// A 16:10 desktop screen.
  desktop;

  PhotoJobTargetValue get analytics => switch (this) {
    PhotoJobTarget.phone => PhotoJobTargetValue.phone,
    PhotoJobTarget.desktop => PhotoJobTargetValue.desktop,
  };
}

class PhotoSize {
  const PhotoSize(this.width, this.height);

  final int width;
  final int height;

  double get aspect => width / height;
  int get shortSide => math.min(width, height);

  @override
  bool operator ==(Object other) => other is PhotoSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '${width}x$height';
}

/// The output size of a desktop version. Same as `DESKTOP_SIZE` in `functions/src/photoWallpaper.ts`.
const PhotoSize photoDesktopSize = PhotoSize(2560, 1600);

/// A shape further than this from the target shape needs Extend. Same as `ASPECT_TOLERANCE` on the server.
const double photoAspectTolerance = 0.05;

/// The phone target: the screen in portrait pixels, kept inside the range the server accepts (720 to 1600 px wide,
/// 1.6 to 2.4 times as tall as wide).
PhotoSize phoneTargetSize({required double width, required double height}) {
  final double short = math.min(width, height);
  final double long = math.max(width, height);
  final double ratio = short > 0 ? (long / short).clamp(1.6, 2.4) : 2.0;
  final int w = short.round().clamp(720, 1600);
  // Rounding down could fall under the server's 1.6 minimum when w * 1.6 is not a whole number.
  return PhotoSize(w, math.max((w * ratio).floor(), (w * 1.6).ceil()));
}

PhotoSize targetSizeFor(PhotoJobTarget target, PhotoSize phone) =>
    target == PhotoJobTarget.desktop ? photoDesktopSize : phone;

/// What the app offers for a photo. Null means the photo already fits and no job is needed. The server checks the
/// same rule (`planPhotoJob`) and refuses a job that does not match it.
PhotoJobMode? planPhotoJob(PhotoSize photo, PhotoSize target) {
  if ((photo.aspect / target.aspect - 1).abs() > photoAspectTolerance) return PhotoJobMode.extend;
  return photo.shortSide < target.shortSide ? PhotoJobMode.upscale : null;
}

/// The job for [tool]. Null means Fit has nothing to do because the photo already fits.
PhotoJobMode? photoJobModeFor(PhotoTool tool, PhotoSize photo, PhotoSize target) =>
    tool == PhotoTool.restyle ? PhotoJobMode.restyle : planPhotoJob(photo, target);

/// Coins for one job. Pro pays half, rounded up, while the economy config gives Pro the discount.
int photoJobCost(PhotoJobMode mode, {required bool isPro, EconomyConfig? config}) {
  final EconomyConfig economy = config ?? EconomyConfig.current;
  final int base = switch (mode) {
    PhotoJobMode.extend => economy.spend.photoExtend,
    PhotoJobMode.upscale => economy.spend.photoUpscale,
    PhotoJobMode.restyle => economy.spend.photoRestyle,
  };
  return proPrice(base, isPro && economy.proDiscountActions.contains('photoWallpaper'));
}

/// Where the photo sits in the target canvas for Extend, in canvas pixels. The photo keeps its shape, stays inside
/// the canvas, and is between [minScale] and 1 times its largest fitting size. Every operation returns a new value.
class PhotoPlacement {
  const PhotoPlacement._(this.canvas, this.photo, this.left, this.top, this.width, this.height);

  /// The photo at its largest size inside the canvas, centred.
  factory PhotoPlacement.fit({required PhotoSize canvas, required PhotoSize photo}) {
    final double scale = _fitScale(canvas, photo);
    final int width = (photo.width * scale).round().clamp(1, canvas.width);
    final int height = (photo.height * scale).round().clamp(1, canvas.height);
    return PhotoPlacement._(canvas, photo, (canvas.width - width) ~/ 2, (canvas.height - height) ~/ 2, width, height);
  }

  /// The smallest size, as a share of the largest fitting size. The server refuses a photo under 10% of the canvas.
  static const double minScale = 0.6;
  static const double minCanvasShare = 0.1;

  final PhotoSize canvas;
  final PhotoSize photo;
  final int left;
  final int top;
  final int width;
  final int height;

  static double _fitScale(PhotoSize canvas, PhotoSize photo) =>
      math.min(canvas.width / photo.width, canvas.height / photo.height);

  /// The share of the largest fitting size, from [minScale] to 1.
  double get scale => width / (photo.width * _fitScale(canvas, photo));

  double get _fitCanvasShare {
    final double fit = _fitScale(canvas, photo);
    return photo.width * fit * photo.height * fit / (canvas.width * canvas.height);
  }

  double get _minimumScale => math.max(minScale, math.sqrt(minCanvasShare / _fitCanvasShare) + 0.01).clamp(0.0, 1.0);

  bool get validForServer => width * height >= minCanvasShare * canvas.width * canvas.height;

  bool get isFit => this == PhotoPlacement.fit(canvas: canvas, photo: photo);

  PhotoPlacement moved(double dx, double dy) => _at(left + dx, top + dy, width, height);

  /// Scales by [factor] around the photo's centre.
  PhotoPlacement scaled(double factor) {
    final double next = (scale * factor).clamp(_minimumScale, 1.0);
    final double fit = _fitScale(canvas, photo);
    final int w = (photo.width * fit * next).round().clamp(1, canvas.width);
    final int h = (photo.height * fit * next).round().clamp(1, canvas.height);
    return _at(left + (width - w) / 2, top + (height - h) / 2, w, h);
  }

  /// Moves the photo to the start (0), centre (0.5) or end (1) of the free axis.
  PhotoPlacement alignedTo(double fraction) {
    final double f = fraction.clamp(0.0, 1.0);
    return _at((canvas.width - width) * f, (canvas.height - height) * f, width, height);
  }

  PhotoPlacement _at(double x, double y, int w, int h) => PhotoPlacement._(
    canvas,
    photo,
    x.round().clamp(0, canvas.width - w),
    y.round().clamp(0, canvas.height - h),
    w,
    h,
  );

  Map<String, int> toJson() => <String, int>{'left': left, 'top': top, 'width': width, 'height': height};

  @override
  bool operator ==(Object other) =>
      other is PhotoPlacement &&
      other.canvas == canvas &&
      other.photo == photo &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(canvas, photo, left, top, width, height);
}

/// The picked photo, held only in memory. [bytes] are the photo as picked; the upload copy is made from them with no
/// metadata. [size] is the upright size of the photo.
class PhotoSource {
  const PhotoSource({required this.bytes, required this.size});

  final Uint8List bytes;
  final PhotoSize size;
}

/// Why a job ended without a wallpaper. The first five come from the server after the charge.
enum PhotoJobFailure {
  unsafeInput('unsafe_input'),
  unsafeOutput('unsafe_output'),
  providerError('provider_error'),
  storageError('storage_error'),
  timeout('timeout'),
  dailyLimit('daily_limit'),
  busy('busy'),
  insufficientCoins('insufficient_coins'),
  unreadable('unreadable'),
  inProgress('in_progress'),
  signIn('sign_in'),
  network('network');

  const PhotoJobFailure(this.wire);

  final String wire;

  static PhotoJobFailure fromWire(Object? value) =>
      PhotoJobFailure.values.firstWhere((PhotoJobFailure f) => f.wire == value, orElse: () => providerError);
}

sealed class PhotoJobState {
  const PhotoJobState();
}

/// Picked and planned. Nothing is sent and nothing is charged yet.
class PhotoJobDraft extends PhotoJobState {
  const PhotoJobDraft();
}

class PhotoJobRunning extends PhotoJobState {
  const PhotoJobRunning(this.requestId);

  /// Sent with every try of this job, so a retry never charges twice.
  final String requestId;
}

class PhotoJobSucceeded extends PhotoJobState {
  const PhotoJobSucceeded({required this.jobId, required this.imageUrl, required this.size, required this.watermarked});

  final String jobId;
  final String imageUrl;
  final PhotoSize size;
  final bool watermarked;
}

class PhotoJobFailed extends PhotoJobState {
  const PhotoJobFailed({required this.reason, required this.charged, required this.refunded, this.cost});

  final PhotoJobFailure reason;

  /// True when the server took the coins for this job.
  final bool charged;

  /// True when the server returned the coins. Only meaningful when [charged].
  final bool refunded;

  /// The actual server charge, when returned. Local failures have no charge amount.
  final int? cost;
}

/// One photo to wallpaper job. A Restyle job has a [style]; the other modes have none.
class PhotoJob {
  const PhotoJob({
    required this.source,
    required this.mode,
    required this.target,
    required this.cost,
    this.style,
    this.state = const PhotoJobDraft(),
  }) : assert((mode == PhotoJobMode.restyle) == (style != null), 'Only Restyle takes a style.');

  final PhotoSource source;
  final PhotoJobMode mode;
  final PhotoJobTarget target;
  final int cost;
  final AiStylePreset? style;
  final PhotoJobState state;

  String get model => mode.model;

  PhotoJob withState(PhotoJobState next) =>
      PhotoJob(source: source, mode: mode, target: target, cost: cost, style: style, state: next);
}

/// The job that was running when the app last ran. Kept on the device, so a result the user paid for is not lost when
/// the app closes during the job.
class PendingPhotoJob {
  const PendingPhotoJob({required this.userId, required this.requestId, required this.mode, required this.target});

  final String userId;
  final String requestId;
  final PhotoJobMode mode;
  final PhotoJobTarget target;

  Map<String, String> toJson() => <String, String>{
    'userId': userId,
    'requestId': requestId,
    'mode': mode.name,
    'target': target.name,
  };

  /// Null when [json] is not a pending job this app version wrote.
  static PendingPhotoJob? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? userId = json['userId'];
    final Object? requestId = json['requestId'];
    final PhotoJobMode? mode = PhotoJobMode.values.where((PhotoJobMode m) => m.name == json['mode']).firstOrNull;
    final PhotoJobTarget? target = PhotoJobTarget.values
        .where((PhotoJobTarget t) => t.name == json['target'])
        .firstOrNull;
    if (userId is! String ||
        userId.isEmpty ||
        requestId is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(requestId)) {
      return null;
    }
    if (mode == null || target == null) return null;
    return PendingPhotoJob(userId: userId, requestId: requestId, mode: mode, target: target);
  }
}
