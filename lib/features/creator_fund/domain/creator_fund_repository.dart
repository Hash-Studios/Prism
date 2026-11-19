import 'package:Prism/features/creator_fund/domain/creator_fund_status.dart';

abstract class CreatorFundRepository {
  Future<CreatorFundStatus> load();
}
