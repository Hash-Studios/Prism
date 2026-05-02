import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wallstore;
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart' show AiQualityTier;
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_sheet_chrome.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

abstract final class _AiGenSpace {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
}

class AiWallpaperTabPage extends StatefulWidget {
  const AiWallpaperTabPage({super.key});

  @override
  State<AiWallpaperTabPage> createState() => _AiWallpaperTabPageState();
}

class _AiWallpaperTabPageState extends State<AiWallpaperTabPage> {
  final AiGenerationRepositoryImpl _repository = AiGenerationRepositoryImpl();
  final Random _random = Random();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _variationController = TextEditingController();
  final FocusNode _promptFocus = FocusNode();

  AiStylePreset _selectedStyle = AiStylePreset.abstract;
  AiQualityTier _selectedQualityTier = AiQualityTier.fast;
  List<AiGenerationRecord> _history = <AiGenerationRecord>[];
  AiGenerationRecord? _latest;

  bool _loadingHistory = false;
  bool _loadingGeneration = false;
  bool _submitting = false;

  static const int _maxPromptChars = 4000;
  static const int _maxVariationChars = 2000;

  static const Map<AiStylePreset, List<String>> _scenePoolByStyle = <AiStylePreset, List<String>>{
    AiStylePreset.anime: <String>[
      'an anime skyline above floating islands',
      'a lone samurai on a neon-lit rainy street',
      'a futuristic shrine with cherry blossoms and holograms',
      'a dreamy anime night market with lantern glow',
      'a cyber-anime city horizon at blue hour',
    ],
    AiStylePreset.minimal: <String>[
      'minimal dunes and a single sun disk',
      'clean geometric mountain layers',
      'a serene monochrome ocean horizon',
      'simple abstract lines with balanced spacing',
      'a soft gradient sky over flat hills',
    ],
    AiStylePreset.cyberpunk: <String>[
      'a neon megacity street with wet reflections',
      'a futuristic alley with holographic billboards',
      'a high-tech skyline with flying traffic lanes',
      'a cyberpunk rooftop overlooking glowing towers',
      'a midnight city crossing with teal-magenta lights',
    ],
    AiStylePreset.watercolor: <String>[
      'a watercolor forest valley at dawn',
      'a hand-painted mountain lake scene',
      'soft watercolor clouds above rolling hills',
      'a tranquil riverbank with pastel tones',
      'an artistic watercolor coastline at sunset',
    ],
    AiStylePreset.meshGradient: <String>[
      'a smooth mesh gradient flow with layered blobs',
      'vibrant fluid gradient waves with depth',
      'soft multi-color mesh forms and gentle curves',
      'high-contrast mesh gradient ribbons',
      'pastel mesh gradient bloom with subtle texture',
    ],
    AiStylePreset.abstract: <String>[
      'an abstract fractal composition with dynamic curves',
      'layered liquid forms with modern depth',
      'bold abstract shapes with soft edges',
      'a surreal abstract field of floating geometry',
      'organic abstract waves with cinematic contrast',
    ],
    AiStylePreset.nature: <String>[
      'a misty mountain range at sunrise',
      'a dense evergreen forest with sun rays',
      'a dramatic coastal cliff with crashing waves',
      'a calm alpine lake under twilight sky',
      'a desert canyon with warm golden light',
    ],
  };

  static const List<String> _lightingPool = <String>[
    'soft ambient',
    'cinematic rim',
    'golden hour',
    'moonlit',
    'volumetric',
  ];

  static const List<String> _moodPool = <String>['calm', 'dreamy', 'epic', 'moody', 'uplifting'];

  static const List<String> _qualityPool = <String>[
    'high detail',
    'ultra clean composition',
    'crisp textures',
    'balanced contrast',
    'vibrant but natural colors',
  ];

  static const List<String> _loadingStatusLines = <String>[
    'Matching your screen size…',
    'Applying your style…',
    'Finalizing your wallpaper…',
  ];

  bool _motionAllowed(BuildContext context) => !MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    _seedDefaultPromptIfEmpty();
    _loadHistory();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _variationController.dispose();
    _promptFocus.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => app_state.prismUser.loggedIn && app_state.prismUser.id.trim().isNotEmpty;

  /// Decode size for the main 9:16 preview (logical width ≈ screen minus horizontal padding).
  ({int cacheWidth, int cacheHeight}) _mainPreviewDecodeExtents(BuildContext context) {
    final double logicalW = (MediaQuery.sizeOf(context).width - 32).clamp(120.0, 560.0);
    final double logicalH = logicalW * (16 / 9);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int cacheW = (logicalW * dpr).round().clamp(64, 4096);
    final int cacheH = (logicalH * dpr).round().clamp(64, 4096);
    return (cacheWidth: cacheW, cacheHeight: cacheH);
  }

  ({int cacheWidth, int cacheHeight}) _thumbDecodeExtents(
    BuildContext context, {
    required double logicalW,
    required double logicalH,
  }) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int cacheW = (logicalW * dpr).round().clamp(32, 2048);
    final int cacheH = (logicalH * dpr).round().clamp(32, 2048);
    return (cacheWidth: cacheW, cacheHeight: cacheH);
  }

  Future<bool> _hasNetworkOrUnknown() async {
    try {
      return await getIt<ConnectivityService>().hasConnection();
    } catch (error, stackTrace) {
      logger.w('Connectivity check failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      return true;
    }
  }

  bool _isOfflineOrNetworkError(Object error) {
    if (error is SocketException || error is TimeoutException || error is http.ClientException) {
      return true;
    }
    if (error is FirebaseException && (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
      return true;
    }
    if (error is FirestoreError) {
      final Object? original = error.original;
      if (original is FirebaseException && (original.code == 'unavailable' || original.code == 'deadline-exceeded')) {
        return true;
      }
    }
    return false;
  }

  String _toastForHistoryFailure(Object error) {
    if (_isOfflineOrNetworkError(error)) {
      return "You're offline or the network failed. Pull to refresh when you're back.";
    }
    return "Couldn't load history. Pull to refresh.";
  }

  String _toastForGenerateFailure(Object error) {
    if (error is AiGenerationApiException) {
      return error.message;
    }
    if (_isOfflineOrNetworkError(error)) {
      return 'No connection. Check your network and try again.';
    }
    return 'Something went wrong. Try again.';
  }

  String _toastForDownloadFailure(Object error) {
    if (_isOfflineOrNetworkError(error)) {
      return 'No connection. Check your network and try again.';
    }
    return "Couldn't save that file. Try again.";
  }

  void _seedDefaultPromptIfEmpty() {
    if (_promptController.text.trim().isNotEmpty) {
      return;
    }
    final prompt = _buildRandomPrompt();
    _promptController.text = prompt;
    _promptController.selection = TextSelection.fromPosition(TextPosition(offset: prompt.length));
  }

  String _pickRandom(List<String> values) {
    return values[_random.nextInt(values.length)];
  }

  String _buildRandomPrompt() {
    final scenes = _scenePoolByStyle[_selectedStyle] ?? _scenePoolByStyle[AiStylePreset.abstract]!;
    final scene = _pickRandom(scenes);
    final lighting = _pickRandom(_lightingPool);
    final mood = _pickRandom(_moodPool);
    final quality = _pickRandom(_qualityPool);
    return '$scene, $lighting lighting, $mood mood, $quality, vertical phone wallpaper, no text';
  }

  void _shufflePrompt() {
    final prompt = _buildRandomPrompt();
    setState(() {
      _promptController.text = prompt;
      _promptController.selection = TextSelection.fromPosition(TextPosition(offset: prompt.length));
    });
    analytics.track(AiPromptShuffledEvent(style: _selectedStyle.apiValue));
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

  String _targetSizeForDevice(BuildContext context) {
    const int minShortEdge = 720;
    const int maxLongEdge = 2048;
    const double maxPixelBudget = 2.9 * 1000 * 1000;

    final media = MediaQuery.of(context);
    final double dpr = media.devicePixelRatio.clamp(1.0, 3.0);
    final int rawW = (media.size.width * dpr).round().clamp(360, 4096);
    final int rawH = (media.size.height * dpr).round().clamp(640, 4096);

    final bool portrait = rawH >= rawW;
    final int longRaw = portrait ? rawH : rawW;
    final int shortRaw = portrait ? rawW : rawH;
    final double aspect = longRaw / shortRaw;

    int shortTarget = shortRaw.clamp(minShortEdge, maxLongEdge);
    int longTarget = (shortTarget * aspect).round();
    if (longTarget > maxLongEdge) {
      longTarget = maxLongEdge;
      shortTarget = (longTarget / aspect).round().clamp(minShortEdge, maxLongEdge);
    }

    int width = portrait ? shortTarget : longTarget;
    int height = portrait ? longTarget : shortTarget;

    final int pixels = width * height;
    if (pixels > maxPixelBudget) {
      final double scale = sqrt(maxPixelBudget / pixels);
      width = (width * scale).round();
      height = (height * scale).round();
    }

    width = ((width / 8).round() * 8).clamp(512, maxLongEdge);
    height = ((height / 8).round() * 8).clamp(512, maxLongEdge);
    return '${width}x$height';
  }

  bool _isAspectRatioMismatch({required AiGenerationRecord generated, required String targetSize}) {
    final List<String> parts = targetSize.split('x');
    if (parts.length != 2) {
      return false;
    }
    final int? tw = int.tryParse(parts[0]);
    final int? th = int.tryParse(parts[1]);
    if (tw == null || th == null || tw == 0 || th == 0 || generated.width <= 0 || generated.height <= 0) {
      return false;
    }
    final double targetRatio = tw / th;
    final double generatedRatio = generated.width / generated.height;
    return (generatedRatio - targetRatio).abs() > 0.08;
  }

  Future<void> _loadHistory() async {
    if (!_isLoggedIn) {
      setState(() {
        _history = <AiGenerationRecord>[];
        _latest = null;
      });
      return;
    }
    setState(() => _loadingHistory = true);
    try {
      final bool online = await _hasNetworkOrUnknown();
      if (!online) {
        if (mounted) {
          toasts.error("You're offline. History will refresh when you're connected.");
        }
        return;
      }
      final result = await _repository.fetchHistory(userId: app_state.prismUser.id);
      setState(() {
        _history = result;
        _latest = result.isEmpty ? null : result.first;
      });
      analytics.track(AiHistoryOpenedEvent(count: result.length));
    } catch (error, stackTrace) {
      logger.w('AI history fetch failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      toasts.error(_toastForHistoryFailure(error));
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _generate({bool variation = false}) async {
    if (_loadingGeneration) return;
    if (!_isLoggedIn) {
      toasts.error('Please sign in to generate wallpapers.');
      return;
    }
    if (!_isRolloutEligible) {
      toasts.error('AI generation is currently rolling out. Please try again soon.');
      return;
    }

    final String prompt = variation ? _variationController.text.trim() : _promptController.text.trim();
    if (!variation && prompt.isEmpty) {
      toasts.error('Add a description or tap a starting chip, then try again.');
      _promptFocus.requestFocus();
      return;
    }
    if (variation && prompt.isEmpty) {
      toasts.error('Say what you want different—colors, mood, details, and so on.');
      return;
    }
    if (!variation && prompt.length > _maxPromptChars) {
      toasts.error('Description is too long (max $_maxPromptChars characters).');
      return;
    }
    if (variation && prompt.length > _maxVariationChars) {
      toasts.error('That refinement is too long (max $_maxVariationChars characters).');
      return;
    }
    if (variation && (_latest == null || !app_state.aiVariationsEnabled)) {
      toasts.error('Refinements are not available right now.');
      return;
    }

    final bool online = await _hasNetworkOrUnknown();
    if (!online) {
      toasts.error('No connection. Connect to the internet, then try again.');
      return;
    }
    if (!mounted) {
      return;
    }

    final String? targetSize = variation ? null : _targetSizeForDevice(context);

    setState(() => _loadingGeneration = true);

    final reservation = await CoinsService.instance.reserveForAiGeneration(
      qualityTier: _selectedQualityTier,
      sourceTag: 'coins.reserve.ai_screen',
    );
    if (!reservation.success || reservation.mode == AiChargeMode.insufficient) {
      CoinsService.instance.logLowBalanceNudge(
        sourceTag: 'coins.ai_generation.low_balance',
        requiredCoins: _selectedQualityTier.coinCost,
      );
      toasts.error('Need ${_selectedQualityTier.coinCost} coins to generate.');
      setState(() => _loadingGeneration = false);
      return;
    }

    analytics.track(
      AiGenerateStartedEvent(
        style: _selectedStyle.apiValue,
        quality: _selectedQualityTier.apiValue,
        mode: aiChargeModeValueFromDomain(reservation.mode),
      ),
    );

    try {
      final AiGenerationRecord generated = variation
          ? await _repository.generateVariation(
              generationId: _latest!.id,
              chargeMode: reservation.mode,
              coinsSpent: reservation.coinsSpent,
              variationPrompt: prompt,
            )
          : await _repository.generate(
              prompt: prompt,
              stylePreset: _selectedStyle,
              qualityTier: _selectedQualityTier,
              targetSize: targetSize!,
              chargeMode: reservation.mode,
              coinsSpent: reservation.coinsSpent,
            );

      CoinsService.instance.commitAiGenerationReservation(
        mode: reservation.mode,
        coinsSpent: reservation.coinsSpent,
        sourceTag: 'coins.commit.ai_screen',
        reservationTransactionId: reservation.transactionId,
        generationId: generated.id,
        imageUrl: generated.watermarkedImageUrl,
        thumbUrl: generated.watermarkedImageUrl,
        prompt: generated.prompt,
        stylePreset: generated.stylePreset.apiValue,
      );

      setState(() {
        _latest = generated;
        _history = <AiGenerationRecord>[generated, ..._history.where((item) => item.id != generated.id)];
      });

      if (mounted && _motionAllowed(context)) {
        HapticFeedback.lightImpact();
      }

      if (variation) {
        analytics.track(
          AiVariationUsedEvent(
            provider: generated.provider,
            mode: aiChargeModeValueFromDomain(reservation.mode),
            coinsSpent: reservation.coinsSpent,
          ),
        );
      } else {
        analytics.track(
          AiGenerateSuccessEvent(
            provider: generated.provider,
            mode: aiChargeModeValueFromDomain(reservation.mode),
            coinsSpent: reservation.coinsSpent,
          ),
        );
        if (targetSize != null && _isAspectRatioMismatch(generated: generated, targetSize: targetSize)) {
          toasts.error('Crop may differ slightly on your device.');
        }
      }
      if (variation) {
        _variationController.clear();
      }
    } catch (error, stackTrace) {
      logger.w('AI generation failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      await CoinsService.instance.rollbackAiGenerationReservation(
        reservation.mode,
        sourceTag: 'coins.rollback.ai_screen',
        reservationTransactionId: reservation.transactionId,
        coinsToRefund: _selectedQualityTier.coinCost,
      );
      analytics.track(
        AiGenerateFailedEvent(error: error.toString(), mode: aiChargeModeValueFromDomain(reservation.mode)),
      );
      toasts.error(_toastForGenerateFailure(error));
    } finally {
      if (mounted) {
        setState(() => _loadingGeneration = false);
      }
    }
  }

  Future<void> _setWallpaper(AiGenerationRecord record) async {
    try {
      final file = await _downloadToTempFile(record.displayUrl(isPremium: app_state.prismUser.premium));
      if (!mounted) return;
      context.router.push(DownloadWallpaperRoute(source: WallpaperSource.prism, file: file));
    } catch (error, stackTrace) {
      logger.w('AI set-wallpaper prep failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      toasts.error(_toastForDownloadFailure(error));
    }
  }

  Future<void> _save(AiGenerationRecord record) async {
    final link = record.displayUrl(isPremium: app_state.prismUser.premium);
    try {
      final request = DownloadRequest(
        link: link,
        filenameWithoutExtension: link.split('/').last.replaceAll('.jpg', '').replaceAll('.png', ''),
      );
      final result = await PrismMediaHostApi().enqueueDownload(request).timeout(const Duration(seconds: 15));
      if (result.success) {
        toasts.codeSend('Wall downloaded in Pictures/Prism!');
      } else {
        toasts.error(result.message ?? "Couldn't download! Please retry.");
      }
    } catch (error, stackTrace) {
      logger.w('AI gallery save failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      toasts.error(_toastForDownloadFailure(error));
    }
  }

  Future<File> _downloadToTempFile(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('download_failed', uri: Uri.parse(url));
    }
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/ai_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path);
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  Future<void> _submitToCommunity(AiGenerationRecord record) async {
    if (!_isLoggedIn) {
      toasts.error('Please sign in to submit wallpapers.');
      return;
    }
    if (!app_state.aiSubmitEnabled) {
      toasts.error('AI submit is currently disabled.');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    analytics.track(AiSubmitStartedEvent(generationId: record.id));
    try {
      final metadata = await _repository.prefillSubmissionMetadata(generationId: record.id);
      final edited = await _showSubmissionEditor(metadata);
      if (edited == null) {
        return;
      }

      final String communityId = _buildCommunityId(record.id);
      await wallstore.createRecord(
        communityId,
        'Prism',
        record.watermarkedImageUrl,
        record.imageUrl,
        '${record.width}x${record.height}',
        'AI',
        edited['title']?.toString(),
        edited['category']?.toString(),
        edited['description']?.toString(),
        false,
        wallpaperTags: (edited['tags'] as List<Object?>? ?? const <Object?>[])
            .map((Object? tag) => tag?.toString() ?? '')
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false),
        isAiGenerated: true,
        aiGenerationId: record.id,
        aiProvider: record.provider,
        aiModel: record.model,
        aiOriginalImageUrl: record.imageUrl,
        aiPrompt: record.prompt,
        aiStylePreset: record.stylePreset.apiValue,
      );
      final updated = record.copyWith(
        submittedWallId: communityId,
        submittedAt: DateTime.now().toUtc(),
        status: 'submitted',
      );
      await _repository.saveHistoryRecord(updated);
      setState(() {
        _history = _history.map((item) => item.id == updated.id ? updated : item).toList();
        if (_latest?.id == updated.id) {
          _latest = updated;
        }
      });
      analytics.track(AiSubmitSuccessEvent(generationId: record.id));
      if (mounted && _motionAllowed(context)) {
        HapticFeedback.selectionClick();
      }
      toasts.codeSend('Submitted for review.');
    } catch (error, stackTrace) {
      logger.w('AI community submit failed', tag: 'ai_wallpaper', error: error, stackTrace: stackTrace);
      toasts.error(
        _isOfflineOrNetworkError(error) ? 'No connection. Try again when online.' : 'Submit failed. Try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _buildCommunityId(String generationId) {
    final sanitized = generationId.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
    final suffix = sanitized.isEmpty ? 'GEN' : sanitized.substring(0, min(10, sanitized.length));
    return 'AI$suffix';
  }

  // One-tap confirm submit sheet — auto-fills from prompt + style
  Future<Map<String, dynamic>?> _showSubmissionEditor(Map<String, dynamic> metadata) async {
    Map<String, dynamic>? output;
    final title = (metadata['title'] ?? '').toString().trim();
    final desc = (metadata['description'] ?? '').toString().trim();
    final category = (metadata['category'] ?? _selectedStyle.label).toString().trim();
    final existingTags = metadata['tags'] is List
        ? (metadata['tags'] as List<Object?>)
              .map((Object? item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : <String>[_selectedStyle.apiValue];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).primaryColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final ({int cacheWidth, int cacheHeight}) submitThumb = _thumbDecodeExtents(ctx, logicalW: 72, logicalH: 120);
        final TextTheme textTheme = Theme.of(ctx).textTheme;
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: AiSheetChrome.bodyPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const AiSheetDragHandle(),
                const SizedBox(height: _AiGenSpace.md),
                if (_latest != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 120,
                          child: _DecodedNetworkImage(
                            url: _latest!.displayUrl(isPremium: app_state.prismUser.premium),
                            cacheWidth: submitThumb.cacheWidth,
                            cacheHeight: submitThumb.cacheHeight,
                            filterQuality: FilterQuality.low,
                            errorColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: _AiGenSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Share with the community?', style: textTheme.titleMedium),
                            const SizedBox(height: _AiGenSpace.xs),
                            Text(
                              'Moderators review submissions before they appear in Prism. Only share work you have rights to.',
                              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                            ),
                            const SizedBox(height: _AiGenSpace.sm),
                            Text(
                              '"${(title.isNotEmpty ? title : _promptController.text.trim()).split(',').first.trim()}"  ·  ${_selectedStyle.label}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(color: scheme.secondary.withValues(alpha: 0.72)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Share with the community?', style: textTheme.titleMedium),
                      const SizedBox(height: _AiGenSpace.xs),
                      Text(
                        'Moderators review submissions before they appear in Prism. Only share work you have rights to.',
                        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                      ),
                    ],
                  ),
                const SizedBox(height: _AiGenSpace.lg),
                FilledButton.icon(
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: const Text('Submit for review'),
                  onPressed: () {
                    final prompt = _promptController.text.trim();
                    final autoTags = <String>[
                      ...prompt
                          .split(' ')
                          .take(3)
                          .map((w) => w.toLowerCase().replaceAll(RegExp('[^a-z]'), ''))
                          .where((w) => w.length > 2),
                      ...existingTags,
                    ];
                    output = <String, dynamic>{
                      'title': title.isNotEmpty ? title : prompt.split(',').first.trim(),
                      'description': desc.isNotEmpty ? desc : prompt,
                      'category': category.isNotEmpty ? category : _selectedStyle.label,
                      'tags': autoTags.toSet().toList(),
                    };
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: _AiGenSpace.xs),
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ],
            ),
          ),
        );
      },
    );
    return output;
  }

  // Variation / advanced options sheet
  void _showAdvancedSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).primaryColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: AiSheetChrome.bodyPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const AiSheetDragHandle(),
                  const SizedBox(height: _AiGenSpace.md),
                  Text('Refine this wallpaper', style: Theme.of(ctx).textTheme.displaySmall),
                  const SizedBox(height: _AiGenSpace.xs),
                  Text(
                    'Say what should change. We keep the rest of the composition as close as we can.',
                    style: Theme.of(
                      ctx,
                    ).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant, height: 1.35),
                  ),
                  const SizedBox(height: _AiGenSpace.md),
                  TextField(
                    controller: _variationController,
                    minLines: 2,
                    maxLines: 4,
                    autofocus: true,
                    inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(_maxVariationChars)],
                    decoration: InputDecoration(
                      labelText: 'Changes you want',
                      hintText: 'Darker sky, warmer palette, softer edges…',
                      filled: true,
                      fillColor: Theme.of(ctx).hintColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: _AiGenSpace.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: const Text('Generate refinement'),
                      onPressed: !app_state.aiVariationsEnabled || _latest == null || _loadingGeneration
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              _generate(variation: true);
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── UI builders ──────────────────────────────────────────────────────────

  Widget _buildQualitySelector() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Quality & cost',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: AiQualityTier.values.map((tier) {
              final bool selected = tier == _selectedQualityTier;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: '${tier.label}, ${tier.coinCost} coins',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedQualityTier = tier),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? scheme.primary.withValues(alpha: 0.22) : Theme.of(context).hintColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2),
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(
                                tier.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? scheme.primary : scheme.secondary,
                                ),
                              ),
                              Text(
                                '${tier.coinCost}c',
                                style: TextStyle(fontSize: 11, color: scheme.secondary.withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultArea(AiGenerationRecord? current, bool loading) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool canSubmit =
        current != null && current.submittedWallId == null && app_state.aiSubmitEnabled && !_submitting;
    final ({int cacheWidth, int cacheHeight}) decode = _mainPreviewDecodeExtents(context);

    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: _motionAllowed(context) ? 320 : 0),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              if (!_motionAllowed(context)) {
                return child;
              }
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.98,
                    end: 1,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
            child: loading
                ? _buildResultShimmer(key: const ValueKey<String>('shimmer'))
                : current == null
                ? _buildResultPlaceholder(key: const ValueKey<String>('placeholder'))
                : Stack(
                    key: ValueKey<String>(current.id),
                    fit: StackFit.expand,
                    children: <Widget>[
                      _DecodedNetworkImage(
                        url: current.displayUrl(isPremium: app_state.prismUser.premium),
                        cacheWidth: decode.cacheWidth,
                        cacheHeight: decode.cacheHeight,
                        errorColor: scheme.surfaceContainerHighest,
                      ),
                      if (canSubmit)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Semantics(
                            button: true,
                            label: 'Submit wallpaper for community review',
                            child: Material(
                              color: scheme.inverseSurface.withValues(alpha: 0.88),
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _submitToCommunity(current),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Icon(Icons.upload_outlined, color: scheme.onInverseSurface, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultShimmer({Key? key}) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle? lineStyle = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary)),
          const SizedBox(height: _AiGenSpace.md),
          Text('Crafting your wallpaper…', style: lineStyle?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: _AiGenSpace.xs),
          if (_motionAllowed(context))
            _AiCyclingStatusLine(lines: _loadingStatusLines, textStyle: lineStyle)
          else
            Text(_loadingStatusLines.first, textAlign: TextAlign.center, style: lineStyle),
        ],
      ),
    );
  }

  Widget _buildResultPlaceholder({Key? key}) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.auto_awesome_rounded, size: 48, color: scheme.primary.withValues(alpha: 0.45)),
          const SizedBox(height: _AiGenSpace.sm),
          Text(
            'Your next wallpaper',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: _AiGenSpace.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Pick a style, describe the scene, then tap Generate. Chips below drop in a full idea you can edit.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    String? semanticLabel,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: Material(
        color: isPrimary ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 22, color: isPrimary ? scheme.onPrimary : scheme.onSurface),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(AiGenerationRecord current) {
    final bool canVary = app_state.aiVariationsEnabled && !_loadingGeneration;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          if (!hideSetWallpaperUi)
            actionButton(
              icon: Icons.wallpaper_outlined,
              label: 'Set',
              semanticLabel: 'Set as wallpaper',
              onTap: () => _setWallpaper(current),
              isPrimary: true,
            ),
          actionButton(
            icon: Icons.download_outlined,
            label: 'Save',
            semanticLabel: 'Save image to your device',
            onTap: () => _save(current),
          ),
          if (canVary)
            actionButton(
              icon: Icons.auto_fix_high,
              label: 'Refine',
              semanticLabel: 'Refine this wallpaper with a follow-up description',
              onTap: _showAdvancedSheet,
            ),
        ],
      ),
    );
  }

  Widget _buildStylePicker() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: AiStylePreset.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final style = AiStylePreset.values[index];
          final bool selected = style == _selectedStyle;
          final List<Color> colors = style.swatchColors;
          return Semantics(
            button: true,
            selected: selected,
            label: 'Style: ${style.label}',
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedStyle = style);
                _shufflePrompt();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? Colors.white : Colors.transparent, width: selected ? 2.5 : 0),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(color: colors.first.withValues(alpha: 0.45), blurRadius: 10, spreadRadius: 1),
                        ]
                      : null,
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      style.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Proxima Nova',
                        shadows: <Shadow>[Shadow(blurRadius: 4, color: Colors.black45)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromptArea(bool loading) {
    final theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<String> scenes = (_scenePoolByStyle[_selectedStyle] ?? _scenePoolByStyle[AiStylePreset.abstract]!)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Starting points',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: _AiGenSpace.xs),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: scenes.map((scene) {
            final short = scene.length > 28 ? '${scene.substring(0, 28)}…' : scene;
            return ActionChip(
              label: Text(short, style: const TextStyle(fontSize: 12)),
              tooltip: 'Use this scene in your description (editable)',
              onPressed: loading
                  ? null
                  : () => setState(() {
                      _promptController.text = '$scene, vertical phone wallpaper, no text';
                      _promptController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _promptController.text.length),
                      );
                    }),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          }).toList(),
        ),
        const SizedBox(height: _AiGenSpace.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _promptController,
                focusNode: _promptFocus,
                minLines: 2,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(_maxPromptChars)],
                decoration: InputDecoration(
                  labelText: 'Description',
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  hintText: 'e.g. misty peaks at dawn, soft light, no text on image',
                  helperText:
                      'Subject, mood, and lighting work well. The box may start with an example—edit it or tap refresh for another.',
                  helperMaxLines: 3,
                  filled: true,
                  fillColor: theme.hintColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Shuffle a new example description',
              onPressed: loading ? null : _shufflePrompt,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenerateButton(bool canUseAi, bool loading, int coinBalance) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int cost = _selectedQualityTier.coinCost;
    final bool hasCoins = coinBalance >= cost;
    final String label;
    if (loading) {
      label = 'Crafting…';
    } else if (hasCoins) {
      label = 'Generate  ·  $cost coins';
    } else {
      label = 'Get coins · need $cost';
    }

    final bool canPress = canUseAi && !loading;
    final VoidCallback? onPressed;
    if (!canPress) {
      onPressed = null;
    } else if (!hasCoins) {
      onPressed = () => context.router.push(const CoinTransactionsRoute());
    } else {
      onPressed = () => _generate();
    }

    final bool showAccent = canPress;

    return Container(
      decoration: BoxDecoration(
        gradient: showAccent
            ? LinearGradient(
                colors: <Color>[
                  scheme.primary,
                  Color.alphaBlend(scheme.primary.withValues(alpha: 0.88), scheme.surface),
                ],
              )
            : null,
        color: showAccent ? null : Theme.of(context).hintColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: showAccent ? scheme.onPrimary : scheme.secondary.withValues(alpha: 0.4),
            disabledForegroundColor: scheme.secondary.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            shadowColor: Colors.transparent,
          ),
          onPressed: onPressed,
          icon: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary.withValues(alpha: 0.85)),
                )
              : Icon(hasCoins ? Icons.auto_awesome_rounded : Icons.account_balance_wallet_outlined, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    );
  }

  Widget _buildHistoryStrip() {
    if (_loadingHistory) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    if (_history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: _AiGenSpace.xl),
        child: Text(
          'Each generation you keep appears here so you can compare or switch back.',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: _AiGenSpace.xl),
        Row(
          children: <Widget>[
            Text('Recent', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
          ],
        ),
        const SizedBox(height: _AiGenSpace.sm),
        SizedBox(
          height: 104,
          child: Builder(
            builder: (BuildContext listContext) {
              final ({int cacheWidth, int cacheHeight}) hx = _thumbDecodeExtents(
                listContext,
                logicalW: 60,
                logicalH: 104,
              );
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                addAutomaticKeepAlives: false,
                itemCount: _history.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final item = _history[index];
                  final bool isSelected = item.id == _latest?.id;
                  final bool motion = _motionAllowed(listContext);
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: isSelected ? 'Selected generation' : 'Past generation',
                    child: GestureDetector(
                      onTap: () => setState(() => _latest = item),
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: motion ? 200 : 0),
                        curve: Curves.easeOutCubic,
                        opacity: isSelected ? 1.0 : 0.5,
                        child: AnimatedScale(
                          duration: Duration(milliseconds: motion ? 200 : 0),
                          curve: Curves.easeOutCubic,
                          scale: isSelected ? 1.0 : 0.96,
                          child: Container(
                            width: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _DecodedNetworkImage(
                                url: item.displayUrl(isPremium: app_state.prismUser.premium),
                                cacheWidth: hx.cacheWidth,
                                cacheHeight: hx.cacheHeight,
                                filterQuality: FilterQuality.low,
                                errorColor: theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canUseAi = _isRolloutEligible;
    final AiGenerationRecord? current = _latest;
    final bool canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: canPop,
        title: const Text('AI wallpaper'),
        actions: const <Widget>[
          CoinBalanceChip(sourceTag: 'ai_gen_page', showStreak: false),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, _AiGenSpace.sm, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!canUseAi)
                  Container(
                    margin: const EdgeInsets.only(bottom: _AiGenSpace.md),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          app_state.aiEnabled ? 'Opening gradually' : 'Unavailable',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          app_state.aiEnabled
                              ? 'AI wallpaper is rolling out (${app_state.aiRolloutPercent}% of accounts). Try again soon.'
                              : 'AI wallpaper is turned off right now.',
                          textAlign: TextAlign.start,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                _buildResultArea(current, _loadingGeneration),
                if (current != null) ...<Widget>[
                  const SizedBox(height: _AiGenSpace.sm),
                  _buildActionRow(current),
                  const SizedBox(height: _AiGenSpace.lg),
                ] else
                  const SizedBox(height: _AiGenSpace.lg),
                _buildStylePicker(),
                const SizedBox(height: _AiGenSpace.md),
                _buildQualitySelector(),
                const SizedBox(height: _AiGenSpace.md),
                _buildPromptArea(_loadingGeneration),
                const SizedBox(height: _AiGenSpace.md),
                ValueListenableBuilder<int>(
                  valueListenable: CoinsService.instance.balanceNotifier,
                  builder: (BuildContext context, int coinBalance, _) {
                    return _buildGenerateButton(canUseAi, _loadingGeneration, coinBalance);
                  },
                ),
                _buildHistoryStrip(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiCyclingStatusLine extends StatefulWidget {
  const _AiCyclingStatusLine({required this.lines, required this.textStyle});

  final List<String> lines;
  final TextStyle? textStyle;

  @override
  State<_AiCyclingStatusLine> createState() => _AiCyclingStatusLineState();
}

class _AiCyclingStatusLineState extends State<_AiCyclingStatusLine> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.lines.length <= 1) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _index = (_index + 1) % widget.lines.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String line = widget.lines[_index % widget.lines.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        child: Text(line, key: ValueKey<String>(line), textAlign: TextAlign.center, style: widget.textStyle),
      ),
    );
  }
}

class _DecodedNetworkImage extends StatelessWidget {
  const _DecodedNetworkImage({
    required this.url,
    required this.cacheWidth,
    required this.cacheHeight,
    this.filterQuality = FilterQuality.medium,
    required this.errorColor,
  });

  final String url;
  final int cacheWidth;
  final int cacheHeight;
  final FilterQuality filterQuality;
  final Color errorColor;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: filterQuality,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => ColoredBox(color: errorColor),
    );
  }
}
