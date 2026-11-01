import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/promo_codes/data/promo_code_repository.dart';
import 'package:Prism/features/promo_codes/domain/entities/promo_code.dart';
import 'package:Prism/features/promo_codes/views/store_code_redemption.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const int _maxInputLength = 40;

void _applyGrant(RedeemSucceeded result) {
  final CoinsService coins = CoinsService.instance;
  if (result.replayed) {
    // A replay contains the original transaction totals, not necessarily today's balance or pass state.
    unawaited(coins.refreshBalance().catchError((Object _) => app_state.prismUser.coins));
    return;
  }
  switch (result.reward) {
    case CoinsReward():
      final int? balance = result.coinBalance;
      if (balance != null) coins.applyServerBalance(balance, ownerId: app_state.prismUser.id);
    case PremiumDaysReward(:final until):
      if (until != null) {
        final DateTime? currentUntil = coins.passesNotifier.value.premiumPassUntil;
        final DateTime longerUntil = currentUntil != null && currentUntil.isAfter(until) ? currentUntil : until;
        coins.passesNotifier.value = coins.passesNotifier.value.copyWith(premiumPassUntil: longerUntil);
      }
  }
}

/// Opens the redeem sheet. A link passes [initialCode]; the sheet fills it in and waits for the user to tap Redeem.
Future<void> showRedeemCodeSheet(
  BuildContext context, {
  required RedeemSheetSource source,
  String? initialCode,
  PromoCodeRepository? repository,
  void Function(RedeemSucceeded result) onRedeemed = _applyGrant,
}) async {
  if (!await requireSignedInAction(context) || !context.mounted) return;
  unawaited(analytics.track(RedeemSheetOpenedEvent(source: source)));
  await showPrismSheet<void>(
    context,
    dismissKeyboardOnDrag: true,
    builder: (_) => RedeemCodeBody(
      repository: repository ?? PromoCodeRepository(),
      initialCode: initialCode,
      onRedeemed: onRedeemed,
    ),
  );
}

String _redeemError(AppLocalizations l10n, RedeemFailureReason reason) => switch (reason) {
  RedeemFailureReason.invalidCode => l10n.promoErrorInvalid,
  RedeemFailureReason.notFound => l10n.promoErrorNotFound,
  RedeemFailureReason.disabled => l10n.promoErrorDisabled,
  RedeemFailureReason.expired => l10n.promoErrorExpired,
  RedeemFailureReason.limitReached => l10n.promoErrorLimitReached,
  RedeemFailureReason.alreadyRedeemed => l10n.promoErrorAlreadyRedeemed,
  RedeemFailureReason.accountTooNew => l10n.promoErrorAccountTooNew,
  RedeemFailureReason.newUsersOnly => l10n.promoErrorNewUsersOnly,
  RedeemFailureReason.premiumNotOnIos => l10n.promoErrorPremiumNotOnIos,
  RedeemFailureReason.alreadyPremium => l10n.promoErrorAlreadyPremium,
  RedeemFailureReason.rateLimited => l10n.promoErrorRateLimited,
  RedeemFailureReason.busy => l10n.promoErrorBusy,
  RedeemFailureReason.signedOut => l10n.promoErrorSignedOut,
  RedeemFailureReason.network => l10n.promoErrorNetwork,
  RedeemFailureReason.unknown => l10n.promoErrorUnknown,
};

// Failures where the same attempt can run again; the server replays a finished one instead of granting twice.
const Set<RedeemFailureReason> _retryable = <RedeemFailureReason>{
  RedeemFailureReason.network,
  RedeemFailureReason.busy,
  RedeemFailureReason.unknown,
};

sealed class _Phase {
  const _Phase();
}

final class _Editing extends _Phase {
  const _Editing([this.failure]);

  final RedeemFailureReason? failure;
}

final class _Redeeming extends _Phase {
  const _Redeeming();
}

final class _Redeemed extends _Phase {
  const _Redeemed(this.reward);

  final PromoReward reward;
}

@visibleForTesting
class RedeemCodeBody extends StatefulWidget {
  const RedeemCodeBody({super.key, required this.repository, required this.onRedeemed, this.initialCode});

  final PromoCodeRepository repository;
  final void Function(RedeemSucceeded result) onRedeemed;
  final String? initialCode;

  @override
  State<RedeemCodeBody> createState() => _RedeemCodeBodyState();
}

class _RedeemCodeBodyState extends State<RedeemCodeBody> {
  late final TextEditingController _code = TextEditingController(text: _clean(widget.initialCode ?? ''));
  final FocusNode _focus = FocusNode();
  _Phase _phase = const _Editing();
  ({String code, String requestId})? _lastAttempt;

  static String _clean(String raw) {
    final String kept = raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9 -]'), '').trim();
    return kept.length > _maxInputLength ? kept.substring(0, _maxInputLength) : kept;
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String pasted = _clean(data?.text ?? '');
    if (!mounted || pasted.isEmpty) return;
    _code.value = TextEditingValue(
      text: pasted,
      selection: TextSelection.collapsed(offset: pasted.length),
    );
    setState(() => _phase = const _Editing());
  }

  Future<void> _redeem() async {
    if (_phase is _Redeeming) return;
    final String code = normalizePromoCode(_code.text);
    if (!isPromoCodeShape(code)) {
      _fail(RedeemFailureReason.invalidCode);
      return;
    }
    _focus.unfocus();
    final ({String code, String requestId})? last = _lastAttempt;
    final String requestId = last != null && last.code == code ? last.requestId : newPromoRequestId();
    _lastAttempt = (code: code, requestId: requestId);
    final String ownerId = app_state.prismUser.id;
    setState(() => _phase = const _Redeeming());
    final RedeemOutcome outcome = await widget.repository.redeem(
      code,
      requestId: requestId,
      platform: storeCodePlatform,
    );
    if (!mounted) return;
    switch (outcome) {
      case RedeemSucceeded(:final reward):
        if (ownerId != app_state.prismUser.id) {
          _lastAttempt = null;
          _fail(RedeemFailureReason.signedOut);
          return;
        }
        unawaited(analytics.track(RedeemSucceededEvent(type: reward.type)));
        widget.onRedeemed(outcome);
        unawaited(HapticFeedback.mediumImpact());
        setState(() => _phase = _Redeemed(reward));
      case RedeemFailed(:final reason):
        if (!_retryable.contains(reason)) _lastAttempt = null;
        _fail(reason);
    }
  }

  void _fail(RedeemFailureReason reason) {
    unawaited(analytics.track(RedeemFailedEvent(reason: reason)));
    setState(() => _phase = _Editing(reason));
    SemanticsService.sendAnnouncement(View.of(context), _redeemError(context.l10n, reason), Directionality.of(context));
  }

  Widget _editing(BuildContext context, AppLocalizations l10n) {
    final _Phase phase = _phase;
    final bool busy = phase is _Redeeming;
    final RedeemFailureReason? failure = phase is _Editing ? phase.failure : null;
    return PrismSheetBody(
      key: const ValueKey<String>('redeem-editing'),
      title: l10n.promoRedeemTitle,
      message: storeCodePlatform == StoreCodePlatform.ios ? l10n.promoRedeemMessageIos : l10n.promoRedeemMessage,
      actions: <Widget>[
        Semantics(
          label: busy ? l10n.promoRedeeming : null,
          child: PrismButton(
            label: l10n.promoRedeemAction,
            loading: busy,
            expand: true,
            maxLines: 2,
            onPressed: _redeem,
          ),
        ),
      ],
      child: PrismTextField(
        controller: _code,
        focusNode: _focus,
        autofocus: widget.initialCode == null,
        enabled: !busy,
        label: l10n.promoCodeFieldLabel,
        hint: l10n.promoCodeFieldHint,
        error: failure == null ? null : _redeemError(l10n, failure),
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 -]')),
          LengthLimitingTextInputFormatter(_maxInputLength),
          TextInputFormatter.withFunction(
            (TextEditingValue _, TextEditingValue next) => next.copyWith(text: next.text.toUpperCase()),
          ),
        ],
        onChanged: (_) {
          if (failure != null) setState(() => _phase = const _Editing());
        },
        onSubmitted: (_) => _redeem(),
        suffix: PrismIconButton(
          icon: Icons.content_paste_rounded,
          tooltip: l10n.promoPasteCode,
          onPressed: busy ? null : _paste,
        ),
      ),
    );
  }

  Widget _redeemed(BuildContext context, AppLocalizations l10n, PromoReward reward) {
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final (String headline, String message) = switch (reward) {
      CoinsReward(:final coins) => (l10n.promoSuccessCoins(coins), l10n.promoSuccessCoinsMessage),
      PremiumDaysReward(:final days, :final until) => (
        l10n.promoSuccessPro(days),
        until == null ? '' : l10n.promoSuccessProMessage(DateFormat.yMMMd(locale).format(until)),
      ),
    };
    return Semantics(
      key: const ValueKey<String>('redeem-done'),
      liveRegion: true,
      child: PrismSheetBody(
        mood: GlintMood.celebrate,
        centered: true,
        title: headline,
        message: message.isEmpty ? null : message,
        actions: <Widget>[
          PrismButton(label: l10n.promoDone, expand: true, maxLines: 2, onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final _Phase phase = _phase;
    return AnimatedSwitcher(
      duration: context.motion(PrismDurations.base),
      switchInCurve: PrismCurves.enter,
      switchOutCurve: PrismCurves.enter,
      transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1).animate(animation), child: child),
      ),
      child: phase is _Redeemed ? _redeemed(context, l10n, phase.reward) : _editing(context, l10n),
    );
  }
}
