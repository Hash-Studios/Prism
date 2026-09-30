import 'dart:io';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class EditButton extends StatefulWidget {
  final String? url;
  const EditButton({required this.url, super.key});

  @override
  _EditButtonState createState() => _EditButtonState();
}

class _EditButtonState extends State<EditButton> {
  late bool isLoading;

  @override
  void initState() {
    isLoading = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CircularMenuButton(
      label: 'Edit',
      onTap: () {
        if (!isLoading) {
          onEdit(widget.url);
        }
      },
      isLoading: isLoading,
      child: Icon(JamIcons.pencil, color: Theme.of(context).colorScheme.secondary, size: 20),
    );
  }

  Future<void> onEdit(String? url) async {
    if (url == null) {
      toasts.error('No wallpaper URL available');
      return;
    }
    setState(() {
      isLoading = true;
    });
    toasts.success('Loading Wallpaper');
    Directory? sessionDirectory;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        toasts.error('Could not load wallpaper for editing');
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }
      if (!mounted) return;
      final editDir = Directory('${(await getTemporaryDirectory()).path}/prism_edit');
      await editDir.create(recursive: true);
      sessionDirectory = await editDir.createTemp('source_');
      final file = File('${sessionDirectory.path}/source.img');
      await file.writeAsBytes(response.bodyBytes);
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      await context.router.push(WallpaperFilterRoute(filePath: file.path));
    } catch (_) {
      if (mounted) {
        toasts.error('Could not load wallpaper for editing');
      }
    } finally {
      try {
        await sessionDirectory?.delete(recursive: true);
      } catch (_) {}
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
