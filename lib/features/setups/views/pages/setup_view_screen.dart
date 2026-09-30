import 'package:Prism/features/setups/views/setups_bloc_adapter.dart';
import 'package:Prism/features/setups/views/widgets/setup_detail_view.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class SetupViewScreen extends StatelessWidget {
  const SetupViewScreen({super.key, required this.setupIndex});

  final int setupIndex;

  @override
  Widget build(BuildContext context) {
    return SetupDetailView(setup: context.setupsAdapter(listen: false).setups![setupIndex]);
  }
}
