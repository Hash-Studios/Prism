import 'package:flutter/material.dart';

/// The user's accent colour. Same as `Theme.of(context).colorScheme.primary`; kept for older call sites.
Color accentColor(BuildContext context) => Theme.of(context).colorScheme.primary;
