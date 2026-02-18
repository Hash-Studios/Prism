import 'dart:io';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as WallStore;
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AiWallpaperTabPage extends StatefulWidget {
  const AiWallpaperTabPage({super.key});

  @override
  State<AiWallpaperTabPage> createState() => _AiWallpaperTabPageState();
}

class _AiWallpaperTabPageState extends State<AiWallpaperTabPage> {
  final AiGenerationRepositoryImpl _repository = AiGenerationRepositoryImpl();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _variationController = TextEditingController();
  final FocusNode _promptFocus = FocusNode();

  AiStylePreset _selectedStyle = AiStylePreset.abstract;
  AiQualityTier _selectedQuality = AiQualityTier.balanced;
  List<AiGenerationRecord> _history = <AiGenerationRecord>[];
  AiGenerationRecord? _latest;

  bool _loadingHistory = false;
  bool _loadingGeneration = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _variationController.dispose();
    _promptFocus.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => globals.prismUser.loggedIn && globals.prismUser.id.trim().isNotEmpty;

  bool get _isRolloutEligible {
    if (!globals.aiEnabled) {
      return false;
    }
    final int percent = globals.aiRolloutPercent.clamp(0, 100);
    if (percent >= 100) {
      return true;
    }
    if (!_isLoggedIn) {
      return false;
    }
    final int hash = globals.prismUser.id.codeUnits.fold<int>(0, (prev, unit) => (prev + unit) % 100);
    return hash < percent;
  }

  String _targetSizeForDevice(BuildContext context) {
    final media = MediaQuery.of(context);
    final double dpr = media.devicePixelRatio.clamp(1.0, 3.0);
    final int width = (media.size.width * dpr).round().clamp(720, 2048);
    final int height = (media.size.height * dpr).round().clamp(1280, 2048);
    return '${width}x$height';
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
      final result = await _repository.fetchHistory(userId: globals.prismUser.id);
      setState(() {
        _history = result;
        _latest = result.isEmpty ? null : result.first;
      });
      analytics.logEvent(name: 'ai_history_opened', parameters: <String, Object>{'count': result.length});
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
    if (variation && (_latest == null || !globals.aiVariationsEnabled)) {
      toasts.error('Variation is not available right now.');
      return;
    }

    setState(() => _loadingGeneration = true);

    final reservation = await CoinsService.instance.reserveForAiGeneration(sourceTag: 'coins.reserve.ai_screen');
    if (!reservation.success || reservation.mode == AiChargeMode.insufficient) {
      CoinsService.instance.logLowBalanceNudge(
        sourceTag: 'coins.ai_generation.low_balance',
        requiredCoins: CoinPolicy.aiGeneration,
      );
      toasts.error('Need ${CoinPolicy.aiGeneration} coins or Pro to generate.');
      setState(() => _loadingGeneration = false);
      return;
    }

    analytics.logEvent(
      name: 'ai_generate_started',
      parameters: <String, Object>{
        'style': _selectedStyle.apiValue,
        'quality': _selectedQuality.apiValue,
        'mode': reservation.mode.value,
      },
    );

    try {
      final AiGenerationRecord generated = variation
          ? await _repository.generateVariation(
              generationId: _latest!.id,
              chargeMode: reservation.mode,
              coinsSpent: reservation.coinsSpent,
              variationPrompt: prompt,
              strength: 0.45,
            )
          : await _repository.generate(
              prompt: prompt,
              stylePreset: _selectedStyle,
              qualityTier: _selectedQuality,
              targetSize: _targetSizeForDevice(context),
              chargeMode: reservation.mode,
              coinsSpent: reservation.coinsSpent,
            );

      CoinsService.instance.commitAiGenerationReservation(
        mode: reservation.mode,
        coinsSpent: reservation.coinsSpent,
        sourceTag: 'coins.commit.ai_screen',
      );

      setState(() {
        _latest = generated;
        _history = <AiGenerationRecord>[generated, ..._history.where((item) => item.id != generated.id)];
      });

      analytics.logEvent(
        name: variation ? 'ai_variation_used' : 'ai_generate_success',
        parameters: <String, Object>{
          'provider': generated.provider,
          'mode': reservation.mode.value,
          'coinsSpent': reservation.coinsSpent,
        },
      );
      if (variation) {
        _variationController.clear();
      }
    } catch (error) {
      await CoinsService.instance.rollbackAiGenerationReservation(
        reservation.mode,
        sourceTag: 'coins.rollback.ai_screen',
      );
      analytics.logEvent(
        name: 'ai_generate_failed',
        parameters: <String, Object>{'error': error.toString(), 'mode': reservation.mode.value},
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
      final file = await _downloadToTempFile(record.displayUrl(isPremium: globals.prismUser.premium));
      if (!mounted) return;
      context.router.push(DownloadWallpaperRoute(arguments: <dynamic>['Prism', file]));
    } catch (_) {
      toasts.error('Unable to prepare wallpaper file.');
    }
  }

  Future<void> _share(AiGenerationRecord record) async {
    final link = record.displayUrl(isPremium: globals.prismUser.premium);
    await Share.share(link, subject: 'Made with Prism AI');
    analytics.logEvent(name: 'ai_share_tapped', parameters: <String, Object>{'generationId': record.id});
  }

  Future<void> _save(AiGenerationRecord record) async {
    try {
      final file = await _downloadToTempFile(record.displayUrl(isPremium: globals.prismUser.premium));
      await Share.shareXFiles(<XFile>[XFile(file.path)], text: 'Generated with Prism AI');
      toasts.codeSend('Use the share sheet to save this wallpaper.');
    } catch (_) {
      toasts.error('Unable to prepare image for saving.');
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
    if (!globals.aiSubmitEnabled) {
      toasts.error('AI submit is currently disabled.');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    analytics.logEvent(name: 'ai_submit_started', parameters: <String, Object>{'generationId': record.id});
    try {
      final metadata = await _repository.prefillSubmissionMetadata(generationId: record.id);
      final edited = await _showSubmissionEditor(metadata);
      if (edited == null) {
        return;
      }

      final String communityId = _buildCommunityId(record.id);
      await WallStore.createRecord(
        communityId,
        'Prism',
        record.imageUrl,
        record.imageUrl,
        '${record.width}x${record.height}',
        'AI',
        edited['title']?.toString(),
        edited['category']?.toString(),
        edited['description']?.toString(),
        false,
        wallpaperTags: ((edited['tags'] as List<dynamic>? ?? <dynamic>[]).map((tag) => tag.toString()).toList()),
        isAiGenerated: true,
        aiGenerationId: record.id,
        aiProvider: record.provider,
        aiModel: record.model,
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
      analytics.logEvent(name: 'ai_submit_success', parameters: <String, Object>{'generationId': record.id});
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

  Future<Map<String, dynamic>?> _showSubmissionEditor(Map<String, dynamic> metadata) async {
    final titleController = TextEditingController(text: (metadata['title'] ?? '').toString());
    final descController = TextEditingController(text: (metadata['description'] ?? '').toString());
    final categoryController = TextEditingController(text: (metadata['category'] ?? 'General').toString());
    final tags = metadata['tags'] is List
        ? (metadata['tags'] as List<dynamic>)
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];
    final tagsController = TextEditingController(text: tags.join(', '));
    Map<String, dynamic>? output;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit AI Wallpaper'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(labelText: 'Tags (comma-separated)'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final desc = descController.text.trim();
              final category = categoryController.text.trim();
              final tags = tagsController.text
                  .split(',')
                  .map((tag) => tag.trim().toLowerCase())
                  .where((tag) => tag.isNotEmpty)
                  .toSet()
                  .toList();
              if (title.isEmpty || desc.isEmpty || category.isEmpty) {
                toasts.error('Please complete all fields.');
                return;
              }
              output = <String, dynamic>{'title': title, 'description': desc, 'category': category, 'tags': tags};
              Navigator.of(context).pop();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    titleController.dispose();
    descController.dispose();
    categoryController.dispose();
    tagsController.dispose();
    return output;
  }

  @override
  Widget build(BuildContext context) {
    final canUseAi = _isRolloutEligible;
    final current = _latest;
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('AI Wallpapers'),
        actions: <Widget>[
          if (_isLoggedIn)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: CoinBalanceChip(sourceTag: 'coins.chip.ai_tab')),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              if (!canUseAi)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      globals.aiEnabled
                          ? 'AI generation is rolling out (${globals.aiRolloutPercent}%).'
                          : 'AI generation is currently disabled.',
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Describe your wallpaper'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _promptController,
                        focusNode: _promptFocus,
                        minLines: 2,
                        maxLines: 4,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: 'A minimalist mountain wallpaper with sunrise glow and soft fog...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AiStylePreset.values.map((style) {
                          final selected = style == _selectedStyle;
                          return ChoiceChip(
                            label: Text(style.label),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedStyle = style),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AiQualityTier>(
                        value: _selectedQuality,
                        decoration: const InputDecoration(labelText: 'Quality'),
                        items: AiQualityTier.values
                            .map((tier) => DropdownMenuItem(value: tier, child: Text(tier.label)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedQuality = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: canUseAi && !_loadingGeneration ? () => _generate() : null,
                          icon: _loadingGeneration
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_awesome),
                          label: Text(_loadingGeneration ? 'Generating...' : 'Generate Wallpaper'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'New users: first 3 free. Then ${CoinPolicy.aiGeneration} coins per generation. Pro includes 30/day.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (current != null) ...<Widget>[
                Text('Latest Result', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Image.network(
                      current.displayUrl(isPremium: globals.prismUser.premium),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _loadingGeneration || !globals.aiVariationsEnabled
                          ? null
                          : () => _generate(variation: true),
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Variation'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _save(current),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Save'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _share(current),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _setWallpaper(current),
                      icon: const Icon(Icons.wallpaper_outlined),
                      label: const Text('Set'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _submitting || !globals.aiSubmitEnabled ? null : () => _submitToCommunity(current),
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(_submitting ? 'Submitting...' : 'Submit'),
                    ),
                  ],
                ),
                if (globals.aiVariationsEnabled) ...<Widget>[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _variationController,
                    decoration: const InputDecoration(
                      hintText: 'Variation prompt (optional): darker background, more neon...',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
              Text('History', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_loadingHistory)
                const Center(
                  child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                )
              else if (_history.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No generations yet. Your history will appear here.'),
                  ),
                )
              else
                ..._history.map(
                  (item) => Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 42,
                          height: 72,
                          child: Image.network(
                            item.displayUrl(isPremium: globals.prismUser.premium),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
                          ),
                        ),
                      ),
                      title: Text(item.stylePreset.label),
                      subtitle: Text(item.prompt, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(item.chargeMode.value),
                      onTap: () => setState(() => _latest = item),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
