import 'package:Prism/data/apps/app_icon.dart';
import 'package:Prism/data/apps/apps_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

Future<void> showSetupIconPicker(BuildContext context, {required ValueChanged<AppIcon> onPicked}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
    ),
    builder: (context) => GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: ColoredBox(
        color: const Color.fromRGBO(0, 0, 0, 0.001),
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.4,
            builder: (context, controller) => _IconPickerSheet(controller: controller, onPicked: onPicked),
          ),
        ),
      ),
    ),
  );
}

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({required this.controller, required this.onPicked});

  final ScrollController controller;
  final ValueChanged<AppIcon> onPicked;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  List<AppIcon> _allIcons = <AppIcon>[];
  List<AppIcon> _icons = <AppIcon>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    getIcons().then((value) {
      if (!mounted) return;
      setState(() {
        _icons = value;
        _allIcons = value;
        _loading = false;
      });
    });
  }

  void _filter(String query) {
    final String q = query.toLowerCase();
    setState(() {
      _icons = q.isEmpty ? _allIcons : _allIcons.where((e) => e.name.trim().toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              width: 32,
              height: 6,
              decoration: BoxDecoration(
                color: theme.textTheme.bodyLarge!.color!.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5000),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: _filter,
                    style: theme.textTheme.bodyLarge!.copyWith(fontSize: 16),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: "Search Icons",
                      hintStyle: theme.textTheme.bodyLarge!.copyWith(
                        fontSize: 16,
                        color: theme.textTheme.bodyLarge!.color!.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 1 - 119,
                  child: ListView.separated(
                    separatorBuilder: (context, index) => const Divider(height: 2),
                    shrinkWrap: true,
                    controller: widget.controller,
                    itemCount: _icons.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _icons.length) return const ListTile(title: SizedBox(height: 60));
                      final AppIcon icon = _icons[index];
                      return ListTile(
                        onTap: () {
                          widget.onPicked(icon);
                          Navigator.pop(context);
                        },
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(imageUrl: icon.iconUrl, width: 38, height: 38, fit: BoxFit.cover),
                        ),
                        title: Text(
                          icon.name.trim(),
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontSize: 16,
                            fontFamily: "Proxima Nova",
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          icon.id.trim(),
                          style: TextStyle(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontFamily: "Proxima Nova",
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
