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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = accentColor ?? scheme.outline;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.45);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 52,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    if (detail != null && detail!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(detail!, style: detailStyle),
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
