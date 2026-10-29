import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_picker_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Lets a creator tie the upload to an open wall request. [requestText] is empty when none is picked.
class FillsRequestRow extends StatelessWidget {
  const FillsRequestRow({super.key, required this.requestText, required this.onChanged, this.pick});

  final String requestText;
  final ValueChanged<WallRequest?> onChanged;

  /// Opens the picker. Defaults to [showWallRequestPicker].
  final Future<WallRequest?> Function(BuildContext)? pick;

  @override
  Widget build(BuildContext context) {
    final bool hasRequest = requestText.trim().isNotEmpty;
    return PrismGroup(
      children: <Widget>[
        PrismRow(
          icon: Icons.lightbulb_outline_rounded,
          title: context.l10n.uploadFillsRequest,
          subtitle: hasRequest ? requestText : context.l10n.uploadFillsRequestHint,
          onTap: () async {
            final WallRequest? picked = await (pick ?? showWallRequestPicker)(context);
            if (picked != null) onChanged(picked);
          },
          trailing: hasRequest
              ? IconButton(
                  tooltip: context.l10n.uploadFillsRequestClear,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
      ],
    );
  }
}
