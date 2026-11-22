import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';

enum WallPriceOutcome { saved, removed, ineligible, notOriginal, disabled, failed }

/// Sets, changes or removes (price 0) the price of the user's own wall through `setWallPrice`.
class CreatorWallPrices {
  CreatorWallPrices({Future<Map<String, dynamic>> Function(Map<String, dynamic> input)? call})
    : _call = call ?? _setWallPrice;

  static final CreatorWallPrices instance = CreatorWallPrices();

  final Future<Map<String, dynamic>> Function(Map<String, dynamic> input) _call;

  /// [wallDocId] is the wall document ID. [price] is 0 or one of `EconomyConfig.creatorWallPrices`.
  Future<WallPriceOutcome> setPrice({required String wallDocId, required int price}) async {
    try {
      final Map<String, dynamic> reply = await _call(<String, dynamic>{'wallId': wallDocId, 'price': price});
      final String reason = reply['reason']?.toString() ?? '';
      if (reply['success'] == true) return price == 0 ? WallPriceOutcome.removed : WallPriceOutcome.saved;
      return switch (reason) {
        'creator_wall_disabled' => WallPriceOutcome.disabled,
        'creator_wall_not_original' || 'creator_wall_unavailable' => WallPriceOutcome.notOriginal,
        _ when reason.startsWith('creator_wall_seller_') => WallPriceOutcome.ineligible,
        _ => WallPriceOutcome.failed,
      };
    } on FirebaseFunctionsException catch (error) {
      logger.w('[CreatorWalls] setWallPrice failed: ${error.code}');
      return error.code == 'permission-denied' ? WallPriceOutcome.notOriginal : WallPriceOutcome.failed;
    } catch (error) {
      logger.w('[CreatorWalls] setWallPrice failed: $error');
      return WallPriceOutcome.failed;
    }
  }

  static Future<Map<String, dynamic>> _setWallPrice(Map<String, dynamic> input) async {
    final HttpsCallableResult<Map<String, dynamic>> result = await appFunctions
        .httpsCallable('setWallPrice')
        .call<Map<String, dynamic>>(input);
    return result.data;
  }
}
