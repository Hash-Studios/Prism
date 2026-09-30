import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The search field of the wallpaper and creator search pages: a 48 point pill with a search icon, and a clear button
/// once there is text. Clearing calls [onChanged] with an empty string.
class PrismSearchField extends StatefulWidget {
  const PrismSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<PrismSearchField> createState() => _PrismSearchFieldState();
}

class _PrismSearchFieldState extends State<PrismSearchField> {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle text = PrismTextStyles.rowTitle(context).copyWith(fontSize: 16);
    return ListenableBuilder(
      listenable: _focus,
      builder: (context, child) => AnimatedContainer(
        duration: context.motion(PrismDurations.fast),
        curve: PrismCurves.enter,
        height: 48,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          border: Border.all(color: _focus.hasFocus ? cs.primary : cs.onSurface.withValues(alpha: 0.08)),
        ),
        child: child,
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: PrismSpace.md),
          Icon(Icons.search_rounded, size: 22, color: cs.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: PrismSpace.xs),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              cursorColor: cs.primary,
              style: text,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: widget.hint,
                hintStyle: text.copyWith(color: cs.onSurface.withValues(alpha: 0.45)),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: PrismSpace.md)
                : PrismIconButton(icon: Icons.close_rounded, tooltip: 'Clear search', iconSize: 20, onPressed: _clear),
          ),
        ],
      ),
    );
  }
}
