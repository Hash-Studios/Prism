import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/rating/rate_prompt_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/ai_target_size.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wallstore;
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart' show AiQualityTier;
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_prompt_pools.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_wallpaper_helpers.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_error_copy.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_generate_bar.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_history_strip.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_pickers.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_preview_stage.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_prompt_field.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_actions.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_sheets.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

bool canSubmitAiGeneration(AiGenerationRecord record, {required String currentUserId}) =>
    record.submittedWallId == null && record.userId == currentUserId;

List<AiGenerationRecord> mergeAiSubmissionHistory(
  List<AiGenerationRecord> fetched,
  Map<String, AiGenerationRecord> confirmed, {
  required String fetchedUserId,
}) {
  final Map<String, AiGenerationRecord> merged = <String, AiGenerationRecord>{
    for (final record in fetched) record.id: record,
  };
  for (final record in confirmed.values) {
    if (record.userId == fetchedUserId) {
      merged[record.id] = record;
    }
  }
  return merged.values.toList(growable: false);
}

@RoutePage(name: 'AiTabRoute')
class AiWallpaperTabPage extends StatefulWidget {
  const AiWallpaperTabPage({super.key, this.repository, this.submitForTesting, this.shareCard});

  final AiGenerationRepositoryImpl? repository;

  /// Builds and shares the branded image card. Tests replace it.
  final Future<ShareCardResult> Function(
    BuildContext context, {
    required String imageUrl,
    required String link,
    String? contextLine,
  })?
  shareCard;
  final Future<wallstore.WallSubmissionResult> Function()? submitForTesting;

  @override
  State<AiWallpaperTabPage> createState() => _AiWallpaperTabPageState();
}

class _AiWallpaperTabPageState extends State<AiWallpaperTabPage> {
  late final AiGenerationRepositoryImpl _repository = widget.repository ?? getIt<AiGenerationRepositoryImpl>();
  final Random _random = Random();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _variationController = TextEditingController();
  final FocusNode _promptFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  AiStylePreset _selectedStyle = AiStylePreset.abstract;
  AiQualityTier _selectedQualityTier = AiQualityTier.fast;
  List<AiGenerationRecord> _history = <AiGenerationRecord>[];
  AiGenerationRecord? _latest;
  final Map<String, AiGenerationRecord> _confirmedSubmissionRecords = <String, AiGenerationRecord>{};
  String _historyUserId = '';
  String _promptOwner = '';
  String _promptLoadingOwner = '';
  bool _promptHydrated = false;
  Timer? _promptSaveTimer;

  /// The last prompt the app wrote itself. While the field still holds it, a new style may replace it.
  String _seededPrompt = '';
  int _sceneCursor = 0;

  bool _loadingHistory = false;
  bool _historyFailed = false;
  bool _loadingGeneration = false;
  bool _saving = false;
  bool _sharing = false;
  bool _submitting = false;
  final Set<String> _unconfirmedSubmissionIds = <String>{};

  static const int _maxPromptChars = 160;
  static const int _maxVariationChars = 160;

  @override
  void initState() {
    super.initState();
    _setGeneratedPrompt(AiPromptPools.randomPrompt(_selectedStyle, _random));
    _loadHistory();
  }

  @override
  void dispose() {
    _promptSaveTimer?.cancel();
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    _variationController.dispose();
    _promptFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => app_state.prismUser.loggedIn && app_state.prismUser.id.trim().isNotEmpty;

  String get _localOwnerId => _isLoggedIn ? app_state.prismUser.id : 'guest';

  void _switchPromptOwner(String owner) {
    if (_promptOwner == owner && (_promptHydrated || _promptLoadingOwner == owner)) return;
    _promptSaveTimer?.cancel();
    _promptController.removeListener(_onPromptChanged);
    _promptOwner = owner;
    _promptLoadingOwner = owner;
    _promptHydrated = false;
    _setGeneratedPrompt(AiPromptPools.randomPrompt(_selectedStyle, _random));
    unawaited(_hydratePrompt(owner));
  }

  Future<void> _hydratePrompt(String owner) async {
    try {
      final String? prompt = await _repository.loadPrompt(userId: owner);
      if (!mounted || owner != _localOwnerId || owner != _promptOwner) return;
      final bool stillGenerated = _promptController.text.trim() == _seededPrompt.trim();
      if (prompt != null && stillGenerated) {
        _promptController.value = TextEditingValue(
          text: prompt,
          selection: TextSelection.collapsed(offset: prompt.length),
        );
      }
      _promptLoadingOwner = '';
      _promptHydrated = true;
      _promptController.addListener(_onPromptChanged);
      _savePromptNow(owner);
    } catch (error, stackTrace) {
      logger.w('Could not restore AI prompt', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      if (mounted && owner == _localOwnerId && owner == _promptOwner) {
        _promptLoadingOwner = '';
        _promptHydrated = true;
        _promptController.addListener(_onPromptChanged);
      }
    }
  }

  void _onPromptChanged() {
    if (!_promptHydrated || _promptOwner != _localOwnerId) return;
    _promptSaveTimer?.cancel();
    final String owner = _promptOwner;
    _promptSaveTimer = Timer(const Duration(milliseconds: 300), () => _savePromptNow(owner));
  }

  void _savePromptNow(String owner) {
    if (owner != _localOwnerId || owner != _promptOwner) return;
    unawaited(
      _repository.savePrompt(userId: owner, prompt: _promptController.text).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        logger.w('Could not save AI prompt', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      }),
    );
  }

  bool get _isRolloutEligible {
    if (!app_state.aiEnabled) {
      return false;
    }
    final int percent = app_state.aiRolloutPercent.clamp(0, 100);
    if (percent >= 100) {
      return true;
    }
    if (!_isLoggedIn) {
      return false;
    }
    final int hash = app_state.prismUser.id.codeUnits.fold<int>(0, (prev, unit) => (prev + unit) % 100);
    return hash < percent;
  }

  void _setGeneratedPrompt(String prompt) {
    _seededPrompt = prompt;
    _promptController.text = prompt;
    _promptController.selection = TextSelection.fromPosition(TextPosition(offset: prompt.length));
  }

  void _shufflePrompt() {
    setState(() => _setGeneratedPrompt(AiPromptPools.randomPrompt(_selectedStyle, _random)));
    analytics.track(AiPromptShuffledEvent(style: _selectedStyle.apiValue));
  }

  void _useSceneIdea() {
    setState(() => _setGeneratedPrompt(AiPromptPools.sceneIdea(_selectedStyle, _sceneCursor++)));
  }

  void _selectStyle(AiStylePreset style) {
    setState(() => _selectedStyle = style);
    final String typed = _promptController.text.trim();
    if (typed.isEmpty || typed == _seededPrompt.trim()) _shufflePrompt();
  }

  void _scrollToTop() {
    if (!_scroll.hasClients || _scroll.offset <= 0) return;
    _scroll.animateTo(0, duration: context.motion(PrismDurations.base), curve: PrismCurves.enter);
  }

  void _selectFromHistory(AiGenerationRecord record) {
    PrismHaptics.selection();
    setState(() => _latest = record);
    _scrollToTop();
  }

  Future<bool> _hasNetworkOrUnknown() async {
    try {
      return await getIt<ConnectivityService>().hasConnection();
    } catch (error, stackTrace) {
      logger.w('Connectivity check failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      return true;
    }
  }

  Future<void> _loadHistory({bool userInitiated = false}) async {
    final String userId = app_state.prismUser.id;
    _switchPromptOwner(_localOwnerId);
    if (_historyUserId != userId) {
      _historyUserId = userId;
      _history = <AiGenerationRecord>[];
      _latest = null;
      _confirmedSubmissionRecords.clear();
      _unconfirmedSubmissionIds.clear();
    }
    if (!_isLoggedIn) {
      setState(() {
        _history = <AiGenerationRecord>[];
        _latest = null;
        _confirmedSubmissionRecords.clear();
        _unconfirmedSubmissionIds.clear();
      });
      return;
    }
    setState(() {
      _loadingHistory = true;
      _historyFailed = false;
    });
    try {
      final List<AiGenerationRecord> local = await _repository.fetchLocalHistory(userId: userId);
      if (!mounted || app_state.prismUser.id != userId) return;
      if (local.isNotEmpty) {
        final List<AiGenerationRecord> localWithConfirmed = mergeAiSubmissionHistory(
          local,
          _confirmedSubmissionRecords,
          fetchedUserId: userId,
        );
        setState(() {
          _history = localWithConfirmed;
          _latest = localWithConfirmed.first;
        });
      }
      final bool online = await _hasNetworkOrUnknown();
      if (!online) {
        if (mounted) {
          setState(() => _historyFailed = local.isEmpty);
          if (userInitiated) toasts.error(context.l10n.economyAiOfflineSavedHistory);
        }
        return;
      }
      final result = await _repository.fetchHistory(userId: userId);
      if (!mounted || app_state.prismUser.id != userId) return;
      final mergedResult = mergeAiSubmissionHistory(result, _confirmedSubmissionRecords, fetchedUserId: userId);
      setState(() {
        _history = mergedResult;
        _latest = mergedResult.isEmpty ? null : mergedResult.first;
      });
      analytics.track(AiHistoryOpenedEvent(count: result.length));
    } catch (error, stackTrace) {
      logger.w('AI history fetch failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _historyFailed = true);
        toasts.error(aiHistoryFailureMessage(context.l10n, error), haptic: userInitiated);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  void _promptSignIn() {
    googleSignInPopUp(context, () {
      if (mounted) _loadHistory();
    });
  }

  bool _canStartGeneration() {
    if (_loadingGeneration) return false;
    if (!_isLoggedIn) {
      _promptSignIn();
      return false;
    }
    if (!_isRolloutEligible) {
      toasts.error(context.l10n.economyAiGenerationRollingOut);
      return false;
    }
    return true;
  }

  Future<bool> _isOnlineForGeneration() async {
    final bool online = await _hasNetworkOrUnknown();
    if (!online && mounted) {
      toasts.error(context.l10n.economyAiConnectToGenerate);
    }
    return online;
  }

  Future<void> _generate() async {
    if (!_canStartGeneration()) return;

    final String prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _promptFocus.requestFocus();
      return;
    }
    if (prompt.length > _maxPromptChars) {
      toasts.error(context.l10n.economyAiPromptTooLong(_maxPromptChars));
      return;
    }
    final AiStylePreset style = _selectedStyle;
    final AiQualityTier qualityTier = _selectedQualityTier;
    final String targetSize = aiTargetSize(
      size: MediaQuery.sizeOf(context),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    await _runGeneration(
      style: style,
      qualityTier: qualityTier,
      request: (AiChargeMode mode, int coinsSpent, String? chargeTxId) => _repository.generate(
        prompt: prompt,
        stylePreset: style,
        qualityTier: qualityTier,
        targetSize: targetSize,
        chargeMode: mode,
        coinsSpent: coinsSpent,
        chargeTxId: chargeTxId,
      ),
      successEvent: (AiGenerationRecord generated, AiChargeMode mode, int coinsSpent) =>
          AiGenerateSuccessEvent(provider: generated.provider, mode: mode, coinsSpent: coinsSpent),
      onSuccess: (AiGenerationRecord generated) {
        if (isAiAspectRatioMismatch(generated: generated, targetSize: targetSize)) {
          toasts.info(context.l10n.economyAiCropMayDiffer);
        }
      },
    );
  }

  Future<void> _generateVariation() async {
    if (!_canStartGeneration()) return;

    final String prompt = _variationController.text.trim();
    if (prompt.isEmpty) {
      toasts.error(context.l10n.economyAiDescribeChanges);
      return;
    }
    if (prompt.length > _maxVariationChars) {
      toasts.error(context.l10n.economyAiVariationTooLong(_maxVariationChars));
      return;
    }
    final AiGenerationRecord? latest = _latest;
    if (latest == null || !app_state.aiVariationsEnabled) {
      toasts.error(context.l10n.economyAiVariationUnavailable);
      return;
    }
    final AiStylePreset style = _selectedStyle;
    final AiQualityTier qualityTier = latest.qualityTier;
    await _runGeneration(
      style: style,
      qualityTier: qualityTier,
      request: (AiChargeMode mode, int coinsSpent, String? chargeTxId) => _repository.generateVariation(
        generationId: latest.id,
        chargeMode: mode,
        coinsSpent: coinsSpent,
        variationPrompt: prompt,
        chargeTxId: chargeTxId,
      ),
      successEvent: (AiGenerationRecord generated, AiChargeMode mode, int coinsSpent) =>
          AiVariationUsedEvent(provider: generated.provider, mode: mode, coinsSpent: coinsSpent),
      onSuccess: (_) => _variationController.clear(),
    );
  }

  Future<void> _runGeneration({
    required AiStylePreset style,
    required AiQualityTier qualityTier,
    required Future<AiGenerationRecord> Function(AiChargeMode mode, int coinsSpent, String? chargeTxId) request,
    required AnalyticsEvent Function(AiGenerationRecord generated, AiChargeMode mode, int coinsSpent) successEvent,
    required void Function(AiGenerationRecord generated) onSuccess,
  }) async {
    if (!_canStartGeneration()) return;
    final String operationId = AnalyticsCorrelation.newId();
    final Stopwatch elapsed = Stopwatch()..start();
    setState(() => _loadingGeneration = true);
    _scrollToTop();
    final bool online = await _isOnlineForGeneration();
    if (!online || !mounted) {
      analytics.track(
        AiGenerateFailedEvent(
          error: online ? 'cancelled' : 'offline',
          errorCategory: online ? 'cancelled' : 'offline',
          refundResult: 'not_required',
          mode: AiChargeMode.insufficient,
          operationId: operationId,
          durationMs: elapsed.elapsedMilliseconds,
        ),
      );
      if (mounted) setState(() => _loadingGeneration = false);
      return;
    }

    final reservation = await CoinsService.instance.reserveForAiGeneration(
      qualityTier: qualityTier,
      operationId: operationId,
      sourceTag: 'coins.reserve.ai_screen',
    );
    if (!mounted) {
      if (reservation.success) {
        await CoinsService.instance.rollbackAiGenerationReservation(
          reservation.mode,
          sourceTag: 'coins.rollback.ai_screen',
          reservationTransactionId: reservation.transactionId,
          operationId: operationId,
        );
      }
      return;
    }
    if (reservation.refundPending) {
      analytics.track(
        AiGenerateFailedEvent(
          error: 'charge_unconfirmed',
          errorCategory: 'charge_unconfirmed',
          mode: reservation.mode,
          operationId: operationId,
          durationMs: elapsed.elapsedMilliseconds,
          chargeTransactionId: reservation.transactionId,
          refundResult: 'pending',
        ),
      );
      toasts.error(context.l10n.economyAiChargeUnconfirmed);
      setState(() => _loadingGeneration = false);
      return;
    }
    if (!reservation.success || reservation.mode == AiChargeMode.insufficient) {
      final String category = reservation.mutation.success ? 'insufficient_balance' : 'charge_failed';
      analytics.track(
        AiGenerateFailedEvent(
          error: category,
          errorCategory: category,
          mode: reservation.mode,
          refundResult: 'not_required',
          operationId: operationId,
          durationMs: elapsed.elapsedMilliseconds,
        ),
      );
      CoinsService.instance.logLowBalanceNudge(
        sourceTag: 'coins.ai_generation.low_balance',
        requiredCoins: qualityTier.costFor(isPro: app_state.prismUser.premium),
      );
      toasts.error(context.l10n.economyAiNeedCoinsToGenerate(qualityTier.costFor(isPro: app_state.prismUser.premium)));
      setState(() => _loadingGeneration = false);
      return;
    }

    bool generationSucceeded = false;
    try {
      analytics.track(
        AiGenerateStartedEvent(
          style: style.apiValue,
          quality: qualityTier.apiValue,
          mode: reservation.mode,
          operationId: operationId,
          chargeTransactionId: reservation.transactionId,
        ),
      );
      final AiGenerationRecord generated = await request(
        reservation.mode,
        reservation.coinsSpent,
        reservation.transactionId,
      );
      generationSucceeded = true;

      CoinsService.instance.commitAiGenerationReservation(
        mode: reservation.mode,
        coinsSpent: reservation.coinsSpent,
        operationId: operationId,
        chargeTransactionId: reservation.transactionId,
        sourceTag: 'coins.commit.ai_screen',
      );

      if (mounted) {
        setState(() {
          _latest = generated;
          _history = <AiGenerationRecord>[generated, ..._history.where((item) => item.id != generated.id)];
        });
      }

      if (mounted && !context.reduceMotion) {
        PrismHaptics.success();
      }

      final AnalyticsEvent event = successEvent(generated, reservation.mode, reservation.coinsSpent);
      analytics.track(
        event is AiVariationUsedEvent
            ? AiVariationUsedEvent(
                provider: generated.provider,
                mode: reservation.mode,
                coinsSpent: reservation.coinsSpent,
                operationId: operationId,
                durationMs: elapsed.elapsedMilliseconds,
                chargeTransactionId: reservation.transactionId,
                generationId: generated.id,
              )
            : AiGenerateSuccessEvent(
                provider: generated.provider,
                mode: reservation.mode,
                coinsSpent: reservation.coinsSpent,
                operationId: operationId,
                durationMs: elapsed.elapsedMilliseconds,
                chargeTransactionId: reservation.transactionId,
                generationId: generated.id,
              ),
      );
      if (mounted) {
        onSuccess(generated);
        showGlintToast(context);
      }
    } catch (error, stackTrace) {
      if (generationSucceeded) {
        logger.w(
          'AI generation succeeded but follow-up work failed',
          tag: 'ai_wallpaper',
          error: error,
          stackTrace: stackTrace,
        );
        return;
      }
      logger.w('AI generation failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      final CoinMutationResult refund = await CoinsService.instance.rollbackAiGenerationReservation(
        reservation.mode,
        sourceTag: 'coins.rollback.ai_screen',
        reservationTransactionId: reservation.transactionId,
        operationId: operationId,
      );
      final String category = isAiOfflineOrNetworkError(error) ? 'network' : 'generation_failed';
      final String refundOutcome = CoinsService.aiRefundOutcome(refund, charged: reservation.coinsSpent > 0);
      analytics.track(
        AiGenerateFailedEvent(
          error: category,
          errorCategory: category,
          mode: reservation.mode,
          operationId: operationId,
          durationMs: elapsed.elapsedMilliseconds,
          chargeTransactionId: reservation.transactionId,
          refundResult: refundOutcome,
        ),
      );
      if (mounted) {
        final String message = aiGenerateFailureMessage(context.l10n, error);
        final String localizedRefundState = switch (refundOutcome) {
          'refunded' || 'already_refunded' => 'refunded',
          'pending' => 'pending',
          _ => 'failed',
        };
        final String fullMessage = reservation.coinsSpent <= 0 || aiGenerationErrorMentionsRefund(error)
            ? message
            : context.l10n.economyAiFailureWithRefund(message, localizedRefundState);
        toasts.error(fullMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingGeneration = false);
      }
    }
  }

  Future<void> _setWallpaper(AiGenerationRecord record) async {
    final AppLocalizations l10n = context.l10n;
    try {
      final File file = await aiDownloadToTempFile(record.displayUrl(isPremium: app_state.prismUser.premium));
      if (!mounted) return;
      context.router.push(DownloadWallpaperRoute(source: WallpaperSource.prism, file: file));
    } catch (error, stackTrace) {
      logger.w('AI set-wallpaper prep failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      toasts.error(aiDownloadFailureMessage(l10n, error));
    }
  }

  Future<void> _save(AiGenerationRecord record) async {
    if (_saving) return;
    final AppLocalizations l10n = context.l10n;
    _saving = true;
    final link = record.displayUrl(isPremium: app_state.prismUser.premium);
    try {
      final File localFile = await OfflineAssetStore.instance.resolve(link).timeout(aiAssetTransferTimeout);
      final request = DownloadRequest(
        link: localFile.path,
        filenameWithoutExtension: downloadBaseName(link),
        isLocalFile: true,
      );
      final result = await PrismMediaHostApi().enqueueDownload(request);
      if (result.success) {
        unawaited(() async {
          try {
            await OfflineAssetStore.instance.retain(link, file: localFile).timeout(aiAssetTransferTimeout);
          } catch (error, stackTrace) {
            logger.w('AI gallery original retention failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
          }
        }());
        toasts.success(wallpaperSavedMessage(l10n));
        if (mounted) await showIosSetWallpaperGuide(context);
        unawaited(RatePromptService.instance.maybePrompt(RatePromptTrigger.aiWallpaperSaved));
      } else if (isPhotosPermissionDenied(result.errorCode)) {
        if (mounted) showPhotosPermissionDenied(context);
      } else {
        toasts.error(l10n.economyAiDownloadFailed);
      }
    } catch (error, stackTrace) {
      logger.w('AI gallery save failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      toasts.error(aiDownloadFailureMessage(l10n, error));
    } finally {
      _saving = false;
    }
  }

  Future<void> _share(AiGenerationRecord record) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    _trackShareEvent(const InviteShareTappedEvent(sourceContext: 'ai_wallpaper'));
    try {
      final ShareCardResult shared = await (widget.shareCard ?? shareWallpaperCard)(
        context,
        imageUrl: record.displayUrl(isPremium: app_state.prismUser.premium),
        link: 'https://prismwalls.com',
        contextLine: 'Made with Prism AI',
      );
      if (!mounted) return;
      _trackShareEvent(
        InviteShareResultEvent(
          channel: ShareChannelValue.shareSheet,
          result: shared.dismissed ? EventResultValue.cancelled : EventResultValue.success,
          reason: shared.dismissed ? AnalyticsReasonValue.userCancelled : null,
          sourceContext: 'ai_wallpaper',
          format: shared.format,
        ),
      );
    } catch (error, stackTrace) {
      logger.w('AI share failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      _trackShareEvent(
        const InviteShareResultEvent(
          channel: ShareChannelValue.shareSheet,
          result: EventResultValue.failure,
          reason: AnalyticsReasonValue.error,
          sourceContext: 'ai_wallpaper',
        ),
      );
      if (mounted) toasts.error(context.l10n.economyAiShareFailed);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _trackShareEvent(AnalyticsEvent event) {
    try {
      unawaited(
        analytics.track(event).catchError((Object error, StackTrace stackTrace) {
          logger.w('AI share analytics failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
        }),
      );
    } catch (error, stackTrace) {
      logger.w('AI share analytics failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _submitToCommunity(AiGenerationRecord record) async {
    if (!canSubmitAiGeneration(record, currentUserId: app_state.prismUser.id) ||
        _confirmedSubmissionRecords.containsKey(record.id)) {
      return;
    }
    if (!_isLoggedIn) {
      _promptSignIn();
      return;
    }
    if (!app_state.aiSubmitEnabled) {
      toasts.error(context.l10n.economyAiSubmitDisabled);
      return;
    }
    if (_unconfirmedSubmissionIds.contains(record.id)) {
      toasts.error(context.l10n.economyAiSubmitStatusUnconfirmed);
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    bool submissionStarted = false;
    bool submissionConfirmed = false;
    try {
      analytics.track(AiSubmitStartedEvent(generationId: record.id));
      final AiSubmissionMetadata metadata = await _repository.prefillSubmissionMetadata(
        generationId: record.id,
        defaultTags: <String>[_selectedStyle.apiValue],
      );
      if (!mounted || app_state.prismUser.id != record.userId) return;
      final AiSubmissionMetadata? edited = await showAiSubmitSheet(
        context,
        record: _latest,
        isPremium: app_state.prismUser.premium,
        metadata: metadata,
        prompt: _promptController.text.trim(),
        style: _selectedStyle,
      );
      if (!mounted || app_state.prismUser.id != record.userId) return;
      if (edited == null) {
        return;
      }

      final String communityId = aiCommunityId(record.id);
      submissionStarted = true;
      final wallstore.WallSubmissionResult submissionResult =
          await (widget.submitForTesting?.call() ??
              wallstore.createRecord(
                communityId,
                'Prism',
                record.watermarkedImageUrl,
                record.watermarkedImageUrl,
                '${record.width}x${record.height}',
                'AI',
                edited.title,
                edited.category,
                edited.description,
                false,
                wallpaperTags: edited.tags,
                isAiGenerated: true,
                aiGenerationId: record.id,
                aiProvider: record.provider,
                aiModel: record.model,
                aiPrompt: record.prompt,
                aiStylePreset: record.stylePreset.apiValue,
              ));
      if (submissionResult == wallstore.WallSubmissionResult.quotaExceeded) {
        return;
      }
      submissionConfirmed = true;
      if (app_state.prismUser.id != record.userId) return;
      final updated = record.copyWith(
        submittedWallId: communityId,
        submittedAt: DateTime.now().toUtc(),
        status: 'submitted',
      );
      _confirmedSubmissionRecords[updated.id] = updated;
      if (mounted) {
        setState(() {
          _history = _history.map((item) => item.id == updated.id ? updated : item).toList();
          if (_latest?.id == updated.id) {
            _latest = updated;
          }
        });
      }
      try {
        await _repository.saveHistoryRecord(updated);
      } catch (error, stackTrace) {
        logger.w(
          'AI wallpaper submitted but local history could not be saved',
          tag: 'ai_wallpaper',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (mounted && app_state.prismUser.id == record.userId) {
        showGlintToast(context);
        toasts.success(context.l10n.economyAiSubmittedForReview);
      }
    } catch (error, stackTrace) {
      if (submissionConfirmed) {
        logger.w(
          'AI wallpaper submission succeeded but follow-up work failed',
          tag: 'ai_wallpaper',
          error: error,
          stackTrace: stackTrace,
        );
      } else if (submissionStarted) {
        if (mounted && app_state.prismUser.id == record.userId) {
          setState(() => _unconfirmedSubmissionIds.add(record.id));
        }
        logger.w(
          'AI wallpaper submission status is unconfirmed',
          tag: 'ai_wallpaper',
          error: error,
          stackTrace: stackTrace,
        );
        if (mounted && app_state.prismUser.id == record.userId) {
          toasts.error(context.l10n.economyAiCouldNotConfirmSubmission);
        }
      } else {
        logger.w('AI community submit failed before saving', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
        if (mounted && app_state.prismUser.id == record.userId) {
          toasts.error(
            isAiOfflineOrNetworkError(error)
                ? context.l10n.economyAiNoConnectionRetry
                : context.l10n.economyAiSubmitFailed,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
      if (submissionConfirmed) {
        try {
          await analytics.track(AiSubmitSuccessEvent(generationId: record.id));
        } catch (error, stackTrace) {
          logger.w(
            'AI wallpaper submission succeeded but follow-up work failed',
            tag: 'ai_wallpaper',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }
  }

  void _openRefineSheet() {
    showAiRefineSheet(
      context,
      controller: _variationController,
      maxChars: _maxVariationChars,
      cost: (_latest?.qualityTier ?? _selectedQualityTier).costFor(isPro: app_state.prismUser.premium),
      enabled: app_state.aiVariationsEnabled && _latest != null && !_loadingGeneration,
      onSubmit: _generateVariation,
    );
  }

  Widget _blockedState() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!app_state.aiEnabled) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: l10n.economyAiUnavailableTitle,
        body: l10n.economyAiUnavailableBody,
      );
    }
    if (!_isRolloutEligible) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: l10n.economyAiRolloutTitle,
        body: l10n.economyAiRolloutBody(app_state.aiRolloutPercent),
      );
    }
    return const SignInPrompt(feature: 'AI wallpaper');
  }

  Widget _composeBody(AiGenerationRecord? current) {
    final bool busy = _loadingGeneration;
    final bool canSubmit =
        current != null &&
        canSubmitAiGeneration(current, currentUserId: app_state.prismUser.id) &&
        !_confirmedSubmissionRecords.containsKey(current.id) &&
        app_state.aiSubmitEnabled &&
        !_submitting &&
        !_unconfirmedSubmissionIds.contains(current.id);
    const EdgeInsets page = PrismSpace.pageInsets;
    return RefreshIndicator(
      onRefresh: () {
        PrismHaptics.impact();
        return _loadHistory(userInitiated: true);
      },
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: page.copyWith(top: PrismSpace.xs),
              child: AiPreviewStage(generating: busy, record: current, isPremium: app_state.prismUser.premium),
            ),
            if (current != null && !busy) ...<Widget>[
              Padding(
                padding: page.copyWith(top: PrismSpace.md),
                child: AiResultActions(
                  showSet: !hideSetWallpaperUi,
                  showRefine: app_state.aiVariationsEnabled,
                  canSubmit: canSubmit,
                  sharing: _sharing,
                  onSet: () => _setWallpaper(current),
                  onSave: () => _save(current),
                  onShare: () => _share(current),
                  onRefine: _openRefineSheet,
                  onSubmit: () => _submitToCommunity(current),
                ),
              ),
              if (_unconfirmedSubmissionIds.contains(current.id))
                Padding(
                  padding: page.copyWith(top: PrismSpace.sm),
                  child: AiUnconfirmedNotice(onCheck: () => context.router.push(const ReviewRoute())),
                ),
            ],
            Padding(
              padding: page.copyWith(top: current == null && !busy ? PrismSpace.xs : PrismSpace.xl),
              child: AiPromptField(
                controller: _promptController,
                focusNode: _promptFocus,
                maxChars: _maxPromptChars,
                enabled: !busy,
                onShuffle: _shufflePrompt,
                onSceneIdea: _useSceneIdea,
              ),
            ),
            PrismSectionHeader(
              title: AppLocalizations.of(context).economyAiStyle,
              small: true,
              padding: EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xl, PrismSpace.page, PrismSpace.sm),
            ),
            AiStylePicker(selected: _selectedStyle, enabled: !busy, onSelected: _selectStyle),
            PrismSectionHeader(
              title: AppLocalizations.of(context).economyAiQuality,
              small: true,
              padding: EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xl, PrismSpace.page, PrismSpace.sm),
            ),
            Padding(
              padding: page,
              child: AiQualityPicker(
                selected: _selectedQualityTier,
                enabled: !busy,
                onSelected: (AiQualityTier tier) => setState(() => _selectedQualityTier = tier),
              ),
            ),
            if (!app_state.prismUser.premium)
              Padding(
                padding: page.copyWith(top: PrismSpace.sm),
                child: Text(
                  AppLocalizations.of(context).economyAiWatermarkNote,
                  style: PrismTextStyles.caption(context),
                ),
              ),
            AiHistoryStrip(
              loading: _loadingHistory,
              failed: _historyFailed,
              history: _history,
              selectedId: current?.id,
              isPremium: app_state.prismUser.premium,
              onSelect: _selectFromHistory,
              onRetry: () => _loadHistory(userInitiated: true),
            ),
            const SizedBox(height: PrismSpace.xxl),
          ],
        ),
      ),
    );
  }

  Widget _generateBar(AiGenerationRecord? current) {
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (BuildContext context, int coinBalance, _) => ListenableBuilder(
        listenable: _promptController,
        builder: (BuildContext context, _) => AiGenerateBar(
          cost: _selectedQualityTier.costFor(isPro: app_state.prismUser.premium),
          balance: coinBalance,
          hasPrompt: _promptController.text.trim().isNotEmpty,
          loading: _loadingGeneration,
          prominent: current == null || _loadingGeneration,
          onGenerate: _generate,
          onGetCoins: () => context.router.push(RewardsRoute(scrollToEarn: true)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AiGenerationRecord? current = _latest;
    final bool available = _isRolloutEligible && _isLoggedIn;
    return PrismPage(
      title: AppLocalizations.of(context).economyAiWallpaper,
      showBack: Navigator.of(context).canPop(),
      actions: const <Widget>[CoinBalanceChip(sourceTag: 'ai_gen_page', showStreak: false)],
      bottomBar: available ? _generateBar(current) : null,
      body: available ? _composeBody(current) : _blockedState(),
    );
  }
}
