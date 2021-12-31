import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:prism/controllers/palette_generator_controller.dart';
import 'package:prism/model/setup/setup_model.dart';
import 'package:prism/services/logger.dart';
import 'package:provider/provider.dart';
import 'package:prism/utils/color_utils.dart';

class SetupCard extends StatelessWidget {
  const SetupCard({
    Key? key,
    required this.snapshot,
    required this.index,
  }) : super(key: key);

  final AsyncSnapshot<List<Setup>> snapshot;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () {
            logger.d('Tapped on ${snapshot.data?[index].image}');
          },
          child: ChangeNotifierProvider<PaletteGeneratorController>(
            create: (_) =>
                PaletteGeneratorController(snapshot.data?[index].image ?? ''),
            child: Consumer<PaletteGeneratorController>(
              builder: (context, pgc, child) => Container(
                height: 296,
                color: pgc.paletteGenerator?.dominantColor?.color.invert
                        .darken20 ??
                    Theme.of(context).primaryColor.withOpacity(0.2),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: CachedNetworkImage(
                          imageUrl: snapshot.data?[index].image ?? "",
                          imageBuilder: (context, imageProvider) => Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: pgc.paletteGenerator?.dominantColor
                                        ?.color.invert ??
                                    Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.2),
                                width: 4,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image(
                                image: imageProvider,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
