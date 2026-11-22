import 'package:Prism/features/coin_packs/data/coin_pack_gateway.dart';
import 'package:flutter/widgets.dart';

/// Placeholder. The real sheet replaces this file.
class CoinPacksSheet extends StatelessWidget {
  const CoinPacksSheet({super.key, required this.source, required this.gateway, this.message});

  final String source;
  final String? message;
  final CoinPackGateway gateway;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
