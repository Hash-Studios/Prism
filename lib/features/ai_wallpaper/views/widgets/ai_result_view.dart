import 'dart:io';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_follow_up.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_wallpaper_helpers.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_history_strip.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_preview_stage.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A finished wallpaper, full-bleed. This session's takes, the follow-up chips and the actions sit over its bottom.
class AiResultView extends StatelessWidget {
  const AiResultView({
    super.key,
    required this.record,
    required this.isPremium,
    required this.session,
    required this.generating,
    required this.showFollowUps,
    required this.followUpCost,
    required this.actions,
    required this.onEditPrompt,
    required this.onSelectTake,
    required this.onFollowUp,
    this.notice,
    this.trailing,
  });

  static const double _takeWidth = 44;
  static const double _takeHeight = 78;

  final AiGenerationRecord record;
  final bool isPremium;

  /// The wallpapers made since the page opened, oldest first.
  final List<AiGenerationRecord> session;

  /// True while a new take is being made. The chips are off and the hero dims.
  final bool generating;
  final bool showFollowUps;
  final int followUpCost;
  final Widget actions;
  final VoidCallback onEditPrompt;
  final ValueChanged<AiGenerationRecord> onSelectTake;
  final ValueChanged<AiFollowUp> onFollowUp;

  /// Shown above the actions, for example a submission that was not confirmed.
  final Widget? notice;

  /// Top end of the screen, for example the coin balance.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Semantics(
              image: true,
              label: l10n.economyAiGeneratedWallpaper,
              child: AiResultHero(url: record.displayUrl(isPremium: isPremium)),
            ),
            const IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0x66000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: generating ? 1 : 0,
                duration: context.motion(PrismDurations.base),
                curve: PrismCurves.enter,
                child: const ColoredBox(color: Color(0x4D000000)),
              ),
            ),
            if (generating)
              Center(
                child: Padding(
                  padding: PrismSpace.pageInsets,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(PrismRadius.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.lg, vertical: PrismSpace.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurface),
                          ),
                          const SizedBox(width: PrismSpace.sm),
                          const Flexible(child: AiGeneratingStatusLine()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.xs, PrismSpace.md, 0),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Row(
                    children: <Widget>[
                      _ImagePill(icon: Icons.edit_rounded, label: l10n.aiResultEditPrompt, onTap: onEditPrompt),
                      const Spacer(),
                      ?trailing,
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (session.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: PrismSpace.sm),
                      child: _SessionStrip(
                        session: session,
                        selectedId: record.id,
                        isPremium: isPremium,
                        onSelect: onSelectTake,
                      ),
                    ),
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: cs.surfaceContainerLow.withValues(alpha: 0.94),
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(PrismRadius.xl)),
                        side: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      minimum: const EdgeInsets.only(bottom: PrismSpace.md),
                      child: Padding(
                        padding: const EdgeInsets.only(top: PrismSpace.md),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (showFollowUps) ...<Widget>[
                              _FollowUpRow(cost: followUpCost, enabled: !generating, onFollowUp: onFollowUp),
                              const SizedBox(height: PrismSpace.sm),
                            ],
                            if (notice != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.sm),
                                child: notice,
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
                              child: actions,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The wallpaper at full size. A new [url] crossfades in only once it is decoded, so a swap never flashes.
class AiResultHero extends StatefulWidget {
  const AiResultHero({super.key, required this.url});

  final String url;

  @override
  State<AiResultHero> createState() => _AiResultHeroState();
}

class _AiResultHeroState extends State<AiResultHero> {
  final Map<String, Future<ImageProvider>> _providers = <String, Future<ImageProvider>>{};
  String? _shownUrl;
  ImageProvider? _shown;
  int _swap = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shownUrl == null) _show(widget.url, precache: false);
  }

  @override
  void didUpdateWidget(covariant AiResultHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _show(widget.url, precache: true);
  }

  Future<ImageProvider> _providerFor(String url, int decodeWidth) => _providers[url] ??= () async {
    File? file;
    try {
      file = await OfflineAssetStore.instance.lookup(url);
    } on Object {
      file = null;
    }
    final ImageProvider base = file != null ? FileImage(file) : CachedNetworkImageProvider(url);
    return ResizeImage.resizeIfNeeded(decodeWidth, null, base);
  }();

  Future<void> _show(String url, {required bool precache}) async {
    final int swap = ++_swap;
    final int decodeWidth = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round().clamp(
      32,
      4096,
    );
    final ImageProvider provider = await _providerFor(url, decodeWidth);
    if (!mounted || swap != _swap) return;
    if (precache) {
      await precacheImage(provider, context, onError: (_, _) {});
      if (!mounted || swap != _swap) return;
    }
    setState(() {
      _shownUrl = url;
      _shown = provider;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ImageProvider? shown = _shown;
    return AnimatedSwitcher(
      duration: context.motion(PrismDurations.base),
      switchInCurve: PrismCurves.enter,
      switchOutCurve: PrismCurves.exit,
      layoutBuilder: (Widget? current, List<Widget> previous) =>
          Stack(fit: StackFit.expand, children: <Widget>[...previous, ?current]),
      child: shown == null
          ? const SizedBox.expand(key: ValueKey<String>('loading'))
          : Image(
              key: ValueKey<String?>(_shownUrl),
              image: shown,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => ColoredBox(
                color: cs.surfaceContainerHighest,
                child: Center(child: Icon(Icons.broken_image_rounded, color: cs.onSurface.withValues(alpha: 0.3))),
              ),
            ),
    );
  }
}

class _SessionStrip extends StatelessWidget {
  const _SessionStrip({
    required this.session,
    required this.selectedId,
    required this.isPremium,
    required this.onSelect,
  });

  final List<AiGenerationRecord> session;
  final String selectedId;
  final bool isPremium;
  final ValueChanged<AiGenerationRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int count = session.length;
    return Semantics(
      container: true,
      label: l10n.aiSessionStripLabel,
      child: SizedBox(
        height: AiResultView._takeHeight,
        child: Center(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: true,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.xs),
            itemBuilder: (_, int reversed) {
              final int index = count - 1 - reversed;
              final AiGenerationRecord take = session[index];
              return AiGenerationThumb(
                key: ValueKey<String>(take.id),
                record: take,
                selected: take.id == selectedId,
                isPremium: isPremium,
                width: AiResultView._takeWidth,
                height: AiResultView._takeHeight,
                semanticLabel: l10n.aiSessionTake(index + 1, count),
                onTap: () => onSelect(take),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow({required this.cost, required this.enabled, required this.onFollowUp});

  final int cost;
  final bool enabled;
  final ValueChanged<AiFollowUp> onFollowUp;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
        children: <Widget>[
          Semantics(
            label: l10n.aiFollowUpCostLabel(cost),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const PrismCoinIcon(size: 16),
                const SizedBox(width: PrismSpace.xxs),
                Text(formatLocalizedNumber(cost, l10n), style: PrismTextStyles.caption(context)),
              ],
            ),
          ),
          for (final AiFollowUp followUp in AiFollowUp.values) ...<Widget>[
            const SizedBox(width: PrismSpace.xs),
            PrismChip(
              key: ValueKey<String>('ai-follow-up-${followUp.name}'),
              label: aiFollowUpLabel(l10n, followUp),
              compact: true,
              onTap: enabled ? () => onFollowUp(followUp) : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled pill that sits on the wallpaper: a dark translucent fill and white text on every theme.
class _ImagePill extends StatelessWidget {
  const _ImagePill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(PrismRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: PrismSpace.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.rowTitle(context).copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
