// Frame cost of the Winter snowfall. Run in profile mode on a device:
//   fvm flutter run --profile -t tool/perf/snow_frame_bench.dart -d <device>
// Phase "baseline" drives frames with an empty repaint. Phase "snow" adds WinterSnowfall. The difference is its cost.
import 'dart:async';
import 'dart:ui';

import 'package:Prism/features/theme_mode/views/widgets/winter_decor.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const Duration _phase = Duration(seconds: 10);

void main() => runApp(const _Bench());

class _Bench extends StatefulWidget {
  const _Bench();

  @override
  State<_Bench> createState() => _BenchState();
}

class _BenchState extends State<_Bench> with SingleTickerProviderStateMixin {
  late final AnimationController _driver = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat();
  final List<FrameTiming> _timings = <FrameTiming>[];
  bool _snow = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_timings.addAll);
    unawaited(_run());
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    _timings.clear();
    await Future<void>.delayed(_phase);
    _report('baseline');
    setState(() => _snow = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    _timings.clear();
    await Future<void>.delayed(_phase);
    _report('snow');
  }

  void _report(String phase) {
    double ms(Duration d) => d.inMicroseconds / 1000;
    String stats(List<double> v) {
      v.sort();
      final double mean = v.reduce((a, b) => a + b) / v.length;
      return 'mean ${mean.toStringAsFixed(3)} p90 ${v[(v.length * 0.9).floor()].toStringAsFixed(3)} '
          'max ${v.last.toStringAsFixed(3)}';
    }

    final List<FrameTiming> frames = List<FrameTiming>.of(_timings);
    // ignore: avoid_print
    print(
      'SNOW_BENCH $phase frames ${frames.length} '
      'build {${stats(frames.map((f) => ms(f.buildDuration)).toList())}} '
      'raster {${stats(frames.map((f) => ms(f.rasterDuration)).toList())}}',
    );
  }

  @override
  void dispose() {
    _driver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = Column(
      children: <Widget>[
        for (int i = 0; i < 6; i++)
          Expanded(child: ColoredBox(color: Color.lerp(const Color(0xFF16304A), const Color(0xFF8CC4EE), i / 6)!)),
      ],
    );
    return MaterialApp(
      theme: kDarkTheme11,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            if (_snow) WinterSnowfall(headerHeight: 150, powerSaver: () async => false, child: body) else body,
            Positioned(
              left: 0,
              top: 0,
              child: AnimatedBuilder(
                animation: _driver,
                builder: (_, _) => CustomPaint(size: const Size(1, 1), painter: _Dot(_driver.value)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends CustomPainter {
  _Dot(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawRect(Offset.zero & size, Paint()..color = Color.fromARGB((t * 255).round(), 0, 0, 0));

  @override
  bool shouldRepaint(_Dot old) => old.t != t;
}
