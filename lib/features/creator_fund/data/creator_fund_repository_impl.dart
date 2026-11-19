import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_repository.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_status.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: CreatorFundRepository)
class CreatorFundRepositoryImpl implements CreatorFundRepository {
  @override
  Future<CreatorFundStatus> load() async => parseCreatorFundStatus(
    (await appFunctions.httpsCallable('getCreatorFundStatus').call<Object?>(<String, Object?>{})).data,
  );
}

T _read<T>(Object? value) {
  if (value is T) return value;
  throw const FormatException('Malformed creator fund status');
}

Map<String, Object?> _map(Object? value) {
  final map = _read<Map<Object?, Object?>>(value);
  if (map.keys.any((key) => key is! String)) throw const FormatException('Invalid creator fund keys');
  return map.map((key, value) => MapEntry(key! as String, value));
}

int _count(Object? value) => switch (value) {
  final int count when count >= 0 => count,
  _ => throw const FormatException('Invalid creator fund count'),
};

int _shareBps(Object? value) => switch (value) {
  final int bps when bps >= 0 && bps <= 10000 => bps,
  _ => throw const FormatException('Invalid creator fund share'),
};

CreatorFundReason _reason(Object? value) => switch (value) {
  'noActivity' => CreatorFundReason.noActivity,
  'fewUsers' => CreatorFundReason.fewUsers,
  'smallShare' => CreatorFundReason.smallShare,
  'moderation' => CreatorFundReason.moderation,
  'team' => CreatorFundReason.team,
  _ => throw const FormatException('Invalid creator fund reason'),
};

CreatorFundStatus parseCreatorFundStatus(Object? raw) {
  final m = _map(raw);
  if (m['schemaVersion'] != 1) throw const FormatException('Unsupported creator fund status');
  final week = _read<String>(m['week']);
  final state = _read<String>(m['state']);
  final distinctUsers = _count(m['distinctUsers']);
  final minDistinctUsers = _count(m['minDistinctUsers']);
  final minPayout = _count(m['minPayout']);
  return switch (state) {
    'off' => CreatorFundOff(week: week),
    'pending' => CreatorFundPending(week: week),
    'paid' => CreatorFundPaid(week: week, coins: _count(m['coins']), shareBps: _shareBps(m['shareBps'])),
    'notQualified' => CreatorFundNotQualified(
      week: week,
      reason: _reason(m['reason']),
      distinctUsers: distinctUsers,
      minDistinctUsers: minDistinctUsers,
      minPayout: minPayout,
      shareBps: m['shareBps'] == null ? null : _shareBps(m['shareBps']),
    ),
    _ => throw const FormatException('Unknown creator fund state'),
  };
}
