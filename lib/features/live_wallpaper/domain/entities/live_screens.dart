import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';

/// The label Prism gives each live wallpaper it applies, so it can later read back what each screen got.
class LiveContentTag {
  const LiveContentTag({required this.style, required this.applyId});

  /// A [MotionStyle] or a [GradientStyle].
  final Enum style;

  /// Unique per apply, so a second apply of the same style is told apart from the first.
  final String applyId;

  static const String _prefix = 'prism.live';

  String encode() => '$_prefix:${style is MotionStyle ? 'motion' : 'gradient'}:${style.name}:$applyId';

  static LiveContentTag? parse(String? raw) {
    final List<String>? parts = raw?.split(':');
    if (parts == null || parts.length != 4 || parts[0] != _prefix) return null;
    final Enum? style = switch (parts[1]) {
      'motion' => MotionStyle.values.asNameMap()[parts[2]],
      'gradient' => GradientStyle.values.asNameMap()[parts[2]],
      _ => null,
    };
    return style == null ? null : LiveContentTag(style: style, applyId: parts[3]);
  }

  @override
  bool operator ==(Object other) => other is LiveContentTag && other.style == style && other.applyId == applyId;

  @override
  int get hashCode => Object.hash(style, applyId);
}

/// What each screen shows after the system preview closes.
class LiveScreenContent {
  const LiveScreenContent({required this.showsPrism, this.tag});

  static const LiveScreenContent other = LiveScreenContent(showsPrism: false);

  /// True when Prism's live wallpaper is on the screen.
  final bool showsPrism;

  /// Null when the screen shows another wallpaper, or a Prism live wall from before tags existed.
  final LiveContentTag? tag;

  @override
  bool operator ==(Object other) => other is LiveScreenContent && other.showsPrism == showsPrism && other.tag == tag;

  @override
  int get hashCode => Object.hash(showsPrism, tag);
}

class LiveScreens {
  const LiveScreens({required this.home, required this.lock});

  static const LiveScreens unknown = LiveScreens(home: LiveScreenContent.other, lock: LiveScreenContent.other);

  final LiveScreenContent home;
  final LiveScreenContent lock;

  /// The screens that show the apply that [tag] names, or null when none does.
  WallpaperTarget? screensShowing(LiveContentTag tag) {
    final bool onHome = home.tag == tag;
    final bool onLock = lock.tag == tag;
    if (onHome && onLock) return WallpaperTarget.both;
    if (onHome) return WallpaperTarget.home;
    if (onLock) return WallpaperTarget.lock;
    return null;
  }

  @override
  bool operator ==(Object other) => other is LiveScreens && other.home == home && other.lock == lock;

  @override
  int get hashCode => Object.hash(home, lock);
}
