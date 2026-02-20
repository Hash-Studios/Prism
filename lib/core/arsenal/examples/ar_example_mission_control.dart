import 'package:Prism/core/arsenal/arsenal.dart';
import 'package:flutter/material.dart';

/// Command-centre operations dashboard — showcases ArScaffold, ArAppBar (with
/// bottom chip row), ArBottomNav, ArAvatar, ArTag, ArProgressSteps, and
/// ArButton.ghost in a realistic mission-control layout.
class ArExampleMissionControl extends StatelessWidget {
  const ArExampleMissionControl({super.key});

  @override
  Widget build(BuildContext context) {
    final navItems = [
      ArNavItem(icon: Icons.radar_outlined, label: 'Ops', onTap: () {}),
      ArNavItem(icon: Icons.hub_outlined, label: 'Network', onTap: () {}),
      ArNavItem(icon: Icons.upload_outlined, label: 'Deploy', onTap: () {}),
      ArNavItem(icon: Icons.person_outline, label: 'Agent', onTap: () {}),
    ];

    return ArScaffold(
      padding: EdgeInsets.zero,
      appBar: const ArAppBar(
        title: 'Operations',
        showBackButton: false,
        action: ArTag(label: 'Live', color: ArsenalColors.accent),
        bottom: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: ArsenalSpacing.md, vertical: ArsenalSpacing.sm),
          child: Row(
            children: [
              ArChip(label: 'All', selected: true),
              SizedBox(width: ArsenalSpacing.sm),
              ArChip(label: 'Active'),
              SizedBox(width: ArsenalSpacing.sm),
              ArChip(label: 'Completed'),
              SizedBox(width: ArsenalSpacing.sm),
              ArChip(label: 'Failed'),
            ],
          ),
        ),
      ),
      navBar: ArBottomNav(items: navItems, activeIndex: 0),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ArsenalSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: ArsenalSpacing.sm),

            // ── Summary header ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ArsenalSpacing.md),
              color: ArsenalColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ACTIVE MISSIONS', style: ArsenalTypography.mono.copyWith(color: ArsenalColors.muted)),
                        const SizedBox(height: ArsenalSpacing.xs),
                        Text('7', style: ArsenalTypography.hero.copyWith(color: ArsenalColors.accent)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 48, color: ArsenalColors.border),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: ArsenalSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SUCCESS RATE', style: ArsenalTypography.mono.copyWith(color: ArsenalColors.muted)),
                          const SizedBox(height: ArsenalSpacing.xs),
                          Text('94%', style: ArsenalTypography.hero),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ArsenalSpacing.lg),

            // ── Recent operations ──────────────────────────────────────────
            Text('RECENT OPERATIONS', style: ArsenalTypography.subheadingMedium),
            const SizedBox(height: ArsenalSpacing.sm),
            const _MissionCard(
              codename: 'GHOST PROTOCOL',
              agent: 'NX',
              status: 'In Progress',
              statusColor: ArsenalColors.accent,
              description: 'Infiltrate node cluster 9-Alpha. Extract firmware keys.',
              totalSteps: 4,
              currentStep: 2,
            ),
            const SizedBox(height: ArsenalSpacing.sm),
            const _MissionCard(
              codename: 'IRON VEIL',
              agent: 'RZ',
              status: 'Queued',
              statusColor: Color(0xFF00BCD4),
              description: 'Deploy counter-surveillance net across sectors 4-7.',
              totalSteps: 3,
              currentStep: 0,
            ),
            const SizedBox(height: ArsenalSpacing.sm),
            const _MissionCard(
              codename: 'RED SPARK',
              agent: 'AK',
              status: 'Critical',
              statusColor: ArsenalColors.error,
              description: 'Emergency patch for compromised relay station.',
              totalSteps: 5,
              currentStep: 3,
            ),
            const SizedBox(height: ArsenalSpacing.md),
            Center(child: ArButton.ghost(label: 'View All Operations')),
            const SizedBox(height: ArsenalSpacing.md),
          ],
        ),
      ),
    );
  }
}

// ── Private helper ──────────────────────────────────────────────────────────

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.codename,
    required this.agent,
    required this.status,
    required this.statusColor,
    required this.description,
    required this.totalSteps,
    required this.currentStep,
  });

  final String codename;
  final String agent;
  final String status;
  final Color statusColor;
  final String description;
  final int totalSteps;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ArsenalColors.surface,
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      padding: const EdgeInsets.all(ArsenalSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ArAvatar(initials: agent, size: ArsenalSpacing.avatarSm),
              const SizedBox(width: ArsenalSpacing.sm),
              Expanded(child: Text(codename, style: ArsenalTypography.subheadingMedium)),
              ArTag(label: status, color: statusColor),
            ],
          ),
          const SizedBox(height: ArsenalSpacing.sm),
          Text(description, style: ArsenalTypography.bodySmall.copyWith(color: ArsenalColors.muted)),
          const SizedBox(height: ArsenalSpacing.sm),
          ArProgressSteps(total: totalSteps, current: currentStep),
        ],
      ),
    );
  }
}
