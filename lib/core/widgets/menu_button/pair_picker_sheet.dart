import 'dart:io';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The tab a lock screen wall came from. The name goes into the `set_wall_pair` event.
enum PairSource { favourites, downloads, history }

/// One wall in the picker.
class PairCandidate {
  const PairCandidate({required this.fullUrl, required this.thumbnailUrl});

  final String fullUrl;
  final String thumbnailUrl;
}

/// The wall the user picked for the lock screen.
class PairPick {
  const PairPick({required this.source, required this.candidate});

  final PairSource source;
  final PairCandidate candidate;
}

/// Opens the picker with the user's favourites, downloads and history.
Future<PairPick?> showPairPickerSheet(BuildContext context, {String? excludeUrl}) {
  final List<PairCandidate> favourites = _favouriteCandidates(context);
  final List<PairCandidate> history = _historyCandidates();
  return showPrismSheet<PairPick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PairPickerSheet(
      favourites: _without(favourites, excludeUrl),
      history: _without(history, excludeUrl),
      loadDownloads: () async => _without(await _downloadCandidates(), excludeUrl),
    ),
  );
}

List<PairCandidate> _without(List<PairCandidate> items, String? url) =>
    url == null ? items : items.where((item) => item.fullUrl != url).toList(growable: false);

List<PairCandidate> _favouriteCandidates(BuildContext context) {
  try {
    return context
        .read<FavouriteWallsBloc>()
        .state
        .items
        .map((wall) => PairCandidate(fullUrl: wall.fullUrl, thumbnailUrl: wall.thumbnailUrl))
        .where((item) => item.fullUrl.isNotEmpty)
        .toList(growable: false);
  } catch (error) {
    logger.w('Pair picker: no favourites available', error: error);
    return const <PairCandidate>[];
  }
}

List<PairCandidate> _historyCandidates() {
  try {
    final Set<String> seen = <String>{};
    return WallpaperHistoryStore.instance
        .items()
        .where((item) => seen.add(item.fullUrl))
        .map((item) => PairCandidate(fullUrl: item.fullUrl, thumbnailUrl: item.thumbnailUrl))
        .toList(growable: false);
  } catch (error) {
    logger.w('Pair picker: no history available', error: error);
    return const <PairCandidate>[];
  }
}

Future<List<PairCandidate>> _downloadCandidates() async {
  try {
    final DownloadItemsResult result = await PrismMediaHostApi().listDownloads();
    if (!result.success) return const <PairCandidate>[];
    return result.items
        .where((path) => File(path).existsSync())
        .map((path) => PairCandidate(fullUrl: path, thumbnailUrl: path))
        .toList(growable: false);
  } catch (error) {
    logger.w('Pair picker: could not list downloads', error: error);
    return const <PairCandidate>[];
  }
}

/// Tabs of walls to choose the lock screen wall from. A tap on a wall closes the sheet with that pick.
class PairPickerSheet extends StatelessWidget {
  const PairPickerSheet({super.key, required this.favourites, required this.history, required this.loadDownloads});

  final List<PairCandidate> favourites;
  final List<PairCandidate> history;
  final Future<List<PairCandidate>> Function() loadDownloads;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: DefaultTabController(
        length: PairSource.values.length,
        child: Column(
          children: <Widget>[
            Text('Pick a lock screen wallpaper', style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            const TabBar(
              tabs: <Widget>[
                Tab(text: 'Favourites'),
                Tab(text: 'Downloads'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _PairGrid(
                    source: PairSource.favourites,
                    load: () async => favourites,
                    emptyText: 'No favourites yet.',
                  ),
                  _PairGrid(source: PairSource.downloads, load: loadDownloads, emptyText: 'No downloads yet.'),
                  _PairGrid(source: PairSource.history, load: () async => history, emptyText: 'No history yet.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairGrid extends StatelessWidget {
  const _PairGrid({required this.source, required this.load, required this.emptyText});

  final PairSource source;
  final Future<List<PairCandidate>> Function() load;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<PairCandidate>>(
      future: load(),
      builder: (context, snapshot) {
        final List<PairCandidate>? items = snapshot.data;
        if (items == null) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (items.isEmpty) {
          return Center(
            child: Text(emptyText, style: TextStyle(color: scheme.secondary)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.56,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final PairCandidate item = items[index];
            return Semantics(
              button: true,
              label: 'Use this wallpaper for the lock screen',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(PairPick(source: source, candidate: item)),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _Thumbnail(item.thumbnailUrl)),
              ),
            );
          },
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest);
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        cacheManager: PrismImageCache.instance,
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 300,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      );
    }
    return Image.file(File(url), fit: BoxFit.cover, cacheWidth: 300, errorBuilder: (_, _, _) => placeholder);
  }
}
