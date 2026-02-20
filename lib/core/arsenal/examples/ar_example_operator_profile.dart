import 'package:Prism/core/arsenal/arsenal.dart';
import 'package:flutter/material.dart';

/// Cyberpunk operative dossier — showcases ArScaffold, ArAppBar, ArAvatar,
/// ArTag, ArChip, ArProgressSteps, and ArButton in a realistic profile layout.
class ArExampleOperatorProfile extends StatelessWidget {
  const ArExampleOperatorProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return ArScaffold(
      appBar: const ArAppBar(
        title: 'Dossier',
        showBackButton: false,
        action: ArTag(label: 'Online', color: Color(0xFF00E676)),
      ),
      bottomBar: Row(
        children: [
          Expanded(child: ArButton.primary(label: 'Recruit')),
          const SizedBox(width: ArsenalSpacing.sm),
          Expanded(child: ArButton.secondary(label: 'Message')),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: ArsenalSpacing.lg),

            // ── Hero identity ──────────────────────────────────────────────
            const ArAvatar(initials: 'VK', size: ArsenalSpacing.avatarLg),
            const SizedBox(height: ArsenalSpacing.md),
            Text('VECTOR_K', style: ArsenalTypography.displayLarge),
            const SizedBox(height: ArsenalSpacing.xs),
            Text('SIGNAL ARCHITECT // SECTOR 7', style: ArsenalTypography.mono.copyWith(color: ArsenalColors.muted)),
            const SizedBox(height: ArsenalSpacing.md),

            // ── Tags ───────────────────────────────────────────────────────
            const Wrap(
              spacing: ArsenalSpacing.sm,
              runSpacing: ArsenalSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                ArTag(label: 'Level 42'),
                ArTag(label: 'Crypto', color: Color(0xFF00BCD4)),
                ArTag(label: 'Netrunner', color: Color(0xFFFF9800)),
              ],
            ),
            const SizedBox(height: ArsenalSpacing.lg),

            // ── Stats cards ────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text('SYSTEM STATS', style: ArsenalTypography.subheadingMedium),
            ),
            const SizedBox(height: ArsenalSpacing.sm),
            const Row(
              children: [
                Expanded(
                  child: _StatCard(label: 'UPLINK', value: '98.2%'),
                ),
                SizedBox(width: ArsenalSpacing.sm),
                Expanded(
                  child: _StatCard(label: 'OPS', value: '1,247'),
                ),
                SizedBox(width: ArsenalSpacing.sm),
                Expanded(
                  child: _StatCard(label: 'RANK', value: '#003'),
                ),
              ],
            ),
            const SizedBox(height: ArsenalSpacing.lg),

            // ── Clearance progress ─────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text('CLEARANCE PROGRESS', style: ArsenalTypography.subheadingMedium),
            ),
            const SizedBox(height: ArsenalSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ArsenalSpacing.md),
              color: ArsenalColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STEP 3 OF 5', style: ArsenalTypography.monoHighlight.copyWith(color: ArsenalColors.accent)),
                  const SizedBox(height: ArsenalSpacing.sm),
                  const ArProgressSteps(total: 5, current: 2),
                  const SizedBox(height: ArsenalSpacing.sm),
                  Text(
                    'Complete neural-link certification to advance.',
                    style: ArsenalTypography.bodySmall.copyWith(color: ArsenalColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ArsenalSpacing.lg),

            // ── Specializations ────────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text('SPECIALIZATIONS', style: ArsenalTypography.subheadingMedium),
            ),
            const SizedBox(height: ArsenalSpacing.sm),
            const Wrap(
              spacing: ArsenalSpacing.sm,
              runSpacing: ArsenalSpacing.sm,
              children: [
                ArChip(label: 'Encryption', selected: true),
                ArChip(label: 'Surveillance'),
                ArChip(label: 'Neural Ops'),
                ArChip(label: 'Firmware'),
              ],
            ),
            const SizedBox(height: ArsenalSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ── Private helper ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ArsenalSpacing.sm, vertical: ArsenalSpacing.md),
      color: ArsenalColors.surface,
      child: Column(
        children: [
          Text(label, style: ArsenalTypography.mono.copyWith(color: ArsenalColors.muted)),
          const SizedBox(height: ArsenalSpacing.xs),
          Text(value, style: ArsenalTypography.subheadingLarge.copyWith(color: ArsenalColors.accent)),
        ],
      ),
    );
  }
}
