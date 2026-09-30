import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/ai_target_size.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
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
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_generate_bar.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_history_strip.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_pickers.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_preview_stage.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_prompt_field.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_actions.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_sheets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  const AiWallpaperTabPage({super.key, this.repository, this.submitForTesting});

  final AiGenerationRepositoryImpl? repository;
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

  /// The last prompt the app wrote itself. While the field still holds it, a new style may replace it.
  String _seededPrompt = '';
  int _sceneCursor = 0;

  bool _loadingHistory = false;
  bool _historyFailed = false;
  bool _loadingGeneration = false;
  bool _submitting = false;
  final Set<String> _unconfirmedSubmissionIds = <String>{};

  static const int _maxPromptChars = 4000;
  static const int _maxVariationChars = 2000;

  @override
  void initState() {
    super.initState();
    _setGeneratedPrompt(AiPromptPools.randomPrompt(_selectedStyle, _random));
    _loadHistory();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _variationController.dispose();
    _promptFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => app_state.prismUser.loggedIn && app_state.prismUser.id.trim().isNotEmpty;

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

  Future<void> _loadHistory() async {
    final String userId = app_state.prismUser.id;
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
      final bool online = await _hasNetworkOrUnknown();
      if (!online) {
        if (mounted) {
          setState(() => _historyFailed = true);
          toasts.error("You're offline. History will refresh when you're connected.");
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
        toasts.error(aiHistoryFailureMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  bool _canStartGeneration() {
    if (_loadingGeneration) return false;
    if (!_isLoggedIn) {
      toasts.error('Please sign in to generate wallpapers.');
      return false;
    }
    if (!_isRolloutEligible) {
      toasts.error('AI generation is currently rolling out. Please try again soon.');
      return false;
    }
    return true;
  }

  Future<bool> _isOnlineForGeneration() async {
    final bool online = await _hasNetworkOrUnknown();
    if (!online && mounted) {
      toasts.error('No connection. Connect to the internet, then try again.');
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
      toasts.error('Description is too long (max $_maxPromptChars characters).');
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
      request: (AiChargeMode mode, int coinsSpent) => _repository.generate(
        prompt: prompt,
        stylePreset: style,
        qualityTier: qualityTier,
        targetSize: targetSize,
        chargeMode: mode,
        coinsSpent: coinsSpent,
      ),
      successEvent: (AiGenerationRecord generated, AiChargeMode mode, int coinsSpent) =>
          AiGenerateSuccessEvent(provider: generated.provider, mode: mode, coinsSpent: coinsSpent),
      onSuccess: (AiGenerationRecord generated) {
        if (isAiAspectRatioMismatch(generated: generated, targetSize: targetSize)) {
          toasts.info('Crop may differ slightly on your device.');
        }
      },
    );
  }

  Future<void> _generateVariation() async {
    if (!_canStartGeneration()) return;

    final String prompt = _variationController.text.trim();
    if (prompt.isEmpty) {
      toasts.error('Say what you want different, such as colors, mood or details.');
      return;
    }
    if (prompt.length > _maxVariationChars) {
      toasts.error('That refinement is too long (max $_maxVariationChars characters).');
      return;
    }
    final AiGenerationRecord? latest = _latest;
    if (latest == null || !app_state.aiVariationsEnabled) {
      toasts.error('Refinements are not available right now.');
      return;
    }
    final AiStylePreset style = _selectedStyle;
    final AiQualityTier qualityTier = _selectedQualityTier;
    await _runGeneration(
      style: style,
      qualityTier: qualityTier,
      request: (AiChargeMode mode, int coinsSpent) => _repository.generateVariation(
        generationId: latest.id,
        chargeMode: mode,
        coinsSpent: coinsSpent,
        variationPrompt: prompt,
      ),
      successEvent: (AiGenerationRecord generated, AiChargeMode mode, int coinsSpent) =>
          AiVariationUsedEvent(provider: generated.provider, mode: mode, coinsSpent: coinsSpent),
      onSuccess: (_) => _variationController.clear(),
    );
  }

  Future<void> _runGeneration({
    required AiStylePreset style,
    required AiQualityTier qualityTier,
    required Future<AiGenerationRecord> Function(AiChargeMode mode, int coinsSpent) request,
    required AnalyticsEvent Function(AiGenerationRecord generated, AiChargeMode mode, int coinsSpent) successEvent,
    required void Function(AiGenerationRecord generated) onSuccess,
  }) async {
    if (!_canStartGeneration()) return;
    setState(() => _loadingGeneration = true);
    _scrollToTop();
    if (!await _isOnlineForGeneration() || !mounted) {
      if (mounted) setState(() => _loadingGeneration = false);
      return;
    }

    final reservation = await CoinsService.instance.reserveForAiGeneration(
      qualityTier: qualityTier,
      sourceTag: 'coins.reserve.ai_screen',
    );
    if (!mounted) {
      if (reservation.success) {
        await CoinsService.instance.rollbackAiGenerationReservation(
          reservation.mode,
          sourceTag: 'coins.rollback.ai_screen',
          reservationTransactionId: reservation.transactionId,
        );
      }
      return;
    }
    if (!reservation.success || reservation.mode == AiChargeMode.insufficient) {
      CoinsService.instance.logLowBalanceNudge(
        sourceTag: 'coins.ai_generation.low_balance',
        requiredCoins: qualityTier.coinCost,
      );
      toasts.error('Need ${qualityTier.coinCost} coins to generate.');
      setState(() => _loadingGeneration = false);
      return;
    }

    bool generationSucceeded = false;
    try {
      analytics.track(
        AiGenerateStartedEvent(style: style.apiValue, quality: qualityTier.apiValue, mode: reservation.mode),
      );
      final AiGenerationRecord generated = await request(reservation.mode, reservation.coinsSpent);
      generationSucceeded = true;

      CoinsService.instance.commitAiGenerationReservation(
        mode: reservation.mode,
        coinsSpent: reservation.coinsSpent,
        sourceTag: 'coins.commit.ai_screen',
      );

      if (mounted) {
        setState(() {
          _latest = generated;
          _history = <AiGenerationRecord>[generated, ..._history.where((item) => item.id != generated.id)];
        });
      }

      if (mounted && !context.reduceMotion) {
        HapticFeedback.lightImpact();
      }

      analytics.track(successEvent(generated, reservation.mode, reservation.coinsSpent));
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
      await CoinsService.instance.rollbackAiGenerationReservation(
        reservation.mode,
        sourceTag: 'coins.rollback.ai_screen',
        reservationTransactionId: reservation.transactionId,
      );
      analytics.track(AiGenerateFailedEvent(error: error.toString(), mode: reservation.mode));
      if (mounted) toasts.error(aiGenerateFailureMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loadingGeneration = false);
      }
    }
  }

  Future<void> _setWallpaper(AiGenerationRecord record) async {
    try {
      final File file = await aiDownloadToTempFile(record.displayUrl(isPremium: app_state.prismUser.premium));
      if (!mounted) return;
      context.router.push(DownloadWallpaperRoute(source: WallpaperSource.prism, file: file));
    } catch (error, stackTrace) {
      logger.w('AI set-wallpaper prep failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      toasts.error(aiDownloadFailureMessage(error));
    }
  }

  Future<void> _save(AiGenerationRecord record) async {
    final link = record.displayUrl(isPremium: app_state.prismUser.premium);
    try {
      final request = DownloadRequest(link: link, filenameWithoutExtension: downloadBaseName(link));
      final result = await PrismMediaHostApi().enqueueDownload(request);
      if (result.success) {
        toasts.success(wallpaperSavedMessage);
      } else {
        toasts.error(result.message ?? "Couldn't download! Please retry.");
      }
    } catch (error, stackTrace) {
      logger.w('AI gallery save failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      toasts.error(aiDownloadFailureMessage(error));
    }
  }

  Future<void> _submitToCommunity(AiGenerationRecord record) async {
    if (!canSubmitAiGeneration(record, currentUserId: app_state.prismUser.id) ||
        _confirmedSubmissionRecords.containsKey(record.id)) {
      return;
    }
    if (!_isLoggedIn) {
      toasts.error('Please sign in to submit wallpapers.');
      return;
    }
    if (!app_state.aiSubmitEnabled) {
      toasts.error('AI submit is currently disabled.');
      return;
    }
    if (_unconfirmedSubmissionIds.contains(record.id)) {
      toasts.error('Submission status is unconfirmed. Check Review Status before trying again.');
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
                aiOriginalImageUrl: record.imageUrl,
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
      if (mounted && !context.reduceMotion) {
        HapticFeedback.selectionClick();
      }
      if (mounted && app_state.prismUser.id == record.userId) {
        showGlintToast(context);
        toasts.success('Submitted for review.');
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
          toasts.error('Could not confirm the submission. Check Review Status before trying again.');
        }
      } else {
        logger.w('AI community submit failed before saving', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
        if (mounted && app_state.prismUser.id == record.userId) {
          toasts.error(isAiOfflineOrNetworkError(error) ? 'No connection. Try again.' : 'Submit failed. Please retry.');
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
      cost: _selectedQualityTier.coinCost,
      enabled: app_state.aiVariationsEnabled && _latest != null && !_loadingGeneration,
      onSubmit: _generateVariation,
    );
  }

  Widget _blockedState() {
    if (!app_state.aiEnabled) {
      return const GlintState(
        kind: GlintStateKind.empty,
        title: 'AI wallpaper is off for now',
        body: 'We turned it off for a short while. Check back soon.',
      );
    }
    if (!_isRolloutEligible) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: 'AI wallpaper is opening gradually',
        body: 'It is on for ${app_state.aiRolloutPercent}% of accounts so far. Try again soon.',
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
      onRefresh: _loadHistory,
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
                  onSet: () => _setWallpaper(current),
                  onSave: () => _save(current),
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
            const PrismSectionHeader(
              title: 'Style',
              small: true,
              padding: EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xl, PrismSpace.page, PrismSpace.sm),
            ),
            AiStylePicker(selected: _selectedStyle, enabled: !busy, onSelected: _selectStyle),
            const PrismSectionHeader(
              title: 'Quality',
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
            AiHistoryStrip(
              loading: _loadingHistory,
              failed: _historyFailed,
              history: _history,
              selectedId: current?.id,
              isPremium: app_state.prismUser.premium,
              onSelect: _selectFromHistory,
              onRetry: _loadHistory,
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
          cost: _selectedQualityTier.coinCost,
          balance: coinBalance,
          hasPrompt: _promptController.text.trim().isNotEmpty,
          loading: _loadingGeneration,
          prominent: current == null || _loadingGeneration,
          onGenerate: _generate,
          onGetCoins: () => context.router.push(RewardsRoute()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AiGenerationRecord? current = _latest;
    final bool available = _isRolloutEligible && _isLoggedIn;
    return PrismPage(
      title: 'AI wallpaper',
      showBack: Navigator.of(context).canPop(),
      actions: const <Widget>[CoinBalanceChip(sourceTag: 'ai_gen_page', showStreak: false)],
      bottomBar: available ? _generateBar(current) : null,
      body: available ? _composeBody(current) : _blockedState(),
    );
  }
}
