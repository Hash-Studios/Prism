import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/typography.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ArAvatar extends StatelessWidget {
  const ArAvatar({super.key, this.imageUrl, this.initials, this.size = 48});

  final String? imageUrl;
  final String? initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ArsenalColors.accent, width: 1.5),
        color: ArsenalColors.surface,
      ),
      child: ClipOval(
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _Fallback(initials: initials, size: size),
              )
            : _Fallback(initials: initials, size: size),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.initials, required this.size});

  final String? initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: ArsenalColors.surface,
      alignment: Alignment.center,
      child: initials != null
          ? Text(initials!.toUpperCase(), style: ArsenalTypography.labelEmphasis.copyWith(color: ArsenalColors.accent))
          : const Icon(Icons.person, color: ArsenalColors.muted, size: 20),
    );
  }
}
