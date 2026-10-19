import 'package:Prism/l10n/l10n.dart';

/// Turns the stable content-report reason value into a label for the active locale.
String adminReviewReportReasonLabel(String wireValue, AppLocalizations l10n) =>
    switch (wireValue.trim().toLowerCase()) {
      'copyright' => l10n.coreReportReasonCopyright,
      'harassment' => l10n.coreReportReasonHarassment,
      'sexual' => l10n.coreReportReasonSexual,
      'spam' => l10n.coreReportReasonSpam,
      'other' => l10n.coreReportReasonOther,
      _ => l10n.coreReportReasonOther,
    };

/// Turns a content-report target value into a label for the active locale.
String adminReviewContentTypeLabel(String wireValue, AppLocalizations l10n) => switch (wireValue.trim().toLowerCase()) {
  'user' => l10n.coreContentReportUser,
  'wall' || 'setup' => l10n.coreContentReportWallpaper,
  _ => l10n.notifReportUnknownContentType,
};
