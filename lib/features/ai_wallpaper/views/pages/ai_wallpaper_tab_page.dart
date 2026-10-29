import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/rating/rate_prompt_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/ai_target_size.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wallstore;
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/ai_rollout.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_follow_up.dart';
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
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_remix_chip.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_actions.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_view.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_sheets.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_style_sheet.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
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
  const AiWallpaperTabPage({super.key, this.repository, this.submitForTesting, this.shareSheet, this.remixSeed});

  final AiGenerationRepositoryImpl? repository;

  /// The wall the user tapped Remix on. Its prompt and style fill the form, and a generation links back to it.
  final AiRemixSeed? remixSeed;

  /// Opens the share sheet. Tests replace it.
  final ShareSheetOpen? shareSheet;
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
  AiRemixSeed? _remixLink;
  List<AiGenerationRecord> _history = <AiGenerationRecord>[];

  /// The wallpaper shown full-bleed. Null shows the prompt editor.
  AiGenerationRecord? _hero;
  AiApplyFromValue _heroFrom = AiApplyFromValue.hero;

  /// The wallpapers made since the page opened, oldest first.
  List<AiGenerationRecord> _session = <AiGenerationRecord>[];
  final Map<String, int> _uploadAwards = <String, int>{};
  final Map<String, AiGenerationRecord> _confirmedSubmissionRecords = <String, AiGenerationRecord>{};
  String _historyUserId = '';
  String _promptOwner = '';
  String _promptLoadingOwner = '';
  bool _promptHydrated = false;
  bool _promptRestored = false;
  bool _promptHasUserIntent = false;
  bool _settingPromptProgrammatically = false;
  String _observedPromptText = '';
  Timer? _promptSaveTimer;
  StreamSubscription<PrismUsersV2>? _sessionSubscription;
  bool _ownerSyncScheduled = false;

  /// The last prompt the app wrote itself. While the field still holds it, a new style may replace it.
  String _seededPrompt = '';
  int _sceneCursor = 0;
  AppLocalizations? _promptMessages;

  bool _loadingHistory = false;
  int _historyLoadGeneration = 0;
  bool _historyFailed = false;
  bool _loadingGeneration = false;
  bool _saving = false;
  bool _sharing = false;
  bool _submitting = false;
  bool _applying = false;
  bool _confirmingFollowUp = false;
  final Set<String> _unconfirmedSubmissionIds = <String>{};

  static const int _maxPromptChars = 160;
  static const int _maxVariationChars = 160;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
    if (getIt.isRegistered<SessionRepository>()) {
      _sessionSubscription = getIt<SessionRepository>().watchCurrentUser().listen((_) => _syncOwnerAndReload());
    }
    _loadHistory();
    final AiRemixSeed? remixSeed = widget.remixSeed;
    if (remixSeed != null) _applyRemixSeed(remixSeed);
  }

  /// Fills the form from [seed]. Runs after [_loadHistory], which resets the prompt owner, so the remix prompt wins.
  void _applyRemixSeed(AiRemixSeed seed) {
    _remixLink = seed;
    final String prompt = seed.prompt.length <= _maxPromptChars ? seed.prompt : _clipPrompt(seed.prompt);
    _setPrompt(prompt, userInitiated: true, updateSeed: false);
    if (seed.style != null) _selectedStyle = seed.style!;
    _selectedQualityTier = remixTier(
      model: seed.model,
      balance: CoinsService.instance.balanceNotifier.value,
      isPro: app_state.prismUser.premium,
    );
  }

  String _clipPrompt(String prompt) {
    final int space = prompt.lastIndexOf(' ', _maxPromptChars);
    final String cut = prompt.substring(0, space > 0 ? space : _maxPromptChars);
    return cut.trim();
  }

  void _dropRemixLink() {
    final AiRemixSeed? link = _remixLink;
    if (link == null) return;
    analytics.track(RemixLinkDroppedEvent(sourceWallType: link.sourceType));
    setState(() => _remixLink = null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppLocalizations messages = context.l10n;
    final bool localeChanged = _promptMessages?.localeName != messages.localeName;
    _promptMessages = messages;
    if (localeChanged &&
        !_promptRestored &&
        !_promptHasUserIntent &&
        (_promptController.text.trim().isEmpty || _promptController.text.trim() == _seededPrompt.trim())) {
      _setPrompt(AiPromptPools.randomPrompt(messages, _selectedStyle, _random));
    }
  }

  @override
  void dispose() {
    _promptSaveTimer?.cancel();
    unawaited(_sessionSubscription?.cancel());
    _promptController.dispose();
    _variationController.dispose();
    _promptFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => app_state.prismUser.loggedIn && app_state.prismUser.id.trim().isNotEmpty;

  String get _localOwnerId => _isLoggedIn ? app_state.prismUser.id : 'guest';

  void _syncOwnerAndReload() {
    if (!mounted || _promptOwner == _localOwnerId) return;
    unawaited(_loadHistory());
  }

  void _scheduleOwnerSync() {
    if (_ownerSyncScheduled) return;
    _ownerSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ownerSyncScheduled = false;
      _syncOwnerAndReload();
    });
  }

  void _switchPromptOwner(String owner) {
    if (_promptOwner == owner && (_promptHydrated || _promptLoadingOwner == owner)) return;
    final String promptBeforeSwitch = _promptController.text;
    final bool fromGuest = _promptOwner.isEmpty || _promptOwner == 'guest';
    _promptSaveTimer?.cancel();
    _promptOwner = owner;
    _promptLoadingOwner = owner;
    _promptHydrated = false;
    _promptRestored = false;
    _promptHasUserIntent = false;
    final AppLocalizations? messages = _promptMessages;
    if (messages != null) _setPrompt(AiPromptPools.randomPrompt(messages, _selectedStyle, _random));
    _variationController.clear();
    if (_remixLink != null && fromGuest) {
      _setPrompt(promptBeforeSwitch, userInitiated: true, updateSeed: false);
    } else {
      _remixLink = null;
    }
    unawaited(_hydratePrompt(owner));
  }

  Future<void> _hydratePrompt(String owner) async {
    try {
      final String? prompt = await _repository.loadPrompt(userId: owner);
      if (!mounted || owner != _localOwnerId || owner != _promptOwner) return;
      if (prompt != null && !_promptHasUserIntent) {
        _promptRestored = true;
        _setPrompt(prompt, updateSeed: false);
      }
      _promptLoadingOwner = '';
      _promptHydrated = true;
      if (_promptHasUserIntent) _schedulePromptSave(owner);
    } catch (error, stackTrace) {
      logger.w('Could not restore AI prompt', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      if (mounted && owner == _localOwnerId && owner == _promptOwner) {
        _promptLoadingOwner = '';
        _promptHydrated = true;
        if (_promptHasUserIntent) _schedulePromptSave(owner);
      }
    }
  }

  void _onPromptChanged() {
    if (_settingPromptProgrammatically) return;
    final String text = _promptController.text;
    if (text == _observedPromptText) return;
    _observedPromptText = text;
    _promptHasUserIntent = true;
    if (!_promptHydrated || _promptOwner != _localOwnerId) return;
    _schedulePromptSave(_promptOwner);
  }

  void _schedulePromptSave(String owner) {
    _promptSaveTimer?.cancel();
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

  bool get _isRolloutEligible => aiRolloutEligible(
    aiEnabled: app_state.aiEnabled,
    rolloutPercent: app_state.aiRolloutPercent,
    loggedIn: _isLoggedIn,
    userId: app_state.prismUser.id,
  );

  void _setPrompt(String prompt, {bool userInitiated = false, bool updateSeed = true}) {
    if (updateSeed) _seededPrompt = prompt;
    if (userInitiated) {
      _promptHasUserIntent = true;
    }
    _settingPromptProgrammatically = true;
    try {
      _promptController.value = TextEditingValue(
        text: prompt,
        selection: TextSelection.collapsed(offset: prompt.length),
      );
      _observedPromptText = prompt;
    } finally {
      _settingPromptProgrammatically = false;
    }
    if (userInitiated && _promptHydrated) _schedulePromptSave(_promptOwner);
  }

  void _shufflePrompt() {
    final AppLocalizations? messages = _promptMessages;
    if (messages == null) return;
    setState(() => _setPrompt(AiPromptPools.randomPrompt(messages, _selectedStyle, _random), userInitiated: true));
    analytics.track(AiPromptShuffledEvent(style: _selectedStyle.apiValue));
  }

  void _useSceneIdea() {
    final AppLocalizations? messages = _promptMessages;
    if (messages == null) return;
    setState(() => _setPrompt(AiPromptPools.sceneIdea(messages, _selectedStyle, _sceneCursor++), userInitiated: true));
  }

  void _selectStyle(AiStylePreset style, AiStylePickSource source) {
    analytics.track(AiStylePickedEvent(style: style.apiValue, source: source));
    setState(() => _selectedStyle = style);
    final String typed = _promptController.text.trim();
    if (typed.isEmpty || typed == _seededPrompt.trim()) _shufflePrompt();
  }

  Future<void> _openStyleSheet() async {
    if (_loadingGeneration) return;
    analytics.track(AiStyleSheetOpenedEvent(style: _selectedStyle.apiValue));
    final AiStylePreset? picked = await showAiStyleSheet(context, selected: _selectedStyle);
    if (picked != null && mounted && !_loadingGeneration) _selectStyle(picked, AiStylePickSource.sheet);
  }

  void _scrollToTop() {
    if (!_scroll.hasClients || _scroll.offset <= 0) return;
    if (context.reduceMotion) {
      _scroll.jumpTo(0);
      return;
    }
    _scroll.animateTo(0, duration: context.motion(PrismDurations.base), curve: PrismCurves.enter);
  }

  void _selectFromHistory(AiGenerationRecord record) {
    PrismHaptics.selection();
    setState(() {
      _hero = record;
      _heroFrom = AiApplyFromValue.hero;
    });
  }

  void _selectTake(AiGenerationRecord record) {
    if (record.id == _hero?.id) return;
    PrismHaptics.selection();
    final int position = _session.indexWhere((AiGenerationRecord take) => take.id == record.id);
    setState(() {
      _hero = record;
      _heroFrom = AiApplyFromValue.strip;
    });
    analytics.track(AiStripSwappedEvent(position: position, count: _session.length));
  }

  void _closeResult() => setState(() => _hero = null);

  Future<bool> _hasNetworkOrUnknown() async {
    try {
      return await getIt<ConnectivityService>().hasConnection();
    } catch (error, stackTrace) {
      logger.w('Connectivity check failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      return true;
    }
  }

  Future<void> _loadHistory({bool userInitiated = false}) async {
    final int loadGeneration = ++_historyLoadGeneration;
    final String userId = app_state.prismUser.id;
    final int ownerSession = CoinsService.instance.economySession;
    bool isCurrentLoad() =>
        mounted &&
        _isLoggedIn &&
        app_state.prismUser.id == userId &&
        ownerSession == CoinsService.instance.economySession &&
        loadGeneration == _historyLoadGeneration;
    _switchPromptOwner(_localOwnerId);
    if (_historyUserId != userId) {
      _historyUserId = userId;
      _history = <AiGenerationRecord>[];
      _hero = null;
      _session = <AiGenerationRecord>[];
      _confirmedSubmissionRecords.clear();
      _uploadAwards.clear();
      _unconfirmedSubmissionIds.clear();
    }
    if (!_isLoggedIn) {
      setState(() {
        _loadingHistory = false;
        _history = <AiGenerationRecord>[];
        _hero = null;
        _session = <AiGenerationRecord>[];
        _confirmedSubmissionRecords.clear();
        _uploadAwards.clear();
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
      if (!isCurrentLoad()) return;
      if (local.isNotEmpty) {
        final List<AiGenerationRecord> localWithConfirmed = mergeAiSubmissionHistory(
          local,
          _confirmedSubmissionRecords,
          fetchedUserId: userId,
        );
        setState(() => _history = localWithConfirmed);
      }
      final bool online = await _hasNetworkOrUnknown();
      if (!mounted || !isCurrentLoad()) return;
      if (!online) {
        setState(() => _historyFailed = local.isEmpty);
        if (userInitiated) toasts.error(context.l10n.economyAiOfflineSavedHistory);
        return;
      }
      final result = await _repository.fetchHistory(userId: userId);
      if (!isCurrentLoad()) return;
      final mergedResult = mergeAiSubmissionHistory(result, _confirmedSubmissionRecords, fetchedUserId: userId);
      setState(() => _history = mergedResult);
      analytics.track(AiHistoryOpenedEvent(count: result.length));
    } catch (error, stackTrace) {
      logger.w('AI history fetch failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      if (mounted && isCurrentLoad()) {
        setState(() => _historyFailed = true);
        toasts.error(aiHistoryFailureMessage(context.l10n, error), haptic: userInitiated);
      }
    } finally {
      if (mounted && loadGeneration == _historyLoadGeneration) {
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
    if (_loadingGeneration || _confirmingFollowUp) return false;
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

  Future<bool> _isOnlineForGeneration({required bool Function() ownsSession}) async {
    final bool online = await _hasNetworkOrUnknown();
    if (!online && mounted && ownsSession()) {
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
      prompt: prompt,
      style: style,
      qualityTier: qualityTier,
      request: (AiChargeMode mode, int coinsSpent, String? chargeTxId, String? remixOf) => _repository.generate(
        prompt: prompt,
        stylePreset: style,
        qualityTier: qualityTier,
        targetSize: targetSize,
        chargeMode: mode,
        coinsSpent: coinsSpent,
        chargeTxId: chargeTxId,
        remixOf: remixOf,
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

  /// Makes a new take of the hero. [prompt] is what to change: typed in the refine sheet, or a follow-up chip's.
  Future<void> _generateVariation({required String prompt, required bool fromSheet}) async {
    if (!_canStartGeneration()) return;

    if (prompt.isEmpty) {
      toasts.error(context.l10n.economyAiDescribeChanges);
      return;
    }
    if (prompt.length > _maxVariationChars) {
      toasts.error(context.l10n.economyAiVariationTooLong(_maxVariationChars));
      return;
    }
    final AiGenerationRecord? latest = _hero;
    if (latest == null || latest.userId != app_state.prismUser.id || !app_state.aiVariationsEnabled) {
      toasts.error(context.l10n.economyAiVariationUnavailable);
      return;
    }
    final AiStylePreset style = _selectedStyle;
    final AiQualityTier qualityTier = latest.qualityTier;
    await _runGeneration(
      prompt: prompt,
      style: style,
      qualityTier: qualityTier,
      request: (AiChargeMode mode, int coinsSpent, String? chargeTxId, String? remixOf) =>
          _repository.generateVariation(
            generationId: latest.id,
            chargeMode: mode,
            coinsSpent: coinsSpent,
            variationPrompt: prompt,
            chargeTxId: chargeTxId,
            remixOf: remixOf != null && latest.remixOf == remixOf ? remixOf : null,
          ),
      successEvent: (AiGenerationRecord generated, AiChargeMode mode, int coinsSpent) =>
          AiVariationUsedEvent(provider: generated.provider, mode: mode, coinsSpent: coinsSpent),
      onSuccess: (_) {
        if (fromSheet) _variationController.clear();
      },
    );
  }

  int get _confirmedFollowUpCost {
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return 0;
      return getIt<SettingsLocalDataSource>().get<int>(PersistenceKeys.aiFollowUpConfirmedCost, defaultValue: 0);
    } catch (error, stackTrace) {
      logger.w(
        'Could not read the confirmed follow-up price',
        tag: 'ai_wallpaper',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  void _saveConfirmedFollowUpCost(int cost) {
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return;
      unawaited(
        getIt<SettingsLocalDataSource>().set(PersistenceKeys.aiFollowUpConfirmedCost, cost).catchError((Object error) {
          logger.w('Could not save the confirmed follow-up price', tag: 'ai_wallpaper', error: error);
        }),
      );
    } catch (error, stackTrace) {
      logger.w(
        'Could not save the confirmed follow-up price',
        tag: 'ai_wallpaper',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Runs [followUp] on the hero at its tier's price. The first time, and when the price goes up, the user confirms.
  Future<void> _runFollowUp(AiFollowUp followUp) async {
    final AiGenerationRecord? parent = _hero;
    if (parent == null || _loadingGeneration || _confirmingFollowUp || !app_state.aiVariationsEnabled) return;
    final String ownerId = app_state.prismUser.id;
    final int cost = parent.qualityTier.costFor(isPro: app_state.prismUser.premium);
    if (cost > _confirmedFollowUpCost) {
      _confirmingFollowUp = true;
      final bool confirmed;
      try {
        confirmed = await showAiFollowUpConfirmSheet(context, cost: cost);
      } finally {
        _confirmingFollowUp = false;
      }
      if (!confirmed || !mounted || _hero?.id != parent.id || app_state.prismUser.id != ownerId) return;
      // A price that rose while the sheet was open was never confirmed. The next tap asks at the new price.
      if (parent.qualityTier.costFor(isPro: app_state.prismUser.premium) > cost) return;
      _saveConfirmedFollowUpCost(cost);
    }
    analytics.track(AiFollowUpUsedEvent(chipId: followUp.name));
    await _generateVariation(prompt: followUp.prompt, fromSheet: false);
  }

  Future<void> _runGeneration({
    required String prompt,
    required AiStylePreset style,
    required AiQualityTier qualityTier,
    required Future<AiGenerationRecord> Function(AiChargeMode mode, int coinsSpent, String? chargeTxId, String? remixOf)
    request,
    required AnalyticsEvent Function(AiGenerationRecord generated, AiChargeMode mode, int coinsSpent) successEvent,
    required void Function(AiGenerationRecord generated) onSuccess,
  }) async {
    if (_promptOwner != _localOwnerId) {
      unawaited(_loadHistory());
      return;
    }
    if (!_canStartGeneration()) return;
    final AiRemixSeed? remixLink = _remixLink;
    final String ownerId = app_state.prismUser.id;
    final int ownerSession = CoinsService.instance.economySession;
    bool ownsSession() =>
        _isLoggedIn && app_state.prismUser.id == ownerId && ownerSession == CoinsService.instance.economySession;
    final String operationId = AnalyticsCorrelation.newId();
    final Stopwatch elapsed = Stopwatch()..start();
    setState(() => _loadingGeneration = true);
    _scrollToTop();
    final bool online = await _isOnlineForGeneration(ownsSession: ownsSession);
    if (!online || !mounted || !ownsSession()) {
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
    if (!mounted || !ownsSession()) {
      if (reservation.success && ownsSession()) {
        await CoinsService.instance.rollbackAiGenerationReservation(
          reservation.mode,
          sourceTag: 'coins.rollback.ai_screen',
          reservationTransactionId: reservation.transactionId,
          operationId: operationId,
        );
      }
      if (mounted) setState(() => _loadingGeneration = false);
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
    AiGenerationActivity? liveActivity;
    try {
      final ColorScheme colors = Theme.of(context).colorScheme;
      liveActivity = await LiveActivityChannel.startAiGeneration(
        AiActivityRequest(
          prompt: prompt,
          style: style.label,
          accentArgb: colors.primary.toARGB32(),
          swatchArgb: style.swatchColors.map((Color c) => c.toARGB32()).toList(),
          generatingTitle: context.l10n.aiLiveActivityGenerating,
          readyTitle: context.l10n.aiLiveActivityReady,
          failedTitle: context.l10n.aiLiveActivityFailed,
          staleTitle: context.l10n.aiLiveActivityStale,
          openLabel: context.l10n.aiLiveActivityOpen,
        ),
      );
      if (!mounted || !ownsSession()) {
        await liveActivity?.cancel();
        if (ownsSession()) {
          await CoinsService.instance.rollbackAiGenerationReservation(
            reservation.mode,
            sourceTag: 'coins.rollback.ai_screen',
            reservationTransactionId: reservation.transactionId,
            operationId: operationId,
          );
        }
        return;
      }

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
        remixLink?.wallDocId,
      );
      generationSucceeded = true;

      // The repository handles persistence of the completed remote result for its original owner. Do not publish
      // it, report a commit against a replacement balance, or refund it in another sign-in session.
      if (!ownsSession()) return;
      unawaited(liveActivity?.finish(generated.displayUrl(isPremium: app_state.prismUser.premium)));

      CoinsService.instance.commitAiGenerationReservation(
        mode: reservation.mode,
        coinsSpent: reservation.coinsSpent,
        operationId: operationId,
        chargeTransactionId: reservation.transactionId,
        sourceTag: 'coins.commit.ai_screen',
      );

      if (mounted) {
        setState(() {
          // Any history snapshot started before this completion may omit the now-synced generation.
          ++_historyLoadGeneration;
          _loadingHistory = false;
          _historyFailed = false;
          _hero = generated;
          _heroFrom = AiApplyFromValue.hero;
          _session = <AiGenerationRecord>[..._session.where((item) => item.id != generated.id), generated];
          _history = <AiGenerationRecord>[generated, ..._history.where((item) => item.id != generated.id)];
        });
        _promptFocus.unfocus();
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
      if (remixLink != null && generated.remixOf != null) {
        analytics.track(
          RemixGeneratedEvent(sourceWallType: remixLink.sourceType, quality: generated.qualityTier.apiValue),
        );
      }
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
      if (!ownsSession()) return;
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
        unawaited(liveActivity?.fail(fullMessage));
      }
    } finally {
      unawaited(liveActivity?.cancel());
      if (mounted) {
        setState(() => _loadingGeneration = false);
      }
    }
  }

  /// Android opens the Set screen with this wall and no crop step. iOS saves it to Photos and shows the set guide.
  Future<void> _apply(AiGenerationRecord record) async {
    if (_applying || !_isLoggedIn || record.userId != app_state.prismUser.id) return;
    final int ownerSession = CoinsService.instance.economySession;
    bool ownsSession() =>
        mounted &&
        _isLoggedIn &&
        record.userId == app_state.prismUser.id &&
        ownerSession == CoinsService.instance.economySession;
    analytics.track(AiResultAppliedEvent(platform: hideSetWallpaperUi ? 'ios' : 'android', from: _heroFrom));
    setState(() => _applying = true);
    try {
      if (hideSetWallpaperUi) {
        await _save(record);
        return;
      }
      final AppLocalizations l10n = context.l10n;
      final File file;
      try {
        file = await aiDownloadToTempFile(record.displayUrl(isPremium: app_state.prismUser.premium));
      } catch (error, stackTrace) {
        logger.w('AI apply prep failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
        if (ownsSession()) toasts.error(aiDownloadFailureMessage(l10n, error));
        return;
      }
      if (!mounted || !ownsSession()) return;
      await SetWallpaperFlow.run(
        context,
        url: file.path,
        wallpaperSource: WallpaperSource.downloaded,
        forceScreen: true,
        entryPoint: 'ai_wallpaper',
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _save(AiGenerationRecord record) async {
    if (_saving || !_isLoggedIn || record.userId != app_state.prismUser.id) return;
    final int ownerSession = CoinsService.instance.economySession;
    bool ownsSession() =>
        _isLoggedIn && record.userId == app_state.prismUser.id && ownerSession == CoinsService.instance.economySession;
    final AppLocalizations l10n = context.l10n;
    _saving = true;
    final link = record.displayUrl(isPremium: app_state.prismUser.premium);
    try {
      final File localFile = await OfflineAssetStore.instance.resolve(link).timeout(aiAssetTransferTimeout);
      if (!ownsSession()) return;
      final request = DownloadRequest(
        link: localFile.path,
        filenameWithoutExtension: downloadBaseName(link),
        isLocalFile: true,
      );
      final result = await PrismMediaHostApi().enqueueDownload(request);
      if (!ownsSession()) return;
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
        if (ownsSession()) unawaited(RatePromptService.instance.maybePrompt(RatePromptTrigger.aiWallpaperSaved));
      } else if (isPhotosPermissionDenied(result.errorCode)) {
        if (mounted) showPhotosPermissionDenied(context);
      } else {
        toasts.error(l10n.economyAiDownloadFailed);
      }
    } catch (error, stackTrace) {
      logger.w('AI gallery save failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      if (ownsSession()) toasts.error(aiDownloadFailureMessage(l10n, error));
    } finally {
      _saving = false;
    }
  }

  Future<void> _share(AiGenerationRecord record) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    _trackShareEvent(const InviteShareTappedEvent(sourceContext: 'ai_wallpaper'));
    try {
      final AppLocalizations l10n = context.l10n;
      await (widget.shareSheet ?? showShareSheet)(
        context,
        ShareCardContent(
          imageUrl: record.displayUrl(isPremium: app_state.prismUser.premium),
          link: 'https://prismwalls.com',
          brandName: l10n.appTitle,
          contextLine: l10n.economyAiMadeWithPrism,
        ),
        'ai_wallpaper',
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
        defaultTags: <String>[record.stylePreset.apiValue],
      );
      if (!mounted || app_state.prismUser.id != record.userId) return;
      final AiSubmissionMetadata? edited = await showAiSubmitSheet(
        context,
        record: record,
        isPremium: app_state.prismUser.premium,
        metadata: metadata,
        prompt: record.prompt,
        style: record.stylePreset,
      );
      if (!mounted || app_state.prismUser.id != record.userId) return;
      if (edited == null) {
        return;
      }

      final String communityId = aiCommunityId(record.id);
      final String wallpaperUrl = record.displayUrl(isPremium: app_state.prismUser.premium);
      submissionStarted = true;
      final wallstore.WallSubmissionResult submissionResult =
          await (widget.submitForTesting?.call() ??
              wallstore.createRecord(
                communityId,
                'Prism',
                record.watermarkedImageUrl,
                wallpaperUrl,
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
                remixOf: record.remixOf,
                onUploadAward: (result) {
                  if (mounted && app_state.prismUser.id == record.userId) {
                    setState(() => _uploadAwards[record.id] = result.delta);
                  }
                },
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
          _session = _session.map((item) => item.id == updated.id ? updated : item).toList();
          if (_hero?.id == updated.id) {
            _hero = updated;
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
          if (record.remixOf != null) await analytics.track(RemixSubmittedEvent(generationId: record.id));
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
      cost: (_hero?.qualityTier ?? _selectedQualityTier).costFor(isPro: app_state.prismUser.premium),
      enabled: app_state.aiVariationsEnabled && _hero != null && !_loadingGeneration,
      onSubmit: () => _generateVariation(prompt: _variationController.text.trim(), fromSheet: true),
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
    return SignInPrompt(feature: context.l10n.economyAiWallpaper);
  }

  Widget _composeBody() {
    final bool busy = _loadingGeneration;
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
              child: AiPreviewStage(generating: busy),
            ),
            Padding(
              padding: page.copyWith(top: busy ? PrismSpace.xl : PrismSpace.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_remixLink != null) ...<Widget>[
                    AiRemixChip(seed: _remixLink!, onDrop: busy ? null : _dropRemixLink),
                    const SizedBox(height: PrismSpace.sm),
                  ],
                  AiPromptField(
                    controller: _promptController,
                    focusNode: _promptFocus,
                    maxChars: _maxPromptChars,
                    enabled: !busy,
                    onShuffle: _shufflePrompt,
                    onSceneIdea: _useSceneIdea,
                  ),
                ],
              ),
            ),
            PrismSectionHeader(
              title: AppLocalizations.of(context).economyAiStyle,
              actionLabel: AppLocalizations.of(context).economySeeAll,
              onAction: _openStyleSheet,
              small: true,
              padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xl, PrismSpace.page, PrismSpace.sm),
            ),
            AiStylePicker(
              selected: _selectedStyle,
              enabled: !busy,
              onSelected: (AiStylePreset style) => _selectStyle(style, AiStylePickSource.row),
            ),
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
              selectedId: null,
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

  Widget _resultView(AiGenerationRecord hero) {
    final bool canSubmit =
        canSubmitAiGeneration(hero, currentUserId: app_state.prismUser.id) &&
        !_confirmedSubmissionRecords.containsKey(hero.id) &&
        app_state.aiSubmitEnabled &&
        !_submitting &&
        !_unconfirmedSubmissionIds.contains(hero.id);
    return AiResultView(
      key: const ValueKey<String>('result'),
      record: hero,
      isPremium: app_state.prismUser.premium,
      session: _session,
      generating: _loadingGeneration,
      showFollowUps: app_state.aiVariationsEnabled,
      followUpCost: hero.qualityTier.costFor(isPro: app_state.prismUser.premium),
      onEditPrompt: _closeResult,
      onSelectTake: _selectTake,
      onFollowUp: _runFollowUp,
      trailing: const CoinBalanceChip(sourceTag: 'ai_gen_page', showStreak: false),
      notice: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (DailyMomentConfig.enabled && (_uploadAwards[hero.id] ?? 0) > 0)
            Text(
              context.l10n.economyCoinsEarned(_uploadAwards[hero.id]!),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          if (_unconfirmedSubmissionIds.contains(hero.id))
            AiUnconfirmedNotice(onCheck: () => context.router.push(const ReviewRoute())),
        ],
      ),
      actions: AiResultActions(
        showSave: !hideSetWallpaperUi,
        showRefine: app_state.aiVariationsEnabled,
        canSubmit: canSubmit,
        sharing: _sharing,
        applying: _applying,
        onApply: () => _apply(hero),
        onSave: () => _save(hero),
        onShare: () => _share(hero),
        onRefine: _openRefineSheet,
        onSubmit: () => _submitToCommunity(hero),
      ),
    );
  }

  Widget _generateBar() {
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (BuildContext context, int coinBalance, _) => ListenableBuilder(
        listenable: _promptController,
        builder: (BuildContext context, _) => AiGenerateBar(
          cost: _selectedQualityTier.costFor(isPro: app_state.prismUser.premium),
          balance: coinBalance,
          hasPrompt: _promptController.text.trim().isNotEmpty,
          loading: _loadingGeneration,
          onGenerate: _generate,
          onGetCoins: () => context.router.push(RewardsRoute(scrollToEarn: true)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_promptOwner != _localOwnerId) _scheduleOwnerSync();
    final bool available = _isRolloutEligible && _isLoggedIn;
    final AiGenerationRecord? hero = available && _hero?.userId == app_state.prismUser.id ? _hero : null;
    final Widget compose = PrismPage(
      title: AppLocalizations.of(context).economyAiWallpaper,
      showBack: Navigator.of(context).canPop(),
      actions: const <Widget>[CoinBalanceChip(sourceTag: 'ai_gen_page', showStreak: false)],
      bottomBar: available ? _generateBar() : null,
      body: available ? _composeBody() : _blockedState(),
    );
    return PopScope(
      canPop: hero == null,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) _closeResult();
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          TickerMode(
            enabled: hero == null,
            child: IgnorePointer(
              ignoring: hero != null,
              child: ExcludeSemantics(excluding: hero != null, child: compose),
            ),
          ),
          AnimatedSwitcher(
            duration: context.motion(PrismDurations.base),
            reverseDuration: context.motion(PrismDurations.fast),
            switchInCurve: PrismCurves.enter,
            switchOutCurve: PrismCurves.exit,
            transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(animation), child: child),
            ),
            child: hero == null ? const SizedBox.shrink(key: ValueKey<String>('compose')) : _resultView(hero),
          ),
        ],
      ),
    );
  }
}
