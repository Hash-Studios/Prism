import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Filled accent pill with an icon and a label, used for the main action on the wallpaper detail screen.
class PrimaryActionPill extends StatelessWidget {
  const PrimaryActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.isLoading,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final Color background = Theme.of(context).colorScheme.error;
    final Color foreground = onColor(background);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: background, shape: const StadiumBorder()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 20,
                width: 20,
                child: isLoading
                    ? CircularProgressIndicator(strokeWidth: 2, color: foreground)
                    : Icon(icon, color: foreground, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontFamily: PrismFonts.proximaNova,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
