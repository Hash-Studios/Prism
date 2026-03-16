import 'package:flutter/material.dart';

class PrismCoinIcon extends StatelessWidget {
  const PrismCoinIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset('assets/images/prism_coin.png', width: size, height: size);
}
