import 'dart:io';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
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
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
      final result = await _repository.fetchHistory(userId: app_state.prismUser.id);
      setState(() {
        _history = result;
        _latest = result.isEmpty ? null : result.first;
      });
      analytics.track(AiHistoryOpenedEvent(count: result.length));
    } catch (_) {
      toasts.error('Unable to load AI history right now.');
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
      toasts.error('Describe the wallpaper you want to generate.');
      _promptFocus.requestFocus();
      return;
    }
    if (variation && (_latest == null || !app_state.aiVariationsEnabled)) {
      toasts.error('Variation is not available right now.');
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
          toasts.error('Generated image ratio may not match your device perfectly.');
        }
      }
      if (variation) {
        _variationController.clear();
      }
    } catch (error) {
      await CoinsService.instance.rollbackAiGenerationReservation(
        reservation.mode,
        sourceTag: 'coins.rollback.ai_screen',
        reservationTransactionId: reservation.transactionId,
        coinsToRefund: _selectedQualityTier.coinCost,
      );
      analytics.track(
        AiGenerateFailedEvent(error: error.toString(), mode: aiChargeModeValueFromDomain(reservation.mode)),
      );
      if (error is AiGenerationApiException) {
        toasts.error(error.message);
      } else {
        toasts.error('Generation failed. Please try again.');
      }
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
    } catch (_) {
      toasts.error('Unable to prepare wallpaper file.');
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
    } catch (_) {
      toasts.error("Couldn't download! Please retry.");
    }
  }

  Future<File> _downloadToTempFile(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('download_failed');
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
      toasts.codeSend('AI wallpaper submitted for review.');
    } catch (error) {
      toasts.error('Unable to submit wallpaper right now.');
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  height: 4,
                  width: 32,
                  decoration: BoxDecoration(color: Theme.of(ctx).hintColor, borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(height: 16),
                if (_latest != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 60,
                      height: 100,
                      child: Image.network(
                        _latest!.displayUrl(isPremium: app_state.prismUser.premium),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text('Submit to Community?', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '"${(title.isNotEmpty ? title : _promptController.text.trim()).split(',').first.trim()}"  ·  ${_selectedStyle.label}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.secondary.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: const Text('Submit'),
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
                ),
                const SizedBox(height: 8),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      height: 4,
                      width: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).hintColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Variation', style: Theme.of(ctx).textTheme.displaySmall),
                  const SizedBox(height: 4),
                  Text(
                    'Describe what to change from the last result.',
                    style: Theme.of(
                      ctx,
                    ).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.secondary.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _variationController,
                    minLines: 2,
                    maxLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Darker background, more neon, colder tones…',
                      filled: true,
                      fillColor: Theme.of(ctx).hintColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: const Text('Generate Variation'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: AiQualityTier.values.map((tier) {
          final bool selected = tier == _selectedQualityTier;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _selectedQualityTier = tier),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF7C4DFF).withValues(alpha: 0.25) : Theme.of(context).hintColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? const Color(0xFF7C4DFF) : Colors.transparent, width: 2),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        tier.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? const Color(0xFF7C4DFF) : Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      Text(
                        '${tier.coinCost}c',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultArea(AiGenerationRecord? current, bool loading) {
    final bool canSubmit =
        current != null && current.submittedWallId == null && app_state.aiSubmitEnabled && !_submitting;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: loading
              ? _buildResultShimmer(key: const ValueKey<String>('shimmer'))
              : current == null
              ? _buildResultPlaceholder(key: const ValueKey<String>('placeholder'))
              : Stack(
                  key: ValueKey<String>(current.id),
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.network(
                      current.displayUrl(isPremium: app_state.prismUser.premium),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black26),
                    ),
                    if (canSubmit)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _submitToCommunity(current),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                            child: const Icon(Icons.upload_outlined, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildResultShimmer({Key? key}) {
    return Container(
      key: key,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF7C4DFF), Color(0xFF311B92)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.3, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            onEnd: () {
              if (mounted) setState(() {});
            },
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 52),
          ),
          const SizedBox(height: 16),
          const Text(
            'Crafting your wallpaper…',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Proxima Nova'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPlaceholder({Key? key}) {
    final theme = Theme.of(context);
    return Container(
      key: key,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF7C4DFF).withValues(alpha: 0.22),
            const Color(0xFF311B92).withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.auto_awesome_rounded, size: 52, color: const Color(0xFF7C4DFF).withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text(
            'Your wallpaper appears here',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary.withValues(alpha: 0.45)),
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
  }) {
    return Material(
      color: isPrimary ? const Color(0xFF7C4DFF) : Colors.transparent,
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
              Icon(icon, size: 22, color: isPrimary ? Colors.white : Theme.of(context).colorScheme.onSurface),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
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
              onTap: () => _setWallpaper(current),
              isPrimary: true,
            ),
          actionButton(icon: Icons.download_outlined, label: 'Save', onTap: () => _save(current)),
          if (canVary) actionButton(icon: Icons.auto_fix_high, label: 'Vary', onTap: _showAdvancedSheet),
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
          return GestureDetector(
            onTap: () {
              setState(() => _selectedStyle = style);
              _shufflePrompt();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
          );
        },
      ),
    );
  }

  Widget _buildPromptArea(bool loading) {
    final theme = Theme.of(context);
    final List<String> scenes = (_scenePoolByStyle[_selectedStyle] ?? _scenePoolByStyle[AiStylePreset.abstract]!)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: scenes.map((scene) {
            final short = scene.length > 28 ? '${scene.substring(0, 28)}…' : scene;
            return ActionChip(
              label: Text(short, style: const TextStyle(fontSize: 12)),
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
        const SizedBox(height: 10),
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
                decoration: InputDecoration(
                  hintText: 'Describe your wallpaper…',
                  filled: true,
                  fillColor: theme.hintColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'New idea',
              onPressed: loading ? null : _shufflePrompt,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenerateButton(bool canUseAi, bool loading, int coinBalance) {
    final int cost = _selectedQualityTier.coinCost;
    final String label;
    if (loading) {
      label = 'Crafting your wallpaper…';
    } else if (coinBalance >= cost) {
      label = 'Generate  ·  $cost coins';
    } else {
      label = 'Watch Ad to Earn Coins';
    }

    final bool enabled = canUseAi && !loading;

    return Container(
      decoration: BoxDecoration(
        gradient: enabled ? const LinearGradient(colors: <Color>[Color(0xFF7C4DFF), Color(0xFF311B92)]) : null,
        color: enabled ? null : Theme.of(context).hintColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            shadowColor: Colors.transparent,
          ),
          onPressed: enabled ? () => _generate() : null,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                )
              : const Icon(Icons.auto_awesome_rounded, size: 18),
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
    if (_history.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Text('Recent', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _history.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final item = _history[index];
              final bool isSelected = item.id == _latest?.id;
              return GestureDetector(
                onTap: () => setState(() => _latest = item),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.5,
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected ? Border.all(color: const Color(0xFF7C4DFF), width: 2) : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        item.displayUrl(isPremium: app_state.prismUser.premium),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black26),
                      ),
                    ),
                  ),
                ),
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
    final int coinBalance = CoinsService.instance.balanceNotifier.value;
    final AiGenerationRecord? current = _latest;
    final bool canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: canPop,
        title: const Text('Generate'),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Rollout gating notice
                if (!canUseAi)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      app_state.aiEnabled
                          ? "AI generation is rolling out (${app_state.aiRolloutPercent}%). You'll get access soon!"
                          : 'AI generation is currently disabled.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                // Result area
                _buildResultArea(current, _loadingGeneration),
                const SizedBox(height: 12),

                // Action row (only when result is available)
                if (current != null) ...<Widget>[_buildActionRow(current), const SizedBox(height: 16)],

                // Style picker
                _buildStylePicker(),
                const SizedBox(height: 16),

                // Quality selector
                _buildQualitySelector(),

                // Prompt area
                _buildPromptArea(_loadingGeneration),
                const SizedBox(height: 16),

                // Generate button
                _buildGenerateButton(canUseAi, _loadingGeneration, coinBalance),

                // History strip
                _buildHistoryStrip(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
