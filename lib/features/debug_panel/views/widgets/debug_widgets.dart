import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String _monospaceFamily = 'monospace';

/// Caption text in the platform monospace family. Log lines, keys and ids read better in it.
TextStyle debugMono(BuildContext context, {double size = 12, double alpha = 1}) {
  final TextStyle caption = PrismTextStyles.caption(context);
  return caption.copyWith(
    fontFamily: _monospaceFamily,
    fontSize: size,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: alpha),
  );
}

/// Shows a short message in the app toast. Errors stay on screen longer.
void showDebugSnackBar(BuildContext context, String message, {bool isError = false}) {
  isError ? toasts.error(message) : toasts.success(message);
}

void copyToClipboard(BuildContext context, String text, {String label = 'Copied'}) {
  Clipboard.setData(ClipboardData(text: text));
  showDebugSnackBar(context, label);
}

/// A search field with a search icon and a clear button that shows once there is text.
class DebugSearchField extends StatelessWidget {
  const DebugSearchField({super.key, required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => PrismTextField(
        controller: controller,
        hint: hintText,
        prefixIcon: Icons.search_rounded,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        suffix: controller.text.isEmpty
            ? null
            : PrismIconButton(icon: Icons.close_rounded, tooltip: 'Clear search', onPressed: controller.clear),
      ),
    );
  }
}
