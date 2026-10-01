part of 'badges_bloc.dart';

enum BadgesStatus { initial, loading, success, failure }

class BadgesState extends Equatable {
  const BadgesState({this.status = BadgesStatus.initial, this.earnedIds = const <String>[]});

  final BadgesStatus status;
  final List<String> earnedIds;

  BadgesState copyWith({BadgesStatus? status, List<String>? earnedIds}) =>
      BadgesState(status: status ?? this.status, earnedIds: earnedIds ?? this.earnedIds);

  @override
  List<Object?> get props => <Object?>[status, earnedIds];
}
