import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:flutter/material.dart';

/// Opens the request sheet. Returns the request made or upvoted, or null when the user closed the sheet.
Future<WallRequest?> showWallRequestSheet(
  BuildContext context, {
  required WallRequestSourceValue source,
  String initialText = '',
}) async => null;
