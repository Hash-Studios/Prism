import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Medium-like editorial note: typographic hierarchy, thin accent rule, no heavy card chrome.
class PersonalizedFeedEditorialNote extends StatelessWidget {
  const PersonalizedFeedEditorialNote({super.key, required this.title, this.detail, this.accentColor});

  final String title;
  final String? detail;

  /// Vertical rule; defaults to [ColorScheme.outline].
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? Theme.of(context).colorScheme.outline;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PrismEditorialNote.maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismEditorialNote.horizontalPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: PrismEditorialNote.accentBarWidth,
                height: PrismEditorialNote.accentBarHeight,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(PrismEditorialNote.accentBarBorderRadius),
                ),
              ),
              const SizedBox(width: PrismEditorialNote.accentBarTextGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PrismTextStyles.editorialTitle(context)),
                    if (detail != null && detail!.isNotEmpty) ...[
                      const SizedBox(height: PrismEditorialNote.titleDetailSpacing),
                      Text(detail!, style: PrismTextStyles.editorialDetail(context)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty / footer message for the personalized feed (editorial shell).
class PersonalizedEmptyCard extends StatelessWidget {
  const PersonalizedEmptyCard({super.key, required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return PersonalizedFeedEditorialNote(title: title, detail: detail);
  }
}
