import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/daily_chest/domain/chest_action.dart';
import 'package:Prism/features/daily_chest/domain/chest_copy.dart';
import 'package:Prism/features/daily_chest/domain/chest_phase.dart';
import 'package:Prism/features/daily_chest/domain/chest_tiers.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_box.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_odds_sheet.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_reveal_card.dart';
import 'package:Prism/features/spin_wheel/spin_wheel.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef OpenChestFunction = Future<DailyChestResult> Function({required int maxCost});

/// The shake has to read before the box opens, so a quick reply waits this long.
const Duration _chargeHold = Duration(milliseconds: 600);

/// Opens the chest over everything, including the bottom bar. The route fades in and scales up from 0.96.
Future<void> showDailyChest(BuildContext context) {
  final Duration duration = context.motion(PrismDurations.base);
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'DailyChest'),
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondary) =>
          const DailyChestPage(),
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

/// The daily chest: a full-screen stage with the box, what it costs and the Open button.
///
/// [open], [quests], [balance], [refresh], [now] and [onOpenShop] default to the live coins service and the router.
/// A test or a render passes its own.
class DailyChestPage extends StatefulWidget {
  const DailyChestPage({super.key, this.open, this.quests, this.balance, this.refresh, this.now, this.onOpenShop});

  final OpenChestFunction? open;

  /// Today's quests. The chest status comes from them.
  final ValueListenable<QuestState?>? quests;

  /// The coin balance the page starts from.
  final ValueListenable<int>? balance;

  /// Syncs the quests with the server. The page calls it when it has no quests for today.
  final Future<void> Function()? refresh;
  final DateTime Function()? now;

  /// Called after the page has closed, when the user asks to see a cosmetic in the Shop.
  final VoidCallback? onOpenShop;

  @override
  State<DailyChestPage> createState() => _DailyChestPageState();
}

class _DailyChestPageState extends State<DailyChestPage> with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  late ValueListenable<QuestState?> _questsSource;
  late ValueListenable<int> _balanceSource;
  QuestState? _quests;
  late int _balance;
  int _delta = 0;
  Timer? _deltaTimer;
  Timer? _clockTimer;

  late ChestPhase _phase;
  ChestWon? _won;

  /// The prize card is up: it comes out of the box at the burst and stays.
  bool _cardUp = false;

  /// The server said the balance is short, whatever the page shows, until the balance changes.
  bool _shortOverride = false;

  /// The price the server named when it refused, which the cached config cannot know yet. It is for one UTC day.
  int? _priceOverride;

  OpenChestFunction get _open => widget.open ?? CoinsService.instance.openDailyChest;
  DateTime get _now => (widget.now ?? DateTime.now)();
  bool get _busy => _phase == ChestPhase.charging || _phase == ChestPhase.opening;

  @override
  void initState() {
    super.initState();
    _questsSource = widget.quests ?? CoinsService.instance.questsNotifier;
    _balanceSource = widget.balance ?? CoinsService.instance.balanceNotifier;
    _quests = _questsSource.value;
    _balance = _balanceSource.value;
    _questsSource.addListener(_onQuestsChanged);
    _balanceSource.addListener(_onBalanceChanged);
    _phase = _idlePhase();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (Timer _) => _onClock());
    if (_status == null) unawaited(_refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The box stops ticking once reduced motion turns on, so an open span that already started never ends.
    if (_phase == ChestPhase.opening && context.reduceMotion) {
      _onBurst();
      _onOpened();
    }
  }

  @override
  void dispose() {
    _questsSource.removeListener(_onQuestsChanged);
    _balanceSource.removeListener(_onBalanceChanged);
    _deltaTimer?.cancel();
    _clockTimer?.cancel();
    _burst.dispose();
    super.dispose();
  }

  /// Today's chest, or null while the quests for today have not arrived.
  DailyChestStatus? get _status {
    final DailyChestStatus? base = DailyChestStatus.fromQuests(
      _quests,
      today: economyDayKey(_now),
      price: CoinPolicy.dailyChestPrice,
    );
    if (base == null) return null;
    return DailyChestStatus(opened: base.opened, questsLeft: base.questsLeft, price: _priceOverride ?? base.price);
  }

  /// The phase of a chest nobody is opening: ready, or spent when it was opened today.
  ChestPhase _idlePhase() => (_status?.opened ?? false) ? ChestPhase.spent : ChestPhase.ready;

  ChestAction? get _action {
    final DailyChestStatus? status = _status;
    if (status == null) return null;
    final ChestAction action = chestAction(status: status, balance: _balance);
    return action == ChestAction.open && _shortOverride && !status.free ? ChestAction.getCoins : action;
  }

  Future<void> _refresh() => (widget.refresh ?? () => CoinsService.instance.progressQuest(null))();

  void _readQuests() {
    final QuestState? next = _questsSource.value;
    if (next?.dayKey != _quests?.dayKey) _priceOverride = null;
    _quests = next;
  }

  void _onQuestsChanged() {
    if (_busy) return;
    setState(() {
      _readQuests();
      if (_phase == ChestPhase.ready || _phase == ChestPhase.spent) _phase = _idlePhase();
    });
  }

  void _onBalanceChanged() {
    if (_busy) return;
    setState(() {
      _balance = _balanceSource.value;
      _shortOverride = false;
    });
  }

  void _onClock() {
    if (!mounted) return;
    if (_status == null) unawaited(_refresh());
    setState(() {});
  }

  Future<void> _onOpen() async {
    if (_phase != ChestPhase.ready) return;
    final DailyChestStatus? status = _status;
    switch (_action) {
      case null || ChestAction.spent:
        return;
      case ChestAction.getCoins:
        unawaited(_getCoins(status!));
        return;
      case ChestAction.open:
        break;
    }
    PrismHaptics.tap();
    final int cost = status!.nextCost;
    final int before = _balance;
    _deltaTimer?.cancel();
    setState(() {
      _phase = ChestPhase.charging;
      _won = null;
      _cardUp = false;
      _balance = before - cost;
      _delta = -cost;
    });
    final Future<DailyChestResult> reply = _send(cost);
    await Future.wait<void>(<Future<void>>[reply, Future<void>.delayed(context.motion(_chargeHold))]);
    final DailyChestResult result = await reply;
    if (!mounted) return;
    switch (result) {
      case final ChestWon won:
        _onWon(won);
      case final ChestRefused refused:
        _onRefused(refused);
      case ChestFailed():
        _onFailed(before);
    }
  }

  Future<DailyChestResult> _send(int cost) async {
    try {
      return await _open(maxCost: cost);
    } on Object {
      return const ChestFailed('error');
    }
  }

  void _onWon(ChestWon won) {
    setState(() {
      _won = won;
      _phase = ChestPhase.opening;
    });
    // Under reduced motion the box never ticks, so the prize shows at once.
    if (context.reduceMotion) {
      _onBurst();
      _onOpened();
    }
  }

  /// The light leaves the box: the prize comes out of it.
  void _onBurst() {
    final ChestWon? won = _won;
    if (!mounted || won == null || _cardUp) return;
    PrismHaptics.success();
    if (!context.reduceMotion && won.win.coins > 0 && won.prize is! XpPrize) _burst.forward(from: 0);
    setState(() {
      _cardUp = true;
      // The service moves the balance when the reply arrives, long before the box opens, so the pill waits for here.
      _balance = _balanceSource.value;
      _delta = won.win.coins - won.cost;
      _shortOverride = false;
    });
    _deltaTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _delta = 0);
    });
  }

  void _onOpened() {
    if (!mounted || _phase != ChestPhase.opening) return;
    if (!_cardUp) _onBurst();
    setState(() {
      _readQuests();
      _phase = ChestPhase.revealed;
    });
  }

  void _onRefused(ChestRefused refused) {
    setState(() {
      _readQuests();
      _balance = _balanceSource.value;
      _delta = 0;
      _shortOverride = refused.refusal == ChestRefusal.insufficientBalance;
      _priceOverride = refused.price ?? _priceOverride;
      _phase = _idlePhase();
    });
    if (refused.refusal == ChestRefusal.priceChanged) toasts.info('The price changed. Check it and open again.');
  }

  void _onFailed(int before) {
    setState(() {
      _readQuests();
      _phase = ChestPhase.ready;
      _balance = before;
      _delta = 0;
    });
    toasts.error("Couldn't reach Prism. Try again.");
  }

  Future<void> _getCoins(DailyChestStatus status) => showGetCoinsSheet(
    context,
    message: 'The chest costs ${status.price} coins. You have $_balance. Watch a video to earn more.',
    sourceTag: 'coins.daily_chest.rewarded_ad',
    upsellSource: 'daily_chest_rewarded_ad',
  );

  void _close() => Navigator.of(context).maybePop();

  /// Closes the page first, so the Shop opens on the screen the chest came from.
  Future<void> _openShop() async {
    final VoidCallback openShop = widget.onOpenShop ?? _shopRoute(context.router.root);
    await Navigator.of(context).maybePop();
    openShop();
  }

  VoidCallback _shopRoute(StackRouter root) =>
      () => unawaited(root.push(const ShopRoute()));

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    // A paid chest finishes on screen: closing mid-open would hide a prize the user already paid for.
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final _ChestLayout layout = _ChestLayout.fit(constraints.biggest);
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Stack(children: <Widget>[_aura(layout, cs), _content(context, layout)]),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The glow behind the box: the accent while it is closed, the colour of the prize's tier once the server has said.
  Widget _aura(_ChestLayout layout, ColorScheme cs) {
    final double size = layout.box * 2.6;
    final bool dark = cs.brightness == Brightness.dark;
    final Color target = _won?.tier.color ?? cs.primary;
    return Positioned(
      left: layout.width / 2 - size / 2,
      top: layout.boxCentreY - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target),
          duration: context.motion(PrismDurations.slow),
          curve: PrismCurves.enter,
          builder: (BuildContext context, Color? colour, Widget? _) {
            final Color c = colour ?? target;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: <Color>[
                    c.withValues(alpha: dark ? 0.6 : 0.45),
                    c.withValues(alpha: dark ? 0.4 : 0.3),
                    c.withValues(alpha: dark ? 0.14 : 0.1),
                    c.withValues(alpha: 0),
                  ],
                  stops: const <double>[0, 0.4, 0.66, 1],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, _ChestLayout layout) {
    return Padding(
      padding: EdgeInsets.only(top: layout.topSpare),
      child: Column(
        children: <Widget>[
          StageTopBar(
            balance: _balance,
            delta: _delta,
            low: _action == ChestAction.getCoins,
            onClose: _busy ? null : _close,
          ),
          _stage(context, layout),
          _actions(context),
          const SizedBox(height: PrismSpace.xs),
          _odds(context),
          const SizedBox(height: PrismSpace.md),
        ],
      ),
    );
  }

  /// The title and the prize card above, the box under them. The card is last so it rises over the box.
  Widget _stage(BuildContext context, _ChestLayout layout) {
    final ChestWon? won = _won;
    final Duration fade = context.motion(PrismDurations.fast);
    return SizedBox(
      width: layout.width,
      height: _ChestLayout.headerHeight + layout.box,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: (layout.width - layout.box) / 2,
            top: _ChestLayout.headerHeight,
            width: layout.box,
            height: layout.box,
            child: ChestBox(phase: _phase, glow: won?.tier.color, onBurst: _onBurst, onOpened: _onOpened),
          ),
          if (!context.reduceMotion)
            Positioned(
              left: 0,
              right: 0,
              top: _ChestLayout.headerHeight,
              height: layout.box,
              child: CoinBurst(
                animation: _burst,
                radius: layout.box * 0.7,
                count: won?.tier == ChestTier.legendary ? 12 : 8,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _ChestLayout.headerHeight,
            child: Align(
              // Low in the slot, so the title sits close to the box it names.
              alignment: const Alignment(0, 0.4),
              child: AnimatedOpacity(
                opacity: _cardUp ? 0 : 1,
                duration: fade,
                child: Semantics(header: true, child: Text('Daily chest', style: PrismTextStyles.display(context))),
              ),
            ),
          ),
          if (_cardUp && won != null)
            Positioned(
              left: PrismSpace.page,
              right: PrismSpace.page,
              top: 0,
              height: _ChestLayout.headerHeight,
              child: Center(
                child: _RisingCard(
                  key: ValueKey<ChestWon>(won),
                  rise: _ChestLayout.headerHeight / 2 + layout.box / 2,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: ChestRevealCard(won: won),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The odds are for a chest nobody is opening. While the box works, and once the prize is up, the pill would compete
  /// with Done and the Shop button. The slot keeps its height, so nothing on the page moves when it goes.
  Widget _odds(BuildContext context) {
    final bool idle = _phase == ChestPhase.ready || _phase == ChestPhase.spent;
    return AnimatedSwitcher(
      key: const ValueKey<String>('odds_slot'),
      duration: context.motion(PrismDurations.fast),
      child: idle
          ? OddsPill(
              key: const ValueKey<String>('odds'),
              onTap: () => unawaited(showChestOdds(context, CoinPolicy.dailyChest)),
            )
          : const SizedBox(key: ValueKey<String>('no_odds'), height: _ChestLayout.oddsHeight),
    );
  }

  /// What sits under the box: the cost and the Open button, or the prize's two exits once it is revealed.
  Widget _actions(BuildContext context) {
    final ChestWon? won = _won;
    final bool revealed = _phase == ChestPhase.revealed && won != null;
    final Duration slide = context.motion(PrismDurations.base);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _ChestLayout.actionsHeight),
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
        child: revealed ? _revealedActions(won) : _openActions(context),
      ),
    );
  }

  Widget _openActions(BuildContext context) {
    final DailyChestStatus? status = _status;
    final bool bonusDone = _quests?.bonus?.claimed ?? false;
    final Duration fade = context.motion(PrismDurations.fast);
    return Column(
      key: const ValueKey<String>('open'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedOpacity(
          opacity: _busy ? 0 : 1,
          duration: fade,
          child: ConstrainedBox(
            // Two even lines, not one long line and a lone word.
            constraints: const BoxConstraints(maxWidth: 300),
            child: status == null
                ? const SizedBox(height: 44)
                : Column(
                    children: <Widget>[
                      Text(
                        chestCostLine(status, now: _now),
                        textAlign: TextAlign.center,
                        style: PrismTextStyles.body(context).copyWith(height: 1.4),
                      ),
                      if (!status.opened) ...<Widget>[
                        const SizedBox(height: PrismSpace.xxs),
                        Text(
                          chestBonusLine(bonusDone: bonusDone),
                          textAlign: TextAlign.center,
                          style: PrismTextStyles.caption(context),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(height: PrismSpace.lg),
        // The button is 58 high. Past 1.15 its label and the price under it no longer fit.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 232), child: _button(status)),
        ),
      ],
    );
  }

  Widget _button(DailyChestStatus? status) {
    if (status == null) {
      return const SpinButton(label: 'Open', semanticLabel: 'Open the chest. Loading', onPressed: null);
    }
    final bool free = status.free;
    final int? price = free ? null : status.nextCost;
    final String label = free ? 'Open free' : 'Open';
    final String semantic = free ? 'Open the chest, free' : 'Open the chest, ${status.nextCost} coins';
    if (_busy) {
      return SpinButton(label: label, semanticLabel: 'Opening', price: price, pressed: true, onPressed: null);
    }
    return switch (_action!) {
      ChestAction.open => SpinButton(label: label, semanticLabel: semantic, price: price, onPressed: _onOpen),
      ChestAction.getCoins => SpinButton(
        label: 'Get coins',
        semanticLabel: 'Get coins. The chest costs ${status.price} coins',
        onPressed: _onOpen,
      ),
      ChestAction.spent => const SpinButton(label: 'Back tomorrow', semanticLabel: 'Back tomorrow', onPressed: null),
    };
  }

  Widget _revealedActions(ChestWon won) {
    final bool cosmetic = won.prize is CosmeticPrize && won.win.itemId != null;
    return ConstrainedBox(
      key: const ValueKey<String>('revealed'),
      constraints: const BoxConstraints(maxWidth: 280),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PrismButton(label: 'Done', expand: true, onPressed: _close),
            if (cosmetic) ...<Widget>[
              const SizedBox(height: PrismSpace.xs),
              PrismButton(
                label: 'See it in the Shop',
                expand: true,
                variant: PrismButtonVariant.ghost,
                onPressed: () => unawaited(_openShop()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The prize card coming out of the box: it starts [rise] below its place, small and clear, and settles.
class _RisingCard extends StatelessWidget {
  const _RisingCard({super.key, required this.rise, required this.child});

  final double rise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: context.motion(PrismDurations.slow),
      curve: PrismCurves.enter,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * rise),
          child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
        ),
      ),
    );
  }
}

/// Where everything goes on one screen: the box is as big as the screen allows, up to 320 and 70 % of the width.
class _ChestLayout {
  const _ChestLayout({required this.width, required this.box, required this.topSpare});

  factory _ChestLayout.fit(Size size) {
    const double fixed = barHeight + headerHeight + actionsHeight + footerHeight;
    final double byHeight = size.height - fixed;
    final double box = math.min(math.min(320, size.width * 0.7), byHeight).clamp(200, 320).toDouble();
    final double spare = math.max(0, size.height - fixed - box);
    return _ChestLayout(width: size.width, box: box, topSpare: spare * 0.4);
  }

  static const double barHeight = StageTopBar.height;

  /// The title, and the prize card in its place once it is up.
  static const double headerHeight = 168;

  /// The cost, the bonus line and the button: two lines of 14 and one of 12, the gap and the 66 high button.
  static const double actionsHeight = 150;

  /// The odds pill, or the empty slot that holds its place.
  static const double oddsHeight = OddsPill.height;

  /// The odds slot and the margins around it.
  static const double footerHeight = oddsHeight + PrismSpace.xs + PrismSpace.md;

  final double width;
  final double box;

  /// Space above the top bar, so a tall screen does not leave the stage top-heavy.
  final double topSpare;

  double get boxCentreY => topSpare + barHeight + headerHeight + box / 2;
}
