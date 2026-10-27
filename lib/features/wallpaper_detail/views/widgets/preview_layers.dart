import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// How the app icons look on the home screen preview. iOS and Android offer different sets.
enum PreviewIconStyle {
  standard,
  dark,
  clear,
  tinted,
  themed;

  static List<PreviewIconStyle> forPlatform(TargetPlatform platform) => platform == TargetPlatform.iOS
      ? const <PreviewIconStyle>[standard, dark, clear, tinted]
      : const <PreviewIconStyle>[standard, themed];
}

/// Used by Tinted and Themed when no colours could be read from the wallpaper.
final ColorScheme _neutralScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF8E8E93),
  brightness: Brightness.dark,
);

/// Generic glyphs and the colour each placeholder app has in the Default style. None is a real app's icon.
const List<(IconData, Color)> _apps = <(IconData, Color)>[
  (Icons.phone_rounded, Color(0xFF34C759)),
  (Icons.explore_rounded, Color(0xFF2F7CF6)),
  (Icons.chat_bubble_rounded, Color(0xFF30D158)),
  (Icons.music_note_rounded, Color(0xFFFF2D55)),
  (Icons.mail_rounded, Color(0xFF0A84FF)),
  (Icons.calendar_today_rounded, Color(0xFFFF3B30)),
  (Icons.photo_rounded, Color(0xFFFF9500)),
  (Icons.camera_alt_rounded, Color(0xFF8E8E93)),
  (Icons.map_rounded, Color(0xFF30B0C7)),
  (Icons.wb_sunny_rounded, Color(0xFF5AC8FA)),
  (Icons.sticky_note_2_rounded, Color(0xFFFFCC00)),
  (Icons.schedule_rounded, Color(0xFF5856D6)),
  (Icons.settings_rounded, Color(0xFF636366)),
  (Icons.calculate_rounded, Color(0xFFFF9F0A)),
  (Icons.videocam_rounded, Color(0xFFAF52DE)),
  (Icons.podcasts_rounded, Color(0xFFBF5AF2)),
  (Icons.shopping_bag_rounded, Color(0xFF00C7BE)),
];

const List<int> _iosDock = <int>[0, 1, 2, 3];
const List<int> _iosGrid = <int>[4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
const List<int> _androidDock = <int>[0, 2, 1, 7, 6];
const List<int> _androidGrid = <int>[4, 5, 8, 9, 10, 11, 12, 13, 14, 16];

/// Key of the dock row, for tests and the position studio.
const ValueKey<String> previewDockKey = ValueKey<String>('preview-dock');

/// How big the layer is drawn compared with a full screen. A phone-shaped frame on a smaller area scales down.
double _layerScale(BuildContext context, BoxConstraints constraints) {
  final double screenWidth = MediaQuery.sizeOf(context).width;
  if (!constraints.hasBoundedWidth || screenWidth <= 0) return 1;
  return constraints.maxWidth / screenWidth;
}

/// Height of the status bar as the layer draws it. It scales with the frame, like the text.
double _statusBarInset(BuildContext context, double scale) => MediaQuery.viewPaddingOf(context).top * scale;

/// Centres [child] in the top third of the space below the status bar.
Widget _topThird(BoxConstraints constraints, double inset, Widget child) {
  return Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: EdgeInsets.only(top: inset),
      child: SizedBox(
        height: constraints.maxHeight.isFinite ? math.max(0.0, constraints.maxHeight - inset) / 3 : null,
        width: constraints.maxWidth,
        child: Center(child: child),
      ),
    ),
  );
}

ShapeBorder _iconShape(bool ios, double size, {BorderSide side = BorderSide.none}) => ios
    ? RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(size * 0.26), side: side)
    : CircleBorder(side: side);

/// Liquid Glass: a blur of the wallpaper behind, a light wash, and a bright edge.
Widget _glass({required ShapeBorder shape, required Widget child, Color? wash}) {
  return ClipPath(
    clipper: ShapeBorderClipper(shape: shape),
    child: BackdropFilter.grouped(
      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: wash == null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.1)],
                )
              : null,
          color: wash,
        ),
        child: child,
      ),
    ),
  );
}

ShapeBorder _withEdge(ShapeBorder shape, double width) {
  final BorderSide edge = BorderSide(color: Colors.white.withValues(alpha: 0.45), width: width);
  return switch (shape) {
    RoundedSuperellipseBorder() => shape.copyWith(side: edge),
    CircleBorder() => shape.copyWith(side: edge),
    _ => shape,
  };
}

typedef _Paint = ({Color fill, Color glyph});

_Paint _iconPaint(PreviewIconStyle style, Color hue, ColorScheme scheme, {required bool ios}) => switch (style) {
  PreviewIconStyle.standard => ios ? (fill: hue, glyph: Colors.white) : (fill: const Color(0xFFF1F3F8), glyph: hue),
  PreviewIconStyle.dark => (fill: const Color(0xFF1C1C1E), glyph: hue),
  PreviewIconStyle.clear => (fill: Colors.transparent, glyph: Colors.white.withValues(alpha: 0.95)),
  PreviewIconStyle.tinted => (
    fill: Color.alphaBlend(scheme.primary.withValues(alpha: 0.2), const Color(0xF0141416)),
    glyph: scheme.primary,
  ),
  // Android 13+ themed icons in light mode: accent tone 90 behind a tone 30 glyph.
  PreviewIconStyle.themed => (fill: scheme.onPrimaryContainer, glyph: scheme.primaryContainer),
};

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app, required this.size, required this.style, required this.scheme, required this.ios});

  final (IconData, Color) app;
  final double size;
  final PreviewIconStyle style;
  final ColorScheme scheme;
  final bool ios;

  @override
  Widget build(BuildContext context) {
    final _Paint paint = _iconPaint(style, app.$2, scheme, ios: ios);
    final Widget glyph = SizedBox.square(
      dimension: size,
      child: Icon(app.$1, size: size * 0.54, color: paint.glyph),
    );
    if (style == PreviewIconStyle.clear) {
      return _glass(shape: _withEdge(_iconShape(ios, size), math.max(0.5, size / 64)), child: glyph);
    }
    return DecoratedBox(
      decoration: ShapeDecoration(color: paint.fill, shape: _iconShape(ios, size)),
      child: glyph,
    );
  }
}

/// The clock and date of a lock screen, drawn over a wallpaper. It fills the space it gets.
/// On iOS it also draws a row of lock screen widgets and the flashlight and camera buttons.
class LockPreviewLayer extends StatelessWidget {
  const LockPreviewLayer({super.key, required this.textColor, this.now});

  final Color textColor;

  /// The time to show. Defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final DateTime time = now ?? DateTime.now();
    final bool use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final String clock = DateFormat(use24Hour ? 'HH:mm' : 'h:mm', context.l10n.localeName).format(time);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scale = _layerScale(context, constraints);
        final double inset = _statusBarInset(context, scale);
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          final double w = constraints.maxWidth / scale;
          final double widget = math.min(w * 0.15, 72) * scale;
          final double button = math.min(w * 0.125, 56) * scale;
          final double buttonSide = w * 0.11 * scale;
          final double buttonBottom = (MediaQuery.viewPaddingOf(context).bottom + 8) * scale;
          Widget lockButton(IconData icon) => _glass(
            shape: const CircleBorder(),
            wash: Colors.black.withValues(alpha: 0.28),
            child: SizedBox.square(
              dimension: button,
              child: Icon(icon, size: button * 0.44, color: Colors.white),
            ),
          );
          return BackdropGroup(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: inset + 24 * scale),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          DateFormat.MMMMEEEEd(context.l10n.localeName).format(time),
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'CupertinoSystemText',
                            fontSize: 20 * scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          clock,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'CupertinoSystemDisplay',
                            fontSize: 96 * scale,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 6 * scale),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (final IconData icon in const <IconData>[
                              Icons.wb_sunny_rounded,
                              Icons.directions_walk_rounded,
                              Icons.battery_full_rounded,
                            ])
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: textColor.withValues(alpha: 0.16),
                                    shape: CircleBorder(
                                      side: BorderSide(color: textColor.withValues(alpha: 0.28), width: 1.5 * scale),
                                    ),
                                  ),
                                  child: SizedBox.square(
                                    dimension: widget,
                                    child: Icon(icon, size: widget * 0.42, color: textColor.withValues(alpha: 0.9)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(left: buttonSide, bottom: buttonBottom, child: lockButton(Icons.flashlight_on_rounded)),
                Positioned(right: buttonSide, bottom: buttonBottom, child: lockButton(Icons.camera_alt_rounded)),
              ],
            ),
          );
        }
        return _topThird(
          constraints,
          inset,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                clock,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Roboto',
                  fontSize: 72 * scale,
                  fontWeight: FontWeight.w200,
                ),
              ),
              SizedBox(height: 5 * scale),
              Text(
                DateFormat.MMMMEEEEd(context.l10n.localeName).format(time),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Roboto',
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A home screen drawn over a wallpaper: app icons, a widget and the dock. It fills the space it gets.
class HomePreviewLayer extends StatelessWidget {
  const HomePreviewLayer({
    super.key,
    required this.textColor,
    this.now,
    this.iconStyle = PreviewIconStyle.standard,
    this.scheme,
  });

  final Color textColor;
  final DateTime? now;
  final PreviewIconStyle iconStyle;

  /// Colours read from the wallpaper. Tinted and Themed icons use them. Null falls back to a neutral grey.
  final ColorScheme? scheme;

  @override
  Widget build(BuildContext context) {
    final DateTime time = now ?? DateTime.now();
    final ColorScheme palette = scheme ?? _neutralScheme;
    final bool ios = defaultTargetPlatform == TargetPlatform.iOS;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double s = _layerScale(context, constraints);
        final double w = constraints.maxWidth / s;
        final double h = constraints.maxHeight / s;
        final EdgeInsets device = MediaQuery.viewPaddingOf(context);
        final Widget layer = ios
            ? _iosHome(context, time, palette, s, w, h, device)
            : _androidHome(context, time, palette, s, w, h, device);
        return BackdropGroup(child: layer);
      },
    );
  }

  Widget _icon(int app, double size, ColorScheme palette, {required bool ios}) =>
      _AppIcon(app: _apps[app], size: size, style: iconStyle, scheme: palette, ios: ios);

  Widget _iosHome(
    BuildContext context,
    DateTime time,
    ColorScheme palette,
    double s,
    double w,
    double h,
    EdgeInsets device,
  ) {
    final double icon = math.min(w * 0.155, 76);
    final double side = w * 0.075;
    final double colPitch = (w - 2 * side - icon) / 3;
    final double rowPitch = icon + w * 0.075;
    final double top = device.top + w * 0.04;
    final double dockInset = w * 0.03;
    final double dockHeight = icon + w * 0.08;
    final double dotsBottom = dockInset + dockHeight + w * 0.035;
    const double dot = 7;
    final int rows = math.max(0, math.min(4, ((h - dotsBottom - dot - top) / rowPitch).floor()));
    final bool showWidget = rows >= 2;
    final List<Widget> grid = <Widget>[];
    int next = 0;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < 4; col++) {
        if (showWidget && row < 2 && col < 2) continue;
        grid.add(
          Positioned(
            left: (side + col * colPitch) * s,
            top: (top + row * rowPitch) * s,
            child: _icon(_iosGrid[next++ % _iosGrid.length], icon * s, palette, ios: true),
          ),
        );
      }
    }
    return Stack(
      children: <Widget>[
        if (showWidget)
          Positioned(
            left: side * s,
            top: top * s,
            child: _CalendarWidget(
              size: Size(colPitch + icon, rowPitch + icon) * s,
              style: iconStyle,
              scheme: palette,
              now: time,
            ),
          ),
        ...grid,
        Positioned(
          left: 0,
          right: 0,
          bottom: dotsBottom * s,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4 * s),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: textColor.withValues(alpha: i == 0 ? 0.95 : 0.45),
                    ),
                    child: SizedBox.square(dimension: dot * s),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: dockInset * s,
          right: dockInset * s,
          bottom: dockInset * s,
          height: dockHeight * s,
          child: _glass(
            shape: _withEdge(
              RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(dockHeight * 0.36 * s)),
              math.max(0.5, s),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: (side - dockInset) * s),
              child: Row(
                key: previewDockKey,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[for (final int app in _iosDock) _icon(app, icon * s, palette, ios: true)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _androidHome(
    BuildContext context,
    DateTime time,
    ColorScheme palette,
    double s,
    double w,
    double h,
    EdgeInsets device,
  ) {
    final double icon = math.min(w * 0.13, 64);
    final double side = w * 0.06;
    final double pillHeight = math.min(w * 0.13, 60);
    final double pillBottom = device.bottom + w * 0.04;
    final double dockBottom = pillBottom + pillHeight + w * 0.06;
    final double rowPitch = icon + w * 0.09;
    final bool themed = iconStyle == PreviewIconStyle.themed;
    final Color pillFill = themed ? palette.onPrimaryContainer : const Color(0xFFF1F3F8);
    final Color pillGlyph = themed ? palette.primaryContainer : const Color(0xFF5F6368);
    final int rows = math.max(0, math.min(2, ((h - dockBottom - icon - device.top - w * 0.3) / rowPitch).floor()));
    Widget iconRow(List<int> apps, {Key? key}) => Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[for (final int app in apps) _icon(app, icon * s, palette, ios: false)],
    );
    return Stack(
      children: <Widget>[
        Positioned(
          left: side * s,
          top: (device.top + w * 0.06) * s,
          child: Text(
            DateFormat.MMMEd(context.l10n.localeName).format(time),
            style: TextStyle(color: textColor, fontFamily: 'Roboto', fontSize: 22 * s, fontWeight: FontWeight.w400),
          ),
        ),
        for (int row = 0; row < rows; row++)
          Positioned(
            left: side * s,
            right: side * s,
            bottom: (dockBottom + (row + 1) * rowPitch) * s,
            child: iconRow(_androidGrid.sublist(row * 5, row * 5 + 5)),
          ),
        Positioned(
          left: side * s,
          right: side * s,
          bottom: dockBottom * s,
          child: iconRow(_androidDock, key: previewDockKey),
        ),
        Positioned(
          left: side * s,
          right: side * s,
          bottom: pillBottom * s,
          height: pillHeight * s,
          child: DecoratedBox(
            decoration: ShapeDecoration(color: pillFill, shape: const StadiumBorder()),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pillHeight * 0.36 * s),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Icon(Icons.search_rounded, size: pillHeight * 0.44 * s, color: pillGlyph),
                  Icon(Icons.mic_rounded, size: pillHeight * 0.4 * s, color: pillGlyph),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The 2x2 widget at the top of the iOS home screen: the weekday, the date, and two event bars.
class _CalendarWidget extends StatelessWidget {
  const _CalendarWidget({required this.size, required this.style, required this.scheme, required this.now});

  final Size size;
  final PreviewIconStyle style;
  final ColorScheme scheme;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final double unit = size.width / 160;
    final ShapeBorder shape = RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(size.width * 0.15));
    final (Color? fill, Color text, Color accent) = switch (style) {
      PreviewIconStyle.standard ||
      PreviewIconStyle.themed => (Colors.white, const Color(0xFF1C1C1E), const Color(0xFFFF3B30)),
      PreviewIconStyle.dark => (const Color(0xFF1C1C1E), Colors.white, const Color(0xFFFF453A)),
      PreviewIconStyle.clear => (null, Colors.white, Colors.white.withValues(alpha: 0.75)),
      PreviewIconStyle.tinted => (
        Color.alphaBlend(scheme.primary.withValues(alpha: 0.2), const Color(0xF0141416)),
        scheme.primary,
        scheme.primary.withValues(alpha: 0.75),
      ),
    };
    final String locale = context.l10n.localeName;
    final Widget content = SizedBox.fromSize(
      size: size,
      child: Padding(
        padding: EdgeInsets.all(14 * unit),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              DateFormat.EEEE(locale).format(now),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: accent,
                fontFamily: 'CupertinoSystemText',
                fontSize: 14 * unit,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              DateFormat.d(locale).format(now),
              style: TextStyle(
                color: text,
                fontFamily: 'CupertinoSystemDisplay',
                fontSize: 46 * unit,
                fontWeight: FontWeight.w300,
                height: 1.05,
              ),
            ),
            const Spacer(),
            for (final double width in const <double>[0.8, 0.55])
              Padding(
                padding: EdgeInsets.only(top: 6 * unit),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: text.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(4 * unit),
                  ),
                  child: SizedBox(width: (size.width - 28 * unit) * width, height: 10 * unit),
                ),
              ),
          ],
        ),
      ),
    );
    if (fill == null) return _glass(shape: _withEdge(shape, math.max(0.5, unit)), child: content);
    return DecoratedBox(
      decoration: ShapeDecoration(color: fill, shape: shape),
      child: content,
    );
  }
}
