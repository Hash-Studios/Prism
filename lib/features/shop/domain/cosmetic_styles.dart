import 'package:Prism/core/widgets/glint/glint_data.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';

/// A profile picture ring: a gradient of [colors] drawn [width] points wide.
class FrameStyle {
  const FrameStyle({required this.colors, required this.width});

  final List<Color> colors;
  final double width;
}

/// A name colour: [colors] run left to right across the text and the first one glows.
class NameGlowStyle {
  const NameGlowStyle({required this.colors});

  final List<Color> colors;
}

const Color _teal = Color(0xFF2FD6C4);
const Color _violet = Color(0xFF8A5CF6);
const Color _goldLight = Color(0xFFFFD76A);
const Color _goldDark = Color(0xFFB8860B);
const Color _black = Color(0xFF0B0B0F);
const Color _orange = Color(0xFFFF8A3D);
const Color _pink = Color(0xFFFF4D8D);
const Color _blue = Color(0xFF3D8BFF);

/// [accent] colours `frame_ring`, so pass the accent of the active theme. An unknown id gets the ring.
FrameStyle frameStyle(String id, {Color accent = const Color(prismDefaultAccentValue)}) => switch (id) {
  'frame_aurora' => const FrameStyle(colors: <Color>[_teal, _violet], width: 3),
  'frame_prism' => FrameStyle(colors: <Color>[...glintRingNodeColors, glintRingNodeColors.first], width: 3),
  'frame_gold' => const FrameStyle(colors: <Color>[_goldLight, _goldDark, _goldLight], width: 3),
  'frame_founders' => const FrameStyle(colors: <Color>[_black, _goldDark, _goldLight], width: 3.5),
  _ => FrameStyle(colors: <Color>[accent, accent], width: 2.5),
};

NameGlowStyle glowStyle(String id) => switch (id) {
  'glow_ocean' => const NameGlowStyle(colors: <Color>[_blue, _teal]),
  'glow_aurora' => const NameGlowStyle(colors: <Color>[_teal, _violet]),
  'glow_prism' => const NameGlowStyle(colors: glintRingNodeColors),
  'glow_founders' => const NameGlowStyle(colors: <Color>[_goldLight, _goldDark]),
  _ => const NameGlowStyle(colors: <Color>[_orange, _pink]),
};

/// Two colours for the app icon preview tile.
List<Color> appIconColors(String id) => switch (id) {
  'icon_noir' => const <Color>[Color(0xFF16161B), Color(0xFF3A3A44)],
  'icon_glass' => const <Color>[Color(0xFFBFD8F5), Color(0xFFF4F8FF)],
  'icon_sunset' => const <Color>[Color(0xFFFF7E5F), Color(0xFFFEB47B)],
  _ => const <Color>[Color(0xFF8A8A92), Color(0xFFD6D6DB)],
};
