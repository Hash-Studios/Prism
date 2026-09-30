import 'package:Prism/core/widgets/animated/show_up.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class SetupDetailsTile extends StatelessWidget {
  final bool panelCollapsed;
  final Duration delay;
  final String tileType;
  final String tileText;
  final VoidCallback onTap;
  const SetupDetailsTile({
    super.key,
    required this.delay,
    required this.tileText,
    required this.tileType,
    required this.onTap,
    required this.panelCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    final Color secondary = Theme.of(context).colorScheme.secondary;
    return panelCollapsed
        ? Container()
        : ShowUpTransition(
            forward: true,
            delay: delay,
            slideSide: SlideFromSlide.bottom,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 80,
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: -55,
                        left: 0,
                        child: Text(
                          tileType,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontSize: 140,
                            color: secondary.withValues(alpha: 0.1),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: secondary.withValues(alpha: 0.1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 10,
                                child: Text(
                                  tileText,
                                  overflow: TextOverflow.fade,
                                  style: TextStyle(color: secondary),
                                ),
                              ),
                              Expanded(child: Icon(JamIcons.chevron_right, color: secondary)),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              splashColor: secondary.withValues(alpha: 0.3),
                              highlightColor: secondary.withValues(alpha: 0.1),
                              onTap: onTap,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}
