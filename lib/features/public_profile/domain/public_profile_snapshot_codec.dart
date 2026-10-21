import 'dart:convert';

import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';

typedef PublicProfileSnapshotWall = ({WallDocDto doc, String? documentId});

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

  static Map<String, Object?> encodeWalls(Iterable<PublicProfileSnapshotWall> items, {required bool hasMore}) {
    final List<PublicProfileSnapshotWall> walls = items.toList(growable: false);
    return <String, Object?>{
      'itemsJson': jsonEncode(walls.map((wall) => wall.doc.toJson()).toList(growable: false)),
      'documentIdsJson': jsonEncode(walls.map((wall) => wall.documentId).toList(growable: false)),
      'hasMore': hasMore,
    };
  }

  static List<PublicProfileSnapshotWall> decodeWalls(Map<String, Object?> record) {
    final List<WallDocDto> docs = (jsonDecode(record['itemsJson']! as String) as List<Object?>)
        .map((value) => WallDocDto.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList(growable: false);
    final String? documentIdsJson = record['documentIdsJson'] as String?;
    final List<Object?> documentIds = documentIdsJson == null
        ? const <Object?>[]
        : jsonDecode(documentIdsJson) as List<Object?>;
    return <PublicProfileSnapshotWall>[
      for (int i = 0; i < docs.length; i++)
        (doc: docs[i], documentId: documentIds.length == docs.length ? documentIds[i] as String? : null),
    ];
  }

  static PublicProfileWallEntity wallFromDto(WallDocDto dto, String id, {String? firestoreDocumentId}) =>
      PublicProfileWallEntity(
        id: dto.id.isNotEmpty ? dto.id : id,
        firestoreDocumentId: firestoreDocumentId,
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
