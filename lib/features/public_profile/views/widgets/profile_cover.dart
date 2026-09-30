import 'dart:io';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The cover art of a profile: a picked [file], the user's image at [url], or the default rings in theme colours.
/// It fills its parent.
class ProfileCover extends StatelessWidget {
  const ProfileCover({super.key, this.url, this.file});

  final String? url;
  final File? file;

  /// True when [url] points at a real image, so a custom cover can be shown or removed.
  static bool hasCover(String? url) => Uri.tryParse(url?.trim() ?? '')?.hasAuthority ?? false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget art = SvgPicture.string(
      defaultHeader
          .replaceAll('#181818', '#${cs.surfaceContainerHigh.rgbHex}')
          .replaceAll('#E77597', '#${cs.primary.rgbHex}'),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
    if (file != null) return Image.file(file!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    if (!hasCover(url)) return art;
    return CachedNetworkImage(
      imageUrl: url!.trim(),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: context.motion(PrismDurations.fast),
      placeholder: (_, _) => art,
      errorWidget: (_, _, _) => art,
    );
  }
}
