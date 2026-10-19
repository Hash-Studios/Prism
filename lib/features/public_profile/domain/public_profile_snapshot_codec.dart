import 'dart:convert';

import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';

class PublicProfileSnapshotCodec {
  const PublicProfileSnapshotCodec._();

  static Map<String, Object?> encodeSummaries(Iterable<UserSummaryEntity> items, {required bool hasMore}) =>
      <String, Object?>{
        'itemsJson': jsonEncode(
          items
              .map(
                (item) => <String, Object?>{
                  'id': item.id,
                  'email': item.email,
                  'name': item.name,
                  'username': item.username,
                  'profilePhoto': item.profilePhoto,
                  'isFollowedByCurrentUser': item.isFollowedByCurrentUser,
                },
              )
              .toList(growable: false),
        ),
        'hasMore': hasMore,
      };

  static List<UserSummaryEntity> decodeSummaries(Map<String, Object?> record) =>
      (jsonDecode(record['itemsJson']! as String) as List<Object?>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .map(
            (item) => UserSummaryEntity(
              id: item['id'] as String,
              email: item['email'] as String,
              name: item['name'] as String,
              username: item['username'] as String,
              profilePhoto: item['profilePhoto'] as String,
              isFollowedByCurrentUser: item['isFollowedByCurrentUser'] as bool,
            ),
          )
          .toList(growable: false);

  static Map<String, Object?> encodeWalls(Iterable<WallDocDto> items, {required bool hasMore}) => <String, Object?>{
    'itemsJson': jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    'hasMore': hasMore,
  };

  static List<WallDocDto> decodeWalls(Map<String, Object?> record) =>
      (jsonDecode(record['itemsJson']! as String) as List<Object?>)
          .map((value) => WallDocDto.fromJson(Map<String, dynamic>.from(value as Map)))
          .toList(growable: false);

  static PublicProfileWallEntity wallFromDto(WallDocDto dto, String id) => PublicProfileWallEntity(
    id: dto.id.isNotEmpty ? dto.id : id,
    by: dto.by,
    desc: dto.desc,
    size: dto.size,
    resolution: dto.resolution,
    email: dto.email,
    source: WallpaperSourceX.fromWire(dto.wallpaperProvider),
    wallpaperThumb: dto.wallpaperThumb,
    wallpaperUrl: dto.wallpaperUrl,
    collections: dto.collections,
    createdAt: dto.createdAt,
    review: dto.review,
    depthTier: WallDepthTier.parse(dto.depth['tier']),
  );
}
