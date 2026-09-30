import 'package:flutter/material.dart';

/// Black or white, whichever reads on top of [background].
Color onColor(Color background) => background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
