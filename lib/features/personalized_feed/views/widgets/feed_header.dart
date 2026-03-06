import 'package:flutter/material.dart';

class PersonalizedFeedHeader extends StatelessWidget {
  const PersonalizedFeedHeader({
    super.key,
    required this.prismCount,
    required this.wallhavenCount,
    required this.pexelsCount,
    required this.itemCount,
    required this.isFetchingMore,
  });

  final int prismCount;
  final int wallhavenCount;
  final int pexelsCount;
  final int itemCount;
  final bool isFetchingMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              secondary.withValues(alpha: 0.18),
              secondary.withValues(alpha: 0.07),
              theme.primaryColor.withValues(alpha: 0.86),
            ],
          ),
          border: Border.all(color: secondary.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 12),
              color: secondary.withValues(alpha: 0.22),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 20, color: secondary),
                const SizedBox(width: 8),
                Text(
                  'FOR YOU',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: secondary,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: isFetchingMore
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: secondary),
                        )
                      : Icon(
                          Icons.tune_rounded,
                          key: const ValueKey('ready'),
                          size: 18,
                          color: secondary.withValues(alpha: 0.86),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$itemCount personalized picks from creators + Wallhaven + Pexels.',
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary.withValues(alpha: 0.92), height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeaderChip(
                  icon: Icons.people_alt_rounded,
                  label: 'Following',
                  value: prismCount,
                  accent: const Color(0xFF4CAF50),
                ),
                _HeaderChip(
                  icon: Icons.landscape_rounded,
                  label: 'Wallhaven',
                  value: wallhavenCount,
                  accent: const Color(0xFF1EA7FD),
                ),
                _HeaderChip(
                  icon: Icons.photo_camera_back_rounded,
                  label: 'Pexels',
                  value: pexelsCount,
                  accent: const Color(0xFFFFA726),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label, required this.value, required this.accent});

  final IconData icon;
  final String label;
  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
