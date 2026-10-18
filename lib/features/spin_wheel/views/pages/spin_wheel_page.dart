import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:Prism/features/spin_wheel/biz/wheel_machine_controller.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:Prism/features/spin_wheel/views/widgets/coin_burst.dart';
import 'package:Prism/features/spin_wheel/views/widgets/spin_button.dart';
import 'package:Prism/features/spin_wheel/views/widgets/spin_plinth.dart';
import 'package:Prism/features/spin_wheel/views/widgets/spin_result_panel.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_geometry.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_machine.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_odds_sheet.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

typedef SpinFunction = Future<SpinWheelResult> Function({required int maxCost});

/// Opens the spin machine over everything, including the bottom bar. The route fades in and scales up from 0.96.
Future<void> showSpinWheel(BuildContext context) {
  CoinsService.instance.refreshSpinWheelStatus();
  final Duration duration = context.motion(PrismDurations.base);
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'SpinWheel'),
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondary) =>
          const SpinWheelPage(),
      transitionsBuilder:
          (BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) {
            final Animation<double> curved = CurvedAnimation(parent: animation, curve: PrismCurves.enter);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(curved), child: child),
            );
          },
    ),
  );
}

enum _Stage { idle, spinning, landed }

/// The spin machine: a full-screen stage with the wheel, the plinth and the SPIN button.
///
/// [spin], [status] and [balance] default to the live coins service. A test or a render passes its own.
class SpinWheelPage extends StatefulWidget {
  const SpinWheelPage({super.key, this.spin, this.status, this.balance});

  final SpinFunction? spin;
  final ValueListenable<SpinWheelStatus>? status;

  final ValueListenable<int>? balance;

  @override
  State<SpinWheelPage> createState() => _SpinWheelPageState();
}

class _SpinWheelPageState extends State<SpinWheelPage> with TickerProviderStateMixin {
  late final WheelMachineController _machine;
  late final Ticker _ticker;
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  final math.Random _random = math.Random();

  late ValueListenable<SpinWheelStatus> _statusSource;
  late ValueListenable<int> _balanceSource;
  late SpinWheelStatus _status;
  late int _balance;
  int _delta = 0;
  Timer? _deltaTimer;

  List<WheelSegment> _segments = CoinPolicy.spinWheel;
  _Stage _stage = _Stage.idle;
  SpinWon? _won;
  int? _winner;

  /// The server said the balance is short, whatever the page shows, until the balance changes.
  bool _shortOverride = false;

  /// What to show once the wheel has stopped after a refusal or a failure.
  VoidCallback? _afterStop;

  SpinFunction get _spin => widget.spin ?? CoinsService.instance.spinWheel;

  bool get _spinInFlight => _stage == _Stage.spinning;

  @override
  void initState() {
    super.initState();
    _statusSource = widget.status ?? CoinsService.instance.spinWheelNotifier;
    _balanceSource = widget.balance ?? CoinsService.instance.balanceNotifier;
    _status = _statusSource.value;
    _balance = _balanceSource.value;
    _statusSource.addListener(_onStatusChanged);
    _balanceSource.addListener(_onBalanceChanged);
    _machine = WheelMachineController(
      segmentCount: _segments.length,
      onPegPass: PrismHaptics.selection,
      onLanded: _onLanded,
      onStopped: _onStopped,
    );
    _ticker = createTicker(_machine.tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = context.reduceMotion;
    _machine.setReduceMotion(reduce: reduce);
    if (reduce) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _statusSource.removeListener(_onStatusChanged);
    _balanceSource.removeListener(_onBalanceChanged);
    _deltaTimer?.cancel();
    _ticker.dispose();
    _burst.dispose();
    _machine.dispose();
    super.dispose();
  }

  void _onStatusChanged() {
    if (_spinInFlight) return;
    setState(() => _status = _statusSource.value);
  }

  void _onBalanceChanged() {
    if (_spinInFlight) return;
    setState(() {
      _balance = _balanceSource.value;
      _shortOverride = false;
    });
  }

  SpinAction get _action {
    final SpinAction action = spinAction(status: _status, balance: _balance);
    return action == SpinAction.spin && _shortOverride && !_status.freeSpinAvailable ? SpinAction.getCoins : action;
  }

  Future<void> _onSpin() async {
    if (_spinInFlight) return;
    switch (_action) {
      case SpinAction.capped:
        return;
      case SpinAction.getCoins:
        unawaited(_getCoins());
        return;
      case SpinAction.spin:
        break;
    }
    PrismHaptics.tap();
    final int cost = _status.nextCost;
    final int before = _balance;
    _deltaTimer?.cancel();
    setState(() {
      _stage = _Stage.spinning;
      _won = null;
      _balance = before - cost;
      _delta = -cost;
    });
    if (!context.reduceMotion) _machine.start();
    SpinWheelResult result;
    try {
      result = await _spin(maxCost: cost);
    } on Object {
      result = const SpinFailed('error');
    }
    if (!mounted) return;
    switch (result) {
      case final SpinWon won:
        _onWon(won);
      case final SpinRefused refused:
        _afterStop = () => _onRefused(refused);
        _machine.stop();
      case SpinFailed():
        _afterStop = () => _onFailed(before);
        _machine.stop();
    }
  }

  void _onWon(SpinWon result) {
    final int count = result.segments.length;
    final int index = result.win.segment.clamp(0, count - 1);
    final double offset = 0.2 + 0.6 * _random.nextDouble();
    setState(() {
      _segments = result.segments;
      _won = result;
    });
    _machine.land(index: index, count: count, offset: offset);
  }

  void _onLanded() {
    final SpinWon? won = _won;
    if (!mounted || won == null) return;
    PrismHaptics.success();
    if (!context.reduceMotion && won.win.coins > 0 && !_isXp(won)) {
      _burst.forward(from: 0);
    }
    setState(() {
      _winner = won.win.segment.clamp(0, won.segments.length - 1);
      _stage = _Stage.landed;
      _status = won.status;
      _balance = won.balance;
      _delta = won.win.coins - won.cost;
      _shortOverride = false;
    });
    _deltaTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _delta = 0);
    });
  }

  bool _isXp(SpinWon won) => won.segments[won.win.segment.clamp(0, won.segments.length - 1)].prize is XpPrize;

  void _onStopped() {
    final VoidCallback? after = _afterStop;
    _afterStop = null;
    if (!mounted) return;
    after?.call();
  }

  void _onRefused(SpinRefused result) {
    setState(() {
      _stage = _Stage.idle;
      _status = result.status;
      _balance = _balanceSource.value;
      _delta = 0;
      _shortOverride = result.refusal == SpinRefusal.insufficientBalance;
    });
    if (result.refusal == SpinRefusal.priceChanged) {
      toasts.info('The price changed. Check it and spin again.');
    }
  }

  void _onFailed(int before) {
    setState(() {
      _stage = _Stage.idle;
      _balance = before;
      _delta = 0;
    });
    toasts.error("Couldn't reach Prism. Try again.");
  }

  /// The short-balance flow: one sheet that offers a video for coins.
  Future<void> _getCoins() async {
    final bool watch =
        await showPrismSheet<bool>(
          context: context,
          builder: (BuildContext sheetContext) => PrismSheetBody(
            title: 'Not enough coins',
            message: 'A spin costs ${_status.price} coins. You have $_balance. Watch a video to earn more.',
            mood: GlintMood.worried,
            centered: true,
            actions: <Widget>[
              PrismButton(
                label: 'Watch a video (+${CoinsService.instance.adsRewardNow})',
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              PrismButton(
                label: 'Not now',
                expand: true,
                variant: PrismButtonVariant.ghost,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ) ??
        false;
    if (!watch || !mounted) return;
    final int reward = CoinsService.instance.adsRewardNow;
    final bool credited = await CoinGate.forContext(context).watchAdForCoins(
      sourceTag: 'coins.spin_wheel.rewarded_ad',
      upsellSource: 'spin_wheel_rewarded_ad',
      isMounted: () => mounted,
      adErrorMessage: 'Ad was not completed.',
    );
    if (credited) toasts.success('+$reward coins');
  }

  void _openPaywall() {
    unawaited(
      PaywallOrchestrator.instance.presentOrRequireSignIn(
        context,
        placement: PaywallPlacement.mainUpsell,
        source: 'spin_wheel_pro_row',
      ),
    );
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool pro = app_state.prismUser.premium;
    // A paid spin finishes on screen: closing mid-spin would hide a prize the user already paid for.
    return PopScope(
      canPop: !_spinInFlight,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final _StageLayout layout = _StageLayout.fit(constraints.biggest, showProRow: !pro);
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  height: math.max(constraints.maxHeight, layout.height),
                  width: constraints.maxWidth,
                  child: Stack(children: <Widget>[_aura(layout, cs), _content(context, layout, pro)]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _aura(_StageLayout layout, ColorScheme cs) {
    final double size = layout.diameter * 2.5;
    final bool dark = cs.brightness == Brightness.dark;
    return Positioned(
      left: layout.width / 2 - size / 2,
      top: layout.wheelCentreY - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: <Color>[
                cs.primary.withValues(alpha: dark ? 0.75 : 0.55),
                cs.primary.withValues(alpha: dark ? 0.55 : 0.4),
                cs.primary.withValues(alpha: dark ? 0.2 : 0.14),
                cs.primary.withValues(alpha: 0),
              ],
              stops: const <double>[0, 0.4, 0.66, 1],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, _StageLayout layout, bool pro) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final WheelPalette palette = WheelPalette.of(cs);
    final WheelGeometry geometry = WheelGeometry(layout.diameter);
    final double plinthWidth = math.min(layout.width - 24, 368);
    final double blockHeight = layout.topPad + layout.diameter + PlinthMetrics.visibleHeight;
    final Duration slide = context.motion(PrismDurations.base);
    return Padding(
      padding: EdgeInsets.only(top: layout.topSpare),
      child: Column(
        children: <Widget>[
          _TopBar(balance: _balance, delta: _delta, low: _action == SpinAction.getCoins, onClose: _close),
          SizedBox(
            height: _StageLayout.titleBand,
            child: Center(
              child: Semantics(header: true, child: Text('Spin the wheel', style: PrismTextStyles.display(context))),
            ),
          ),
          SizedBox(
            width: layout.width,
            height: blockHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: (layout.width - plinthWidth) / 2,
                  top: layout.topPad + layout.diameter - geometry.plinthOverlap,
                  child: SpinPlinth(
                    geometry: geometry,
                    width: plinthWidth,
                    palette: palette,
                    bulbs: _machine.bulbs,
                    child: AnimatedSwitcher(
                      duration: slide,
                      switchInCurve: PrismCurves.enter,
                      switchOutCurve: PrismCurves.exit,
                      // One fades out in the first half, the other fades in during the second, so they never overlap.
                      transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
                        opacity: CurvedAnimation(parent: animation, curve: const Interval(0.5, 1)),
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _stage == _Stage.landed && _won != null
                          ? _result(_won!, palette)
                          : Center(
                              key: const ValueKey<String>('button'),
                              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 232), child: _button()),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  left: (layout.width - layout.diameter) / 2,
                  top: layout.topPad,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: _stage == _Stage.landed ? 1 : 0),
                    duration: context.motion(PrismDurations.slow),
                    curve: PrismCurves.enter,
                    builder: (BuildContext context, double dim, Widget? _) => WheelMachine(
                      segments: _segments,
                      geometry: geometry,
                      theta: _machine.theta,
                      flapper: _machine.flapperAngle,
                      bulbs: _machine.bulbs,
                      winner: _winner,
                      dim: dim,
                    ),
                  ),
                ),
                if (!context.reduceMotion)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: layout.topPad,
                    height: layout.diameter,
                    child: CoinBurst(animation: _burst, radius: layout.diameter * 0.62, count: _isJackpot() ? 12 : 8),
                  ),
              ],
            ),
          ),
          const SizedBox(height: PrismSpace.sm),
          _OddsPill(onTap: () => unawaited(showWheelOdds(context, _segments))),
          const SizedBox(height: PrismSpace.xxs),
          Text(spinsLeftCaption(_status), style: PrismTextStyles.caption(context)),
          if (!pro) ...<Widget>[
            const SizedBox(height: PrismSpace.md),
            Padding(
              padding: PrismSpace.pageInsets,
              child: _ProRow(onTap: _openPaywall),
            ),
          ],
        ],
      ),
    );
  }

  bool _isJackpot() {
    final SpinWon? won = _won;
    return won != null && _winner != null && _winner == jackpotIndex(won.segments);
  }

  Widget _button() {
    final SpinAction action = _action;
    final bool free = _status.freeSpinAvailable;
    if (_spinInFlight) {
      return SpinButton(
        label: 'SPIN',
        semanticLabel: 'Spinning',
        caption: free ? 'Free spin' : null,
        price: free ? null : _status.nextCost,
        pressed: true,
        onPressed: null,
      );
    }
    return switch (action) {
      SpinAction.spin => SpinButton(
        label: 'SPIN',
        semanticLabel: free ? 'Spin, free spin' : 'Spin, ${_status.nextCost} coins',
        caption: free ? 'Free spin' : null,
        price: free ? null : _status.nextCost,
        onPressed: _onSpin,
      ),
      SpinAction.getCoins => SpinButton(
        label: 'Get coins',
        semanticLabel: 'Get coins. A spin costs ${_status.price} coins',
        caption: 'A spin costs ${_status.price} coins',
        onPressed: _onSpin,
      ),
      SpinAction.capped => const SpinButton(
        label: 'Back tomorrow',
        semanticLabel: 'Back tomorrow',
        caption: 'All spins used',
        onPressed: null,
      ),
    };
  }

  Widget _result(SpinWon won, WheelPalette palette) {
    final int index = (_winner ?? 0).clamp(0, won.segments.length - 1);
    return SpinResultPanel(
      key: ValueKey<SpinWon>(won),
      win: won.win,
      prize: won.segments[index].prize,
      jackpot: index == jackpotIndex(won.segments),
      status: _status,
      action: _action,
      ink: palette.plinthInk,
      onSpinAgain: _onSpin,
      onDone: _close,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.balance, required this.delta, required this.low, required this.onClose});

  final int balance;
  final int delta;
  final bool low;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
        child: Row(
          children: <Widget>[
            PrismIconButton(icon: Icons.close_rounded, tooltip: 'Close', filled: true, onPressed: onClose),
            const Spacer(),
            CoinBalancePill(balance: balance, delta: delta, low: low),
            const SizedBox(width: PrismSpace.xs),
          ],
        ),
      ),
    );
  }
}

/// One quiet row for people who are not Pro. It opens the paywall.
class _ProRow extends StatelessWidget {
  const _ProRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PrismCard(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.sm),
      semanticLabel: 'Pro members get a free spin every day',
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(Icons.workspace_premium_outlined, size: 20, color: cs.onSurface),
          const SizedBox(width: PrismSpace.sm),
          Expanded(
            child: Text(
              'Pro members get a free spin every day',
              style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}

class _OddsPill extends StatelessWidget {
  const _OddsPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PressScale(
      child: Semantics(
        button: true,
        label: 'See the odds',
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurface),
                      const SizedBox(width: 6),
                      Text('See the odds', style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where everything goes on one screen: the wheel is as big as the screen allows, up to 340.
class _StageLayout {
  const _StageLayout({required this.width, required this.diameter, required this.topSpare, required this.height});

  factory _StageLayout.fit(Size size, {required bool showProRow}) {
    final double proRow = showProRow ? proRowHeight : 0;
    final double fixed = barHeight + titleBand + 6 + PlinthMetrics.visibleHeight + footerHeight + proRow + 16;
    final double byHeight = (size.height - fixed) / 1.06;
    final double d = math.min(math.min(340, size.width - 48), byHeight).clamp(232, 340).toDouble();
    final double height = fixed + 1.06 * d;
    final double spare = math.max(0, size.height - height);
    return _StageLayout(width: size.width, diameter: d, topSpare: spare * 0.45, height: height);
  }

  static const double barHeight = 56;
  static const double titleBand = 44;
  static const double footerHeight = 12 + 44 + 4 + 18;
  static const double proRowHeight = 16 + 56;

  final double width;
  final double diameter;

  /// Space above the top bar, so a tall screen does not leave the stage top-heavy.
  final double topSpare;

  /// Height the content needs. A shorter screen scrolls.
  final double height;

  double get topPad => diameter * 0.06 + 6;
  double get wheelCentreY => topSpare + barHeight + titleBand + topPad + diameter / 2;
}
