import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class InterestCategoryTile extends StatelessWidget {
  const InterestCategoryTile({
    super.key,
    required this.name,
    required this.isSelected,
    required this.onTap,
    this.imageUrl,
  });

  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primary : Colors.transparent, width: 2.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: const Color(0xFF2A2A2A)),
                    errorWidget: (_, __, ___) => Container(color: const Color(0xFF2A2A2A)),
                  )
                else
                  Container(color: const Color(0xFF2A2A2A)),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
                if (isSelected) Container(color: primary.withValues(alpha: 0.25)),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
