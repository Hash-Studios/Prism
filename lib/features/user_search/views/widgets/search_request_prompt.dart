import 'dart:async';

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// A quiet row under a few search results: asks for the wall the user did not find, with a request action.
class SearchRequestPrompt extends StatelessWidget {
  const SearchRequestPrompt({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: PrismSpace.pageInsets,
      child: Row(
        children: <Widget>[
          Expanded(child: Text(context.l10n.searchRequestPrompt, style: PrismTextStyles.caption(context))),
          TextButton(
            onPressed: () =>
                unawaited(showWallRequestSheet(context, source: WallRequestSourceValue.search, initialText: query)),
            child: Text(context.l10n.searchRequestAction),
          ),
        ],
      ),
    );
  }
}
