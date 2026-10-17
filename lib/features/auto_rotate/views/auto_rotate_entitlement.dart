import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';

/// Auto-rotate runs for a signed-in Pro user and while a 7-day auto-rotate pass is active.
bool autoRotateEntitled(SessionEntity session) =>
    session.loggedIn &&
    (session.premium || CoinsService.instance.passesNotifier.value.autoRotatePassActive(DateTime.now()));
