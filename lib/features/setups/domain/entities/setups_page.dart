import 'package:Prism/features/setups/domain/entities/setup_entity.dart';

class SetupsPage {
  const SetupsPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<SetupEntity> items;
  final bool hasMore;
  final String? nextCursor;
}
