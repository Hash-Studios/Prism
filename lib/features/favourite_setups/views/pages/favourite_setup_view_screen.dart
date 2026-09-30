import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/setups/views/widgets/setup_detail_view.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class FavSetupViewScreen extends StatelessWidget {
  const FavSetupViewScreen({super.key, required this.setupIndex});

  final int setupIndex;

  @override
  Widget build(BuildContext context) {
    return SetupDetailView(
      setup: context.favouriteSetupsAdapter(listen: false).items![setupIndex],
      closeOnFavouriteToggle: true,
    );
  }
}
