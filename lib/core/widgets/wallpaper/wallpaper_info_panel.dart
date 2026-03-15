import 'dart:ui';

import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class WallpaperInfoPanel extends StatelessWidget {
  const WallpaperInfoPanel({
    super.key,
    required this.entity,
    required this.panelCollapsed,
    required this.accent,
    required this.colors,
    required this.onCollapseTap,
    required this.viewsFuture,
    this.fixedHeight = false,
  });

  final WallpaperDetailEntity entity;
  final bool panelCollapsed;
  final Color? accent;
  final List<Color?>? colors;
  final VoidCallback onCollapseTap;
  final Future<String>? viewsFuture;
  final bool fixedHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      height: MediaQuery.of(context).size.height * .43,
      width: MediaQuery.of(context).size.width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 750),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: panelCollapsed
                  ? Theme.of(context).primaryColor.withValues(alpha: 1)
                  : Theme.of(context).primaryColor.withValues(alpha: .5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCollapseHandle(context),
                _buildColorBar(context),
                Expanded(flex: 8, child: SingleChildScrollView(child: _buildInfoContent(context))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseHandle(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: AnimatedOpacity(
          duration: Duration.zero,
          opacity: panelCollapsed ? 0.0 : 1.0,
          child: GestureDetector(
            onTap: onCollapseTap,
            child: Icon(JamIcons.chevron_down, color: Theme.of(context).colorScheme.secondary),
          ),
        ),
      ),
    );
  }

  Widget _buildColorBar(BuildContext context) {
    final circleSize = 64.0 * 0.7.clamp(32.0, 56.0);
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(colors == null ? 5 : colors!.length, (index) {
          return Container(
            decoration: BoxDecoration(
              color: colors == null ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : colors![index],
              shape: BoxShape.circle,
            ),
            height: circleSize,
            width: circleSize,
          );
        }),
      ),
    );
  }

  Widget _buildInfoContent(BuildContext context) {
    return entity.when(
      prism: (wallpaper) => _buildPrismInfo(context, wallpaper),
      wallhaven: (wallpaper) => _buildWallhavenInfo(context, wallpaper),
      pexels: (wallpaper) => _buildPexelsInfo(context, wallpaper),
    );
  }

  Widget _buildPrismInfo(BuildContext context, PrismWallpaper wallpaper) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildLeftColumn(context, wallpaper), _buildRightColumn(context, wallpaper)],
      ),
    );
  }

  Widget _buildLeftColumn(BuildContext context, PrismWallpaper wallpaper) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.36,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                Text(
                  wallpaper.id.toUpperCase(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.secondary, fontSize: 16),
                ),
                if (viewsFuture != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Container(height: 20, color: Theme.of(context).colorScheme.secondary, width: 2),
                  ),
                  FutureBuilder(
                    future: viewsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                        return Text(
                          "${snapshot.data} views",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.secondary, fontSize: 16),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        if (wallpaper.collections?.isNotEmpty == true)
          _buildInfoRow(context, JamIcons.folder, wallpaper.collections!.take(2).join(', ')),
        if (wallpaper.core.category != null) _buildInfoRow(context, JamIcons.unordered_list, wallpaper.core.category!),
        if (wallpaper.core.resolution != null) _buildInfoRow(context, JamIcons.set_square, wallpaper.core.resolution!),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context, PrismWallpaper wallpaper) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (wallpaper.core.authorName != null)
          _buildInfoRow(context, JamIcons.user, wallpaper.core.authorName!, reversed: true),
        if (wallpaper.core.createdAt != null)
          _buildInfoRow(context, JamIcons.calendar, _formatDate(wallpaper.core.createdAt!), reversed: true),
        _buildInfoRow(context, JamIcons.database, 'Prism', reversed: true),
      ],
    );
  }

  Widget _buildWallhavenInfo(BuildContext context, WallhavenWallpaper wallpaper) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoTitle(context, wallpaper.id.toUpperCase()),
              const SizedBox(height: 5),
              if (wallpaper.views != null) _buildInfoRow(context, JamIcons.eye, wallpaper.views.toString()),
              const SizedBox(height: 5),
              if (wallpaper.core.favourites != null)
                _buildInfoRow(context, JamIcons.heart_f, wallpaper.core.favourites.toString()),
              const SizedBox(height: 5),
              if (wallpaper.sizeBytes != null)
                _buildInfoRow(
                  context,
                  JamIcons.save,
                  "${(_parseSize(wallpaper.sizeBytes ?? wallpaper.core.sizeBytes) / 1000000).toStringAsFixed(2)} MB",
                ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (wallpaper.core.category != null)
                _buildInfoRow(
                  context,
                  JamIcons.unordered_list,
                  wallpaper.core.category!,
                  reversed: true,
                  showIconLast: true,
                ),
              const SizedBox(height: 5),
              if (wallpaper.core.resolution != null)
                _buildInfoRow(
                  context,
                  JamIcons.set_square,
                  wallpaper.core.resolution!,
                  reversed: true,
                  showIconLast: true,
                ),
              const SizedBox(height: 5),
              _buildInfoRow(context, JamIcons.database, 'Wallhaven', reversed: true, showIconLast: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPexelsInfo(BuildContext context, PexelsWallpaper wallpaper) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoTitle(context, wallpaper.id),
              const SizedBox(height: 5),
              _buildInfoRow(context, JamIcons.info, wallpaper.id),
              const SizedBox(height: 5),
              if (wallpaper.core.width != null && wallpaper.core.height != null)
                _buildInfoRow(context, JamIcons.set_square, "${wallpaper.core.width}x${wallpaper.core.height}"),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (wallpaper.photographer != null)
                SizedBox(
                  width: 160,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          JamIcons.camera,
                          size: 20,
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            wallpaper.photographer!,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 5),
              _buildInfoRow(context, JamIcons.database, 'Pexels', reversed: true, showIconLast: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String text, {
    bool reversed = false,
    bool showIconLast = false,
  }) {
    final iconWidget = Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7));
    final textWidget = Flexible(
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
    const spacer = SizedBox(width: 10);

    if (showIconLast) {
      return Row(mainAxisSize: MainAxisSize.min, children: [textWidget, spacer, iconWidget]);
    }
    if (reversed) {
      return Row(mainAxisSize: MainAxisSize.min, children: [textWidget, spacer, iconWidget]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [iconWidget, spacer, textWidget]);
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  double _parseSize(int? size) {
    return (size ?? 0).toDouble();
  }
}
