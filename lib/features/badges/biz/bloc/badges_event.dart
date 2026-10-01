part of 'badges_bloc.dart';

sealed class BadgesEvent {
  const BadgesEvent();
}

/// Ask the server for new badges, then show the owned list.
class BadgesLoaded extends BadgesEvent {
  const BadgesLoaded();
}
