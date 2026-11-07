import 'dart:async';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_refresh.dart';
import 'package:Prism/features/promo_codes/data/promo_code_repository.dart';
import 'package:Prism/features/promo_codes/domain/entities/promo_code.dart';
import 'package:Prism/features/promo_codes/views/store_code_redemption.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Admin tool to create promo codes and turn them off. Reached only through the admin guard.
@RoutePage()
class PromoCodesAdminPage extends StatefulWidget {
  const PromoCodesAdminPage({super.key, this.repository});

  final PromoCodeRepository? repository;

  @override
  State<PromoCodesAdminPage> createState() => _PromoCodesAdminPageState();
}

class _PromoCodesAdminPageState extends State<PromoCodesAdminPage> {
  late final PromoCodeRepository _repository;

  final TextEditingController _amount = TextEditingController();
  final TextEditingController _maxRedemptions = TextEditingController(text: '1');
  final TextEditingController _expiresInDays = TextEditingController(text: '7');
  final TextEditingController _minAccountAge = TextEditingController(text: '0');
  final TextEditingController _newUsersDays = TextEditingController(text: '7');
  final TextEditingController _customCode = TextEditingController();
  final TextEditingController _label = TextEditingController();

  PromoRewardType _type = PromoRewardType.coins;
  bool _newUsersOnly = false;
  bool _creating = false;
  List<PromoCodeSummary>? _codes;
  bool _loadFailed = false;
  final Set<String> _busyCodes = <String>{};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PromoCodeRepository();
    unawaited(_reload());
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _amount,
      _maxRedemptions,
      _expiresInDays,
      _minAccountAge,
      _newUsersDays,
      _customCode,
      _label,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Keeps the current list on screen while a refresh runs; only a failed load replaces it with the error state.
  Future<void> _reload() async {
    try {
      final List<PromoCodeSummary> codes = await _repository.listCodes();
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _loadFailed = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _codes = null;
        _loadFailed = true;
      });
    }
  }

  void _retry() {
    setState(() => _loadFailed = false);
    unawaited(_reload());
  }

  int _number(TextEditingController controller) => int.tryParse(controller.text) ?? 0;

  bool get _canCreate =>
      !_creating &&
      _number(_amount) > 0 &&
      _number(_maxRedemptions) > 0 &&
      _number(_expiresInDays) > 0 &&
      _minAccountAge.text.isNotEmpty &&
      (!_newUsersOnly || _number(_newUsersDays) > 0);

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() => _creating = true);
    try {
      final String code = await _repository.createCode(
        NewPromoCode(
          type: _type,
          amount: _number(_amount),
          maxRedemptions: _number(_maxRedemptions),
          expiresAt: DateTime.now().add(Duration(days: _number(_expiresInDays))),
          code: _customCode.text.isEmpty ? null : normalizePromoCode(_customCode.text),
          minAccountAgeDays: _number(_minAccountAge),
          newUsersOnlyDays: _newUsersOnly ? _number(_newUsersDays) : null,
          label: _label.text.trim(),
        ),
      );
      if (!mounted) return;
      toasts.success(context.l10n.promoAdminCreated(code));
      _customCode.clear();
      _label.clear();
      await _reload();
    } on cf.FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      toasts.error(context.l10n.promoAdminCreateFailed(error.message ?? error.code));
    } on Object {
      if (mounted) toasts.error(context.l10n.coreSomethingWentWrong);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _setDisabled(PromoCodeSummary code, {required bool disabled}) async {
    setState(() => _busyCodes.add(code.code));
    try {
      await _repository.setDisabled(code.code, disabled: disabled);
      await _reload();
    } on cf.FirebaseFunctionsException catch (error) {
      if (mounted) toasts.error(error.message ?? error.code);
    } on Object {
      if (mounted) toasts.error(context.l10n.coreSomethingWentWrong);
    } finally {
      if (mounted) setState(() => _busyCodes.remove(code.code));
    }
  }

  void _copy(PromoCodeSummary code) {
    unawaited(Clipboard.setData(ClipboardData(text: code.code)));
    toasts.success(context.l10n.promoAdminCopied);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PrismPage(
      title: l10n.promoAdminTitle,
      body: PrismRefresh(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.xxl),
          children: <Widget>[
            _buildForm(l10n),
            PrismSectionHeader(title: l10n.promoSettingsGroup),
            _buildCodes(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    const SizedBox gap = SizedBox(height: PrismSpace.md);
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrismSegmented<PromoRewardType>(
            values: storeCodePlatform == StoreCodePlatform.ios
                ? const <PromoRewardType>[PromoRewardType.coins]
                : PromoRewardType.values,
            selected: _type,
            labelOf: (PromoRewardType type) =>
                type == PromoRewardType.coins ? l10n.promoAdminTypeCoins : l10n.promoAdminTypePro,
            onChanged: (PromoRewardType type) => setState(() => _type = type),
          ),
          gap,
          _numberField(
            controller: _amount,
            label: l10n.promoAdminAmount,
            helper: _type == PromoRewardType.coins ? l10n.promoAdminAmountHelpCoins : l10n.promoAdminAmountHelpPro,
          ),
          gap,
          _numberField(controller: _maxRedemptions, label: l10n.promoAdminMaxRedemptions),
          gap,
          _numberField(controller: _expiresInDays, label: l10n.promoAdminExpiresInDays),
          gap,
          _numberField(controller: _minAccountAge, label: l10n.promoAdminMinAccountAge),
          gap,
          PrismSwitchRow(
            title: l10n.promoAdminNewUsersOnly,
            value: _newUsersOnly,
            onChanged: (bool value) => setState(() => _newUsersOnly = value),
          ),
          if (_newUsersOnly) ...<Widget>[
            gap,
            _numberField(controller: _newUsersDays, label: l10n.promoAdminNewUsersDays),
          ],
          gap,
          PrismTextField(
            controller: _customCode,
            label: l10n.promoAdminCustomCode,
            helper: l10n.promoAdminCustomCodeHelp,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(32),
              TextInputFormatter.withFunction(
                (TextEditingValue _, TextEditingValue next) => next.copyWith(text: next.text.toUpperCase()),
              ),
            ],
          ),
          gap,
          PrismTextField(controller: _label, label: l10n.promoAdminLabel),
          gap,
          PrismButton(
            label: l10n.promoAdminCreate,
            expand: true,
            loading: _creating,
            onPressed: _canCreate ? _create : null,
          ),
        ],
      ),
    );
  }

  Widget _numberField({required TextEditingController controller, required String label, String? helper}) {
    return PrismTextField(
      controller: controller,
      label: label,
      helper: helper,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
      onChanged: (String _) => setState(() {}),
    );
  }

  Widget _buildCodes(AppLocalizations l10n) {
    final List<PromoCodeSummary>? codes = _codes;
    if (codes == null) {
      if (_loadFailed) {
        return GlintState(
          kind: GlintStateKind.error,
          title: l10n.promoAdminLoadFailed,
          actionLabel: l10n.adminTryAgain,
          actionVariant: PrismButtonVariant.tonal,
          onAction: _retry,
        );
      }
      // The skeleton scrolls inside its own list, so it needs a height from the page.
      return SizedBox(height: 360, child: PrismSkeleton.rows());
    }
    if (codes.isEmpty) {
      return GlintState(kind: GlintStateKind.empty, title: l10n.promoAdminEmpty);
    }
    return PrismGroup(children: <Widget>[for (final PromoCodeSummary code in codes) _codeRow(l10n, code)]);
  }

  PrismRow _codeRow(AppLocalizations l10n, PromoCodeSummary code) {
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final String reward = switch (code.reward) {
      CoinsReward(:final coins) => l10n.economyCoins(coins),
      PremiumDaysReward(:final days) => '$days ${l10n.promoAdminTypePro}',
    };
    final String details = <String>[
      reward,
      l10n.promoAdminRedemptions(code.redemptionCount, code.maxRedemptions),
      l10n.promoAdminExpires(DateFormat.yMMMd(locale).format(code.expiresAt)),
    ].join(' · ');
    final bool busy = _busyCodes.contains(code.code);
    return PrismRow(
      title: code.code,
      subtitle: code.label.isEmpty ? details : '$details\n${code.label}',
      trailingBelow: true,
      trailing: Wrap(
        spacing: PrismSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (code.disabled) PrismTag(label: l10n.promoAdminDisabled),
          PrismIconButton(icon: Icons.copy_rounded, tooltip: l10n.promoAdminCopy, onPressed: () => _copy(code)),
          PrismButton(
            label: code.disabled ? l10n.promoAdminEnable : l10n.promoAdminDisable,
            variant: PrismButtonVariant.ghost,
            size: PrismButtonSize.compact,
            loading: busy,
            onPressed: busy ? null : () => unawaited(_setDisabled(code, disabled: !code.disabled)),
          ),
        ],
      ),
    );
  }
}
