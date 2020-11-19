import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class CollapsedPanel extends StatelessWidget {
  final bool panelCollapsed;
  final PanelController panelController;
  const CollapsedPanel({
    Key key,
    this.panelCollapsed,
    @required this.panelController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 750),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        color: panelCollapsed
            ? Theme.of(context).primaryColor.withOpacity(1)
            : Theme.of(context).primaryColor.withOpacity(0),
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 30,
        child: Center(
            child: AnimatedOpacity(
          duration: const Duration(),
          opacity: panelCollapsed ? 1.0 : 0.0,
          child: IconButton(
            icon: Icon(
              JamIcons.chevron_up,
              color: Theme.of(context).accentColor,
            ),
            onPressed: () {
              panelController.open();
            },
          ),
        )),
      ),
    );
  }
}
