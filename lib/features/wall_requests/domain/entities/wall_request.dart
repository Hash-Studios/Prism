/// The browse categories and the mood ids a request may carry. Must match REQUEST_CATEGORIES and REQUEST_MOODS in
/// functions/src/wallRequests.ts.
const List<String> wallRequestCategoryTags = <String>[
  'AI Art',
  'Aesthetic',
  'Cyberpunk',
  '3D Render',
  'Gradient',
  'Minimal',
  'Dark',
  'Nature',
  'Landscape',
  'Space',
  'Anime',
  'Neon',
  'Abstract',
  'Architecture',
  'Ocean',
  'Forest',
  'Galaxy',
  'Vintage',
  'Flowers',
  'Cars',
  'AMOLED',
];
const List<String> wallRequestMoodTags = <String>['dreamy', 'dark_quiet', 'bright_bold'];
const int wallRequestMinLength = 3;
const int wallRequestMaxLength = 80;
const int wallRequestMaxTags = 3;

enum WallRequestStatus { open, filled }

enum WallRequestFiller { creator, studio }

enum WallRequestTab {
  top('top'),
  newest('new'),
  filled('filled');

  const WallRequestTab(this.wire);

  final String wire;

  static WallRequestTab fromWire(String? value) =>
      WallRequestTab.values.firstWhere((WallRequestTab tab) => tab.wire == value, orElse: () => WallRequestTab.top);
}

/// One request as `listWallRequests` returns it. The requester is only a display name and an avatar.
class WallRequest {
  const WallRequest({
    required this.id,
    required this.text,
    required this.tags,
    required this.voteCount,
    required this.status,
    required this.createdAt,
    required this.requesterName,
    required this.requesterPhoto,
    required this.mine,
    required this.voted,
    required this.hidden,
    this.filledWallId = '',
    this.filledWallThumb = '',
    this.filledBy,
    this.filledAt,
  });

  factory WallRequest.fromMap(Map<String, Object?> map) {
    String text(String key) => map[key] is String ? map[key]! as String : '';
    int number(String key) => map[key] is num ? (map[key]! as num).toInt() : 0;
    DateTime? time(String key) => number(key) > 0 ? DateTime.fromMillisecondsSinceEpoch(number(key)) : null;
    final Object? tags = map['tags'];
    return WallRequest(
      id: text('id'),
      text: text('text'),
      tags: tags is List ? tags.whereType<String>().toList(growable: false) : const <String>[],
      voteCount: number('voteCount'),
      status: map['status'] == 'filled' ? WallRequestStatus.filled : WallRequestStatus.open,
      createdAt: time('createdAtMs') ?? DateTime.fromMillisecondsSinceEpoch(0),
      requesterName: text('requesterName'),
      requesterPhoto: text('requesterPhoto'),
      mine: map['mine'] == true,
      voted: map['voted'] == true,
      hidden: map['hidden'] == true,
      filledWallId: text('filledWallId'),
      filledWallThumb: text('filledWallThumb'),
      filledBy: switch (map['filledBy']) {
        'creator' => WallRequestFiller.creator,
        'studio' => WallRequestFiller.studio,
        _ => null,
      },
      filledAt: time('filledAtMs'),
    );
  }

  final String id;
  final String text;
  final List<String> tags;
  final int voteCount;
  final WallRequestStatus status;
  final DateTime createdAt;
  final String requesterName;
  final String requesterPhoto;
  final bool mine;
  final bool voted;
  final bool hidden;
  final String filledWallId;
  final String filledWallThumb;
  final WallRequestFiller? filledBy;
  final DateTime? filledAt;

  bool get isFilled => status == WallRequestStatus.filled;

  /// Only another user's open, visible request takes a vote.
  bool get canVote => !mine && !isFilled && !hidden;

  WallRequest copyWith({bool? voted, int? voteCount, bool? hidden}) => WallRequest(
    id: id,
    text: text,
    tags: tags,
    voteCount: voteCount ?? this.voteCount,
    status: status,
    createdAt: createdAt,
    requesterName: requesterName,
    requesterPhoto: requesterPhoto,
    mine: mine,
    voted: voted ?? this.voted,
    hidden: hidden ?? this.hidden,
    filledWallId: filledWallId,
    filledWallThumb: filledWallThumb,
    filledBy: filledBy,
    filledAt: filledAt,
  );
}

/// What `createWallRequest` did: made the request, or found a close open one to upvote instead.
sealed class CreateWallRequestResult {
  const CreateWallRequestResult(this.request);

  final WallRequest request;
}

final class WallRequestCreated extends CreateWallRequestResult {
  const WallRequestCreated(super.request);
}

final class WallRequestDuplicate extends CreateWallRequestResult {
  const WallRequestDuplicate(super.request, {required this.exact});

  /// Same words as an open request. The app then offers no "Request mine anyway".
  final bool exact;
}

/// Server errors the app has copy for. The callables send these codes as the error message.
enum WallRequestError { textRejected, dailyLimit, ownRequest, closed, missing, signedOut, unknown }

class WallRequestException implements Exception {
  const WallRequestException(this.error);

  final WallRequestError error;

  @override
  String toString() => 'WallRequestException($error)';
}
