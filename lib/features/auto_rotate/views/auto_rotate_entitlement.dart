import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';

/// Auto-rotate runs for a signed-in Pro user and while a 7-day auto-rotate pass is active.
bool autoRotateEntitled(SessionEntity session) =>
    session.loggedIn && (session.premium || CoinsService.instance.currentPasses.autoRotatePassActive(DateTime.now()));

/// When the pass that allows auto-rotate ends. Null for Pro users and when no pass is active.
DateTime? autoRotatePassEnd(SessionEntity session) {
  if (!session.loggedIn || session.premium) return null;
  final Passes passes = CoinsService.instance.currentPasses;
  return passes.autoRotatePassActive(DateTime.now()) ? passes.autoRotatePassUntil : null;
}
