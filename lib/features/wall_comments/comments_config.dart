import 'package:Prism/core/startup/firebase_init.dart';
import 'package:flutter/foundation.dart';

/// Remote Config kill switch `comments_enabled`. Missing means on. Off hides the comments button, and the server
/// refuses new comments.
class CommentsConfig {
  CommentsConfig._();

  static const String enabledKey = 'comments_enabled';

  @visibleForTesting
  static bool? override;

  static bool get enabled =>
      override ??
      switch (FirebaseInit.remoteConfigIfInitialized?.getString(enabledKey).trim().toLowerCase()) {
        'false' || '0' => false,
        _ => true,
      };
}
