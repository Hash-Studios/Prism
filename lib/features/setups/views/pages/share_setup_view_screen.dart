import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/not_found_page.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/domain/usecases/setups_usecases.dart';
import 'package:Prism/features/setups/views/widgets/setup_detail_view.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ShareSetupViewScreen extends StatefulWidget {
  const ShareSetupViewScreen({super.key, @PathParam('setupName') required this.setupName});

  final String setupName;

  @override
  State<ShareSetupViewScreen> createState() => _ShareSetupViewScreenState();
}

class _ShareSetupViewScreenState extends State<ShareSetupViewScreen> {
  late final Future<Result<SetupEntity?>> _future = getIt<FetchSetupByNameUseCase>()(widget.setupName);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<SetupEntity?>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Theme.of(context).primaryColor,
            body: Center(child: Loader()),
          );
        }
        final SetupEntity? setup = snapshot.data?.data;
        if (setup == null) {
          return const NotFoundPage();
        }
        return SetupDetailView(setup: setup, sharedLink: true);
      },
    );
  }
}
