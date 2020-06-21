import 'package:Prism/data/wallhaven/model/tag.dart';

class WallPaper {
  final String id;
  final String url;
  final String short_url;
  final String views;
  final String favorites;
  final String category;
  final String dimension_x;
  final String dimension_y;
  final String resolution;
  final String file_size;
  final List<String> colors;
  final String path;
  final Map<String, String> thumbs;
  final List<Tag> tags;
  final int current_page;
  WallPaper({
    this.id,
    this.url,
    this.short_url,
    this.views,
    this.favorites,
    this.category,
    this.dimension_x,
    this.dimension_y,
    this.resolution,
    this.file_size,
    this.colors,
    this.path,
    this.thumbs,
    this.tags,
    this.current_page,
  });
}
