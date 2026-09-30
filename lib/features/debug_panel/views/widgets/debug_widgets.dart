import 'package:Prism/logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

extension AppLogLevelColor on AppLogLevel {
  Color get color => switch (this) {
    AppLogLevel.debug => Colors.blueGrey,
    AppLogLevel.info => Colors.green,
    AppLogLevel.warn => Colors.orange,
    AppLogLevel.error => Colors.red,
  };
}

void showDebugSnackBar(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: duration));
}

void copyToClipboard(
  BuildContext context,
  String text, {
  String label = 'Copied',
  Duration duration = const Duration(seconds: 1),
}) {
  Clipboard.setData(ClipboardData(text: text));
  showDebugSnackBar(context, label, duration: duration);
}

class DebugSectionHeader extends StatelessWidget {
  const DebugSectionHeader(this.title, {super.key, this.top = 20});

  final String title;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class DebugSearchField extends StatelessWidget {
  const DebugSearchField({super.key, required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: controller.clear)
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
