import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/typography.dart';
import 'package:flutter/material.dart';

class ArNavItem {
  const ArNavItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class ArBottomNav extends StatelessWidget {
  const ArBottomNav({super.key, required this.items, required this.activeIndex});

  final List<ArNavItem> items;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: ArsenalColors.border),
        ColoredBox(
          color: ArsenalColors.background,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (int i = 0; i < items.length; i++)
                    Expanded(
                      child: _ArNavItemWidget(item: items[i], isActive: i == activeIndex),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArNavItemWidget extends StatelessWidget {
  const _ArNavItemWidget({required this.item, required this.isActive});

  final ArNavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? ArsenalColors.accent : ArsenalColors.muted;
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(item.label.toUpperCase(), style: ArsenalTypography.label.copyWith(color: color)),
        ],
      ),
    );
  }
}
