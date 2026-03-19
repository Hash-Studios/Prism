import 'package:Prism/features/category_feed/views/pages/collection_screen.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class CollectionTabPage extends StatelessWidget {
  const CollectionTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CollectionScreen();
  }
}
