part of 'session_bloc.dart';

@freezed
abstract class SessionEvent with _$SessionEvent {
  const factory SessionEvent.started() = _Started;
  const factory SessionEvent.premiumRefreshRequested() = _PremiumRefreshRequested;
  const factory SessionEvent.signOutRequested() = _SignOutRequested;
}
