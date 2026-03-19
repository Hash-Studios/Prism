import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/profile_setups/domain/entities/profile_setups_page.dart';
import 'package:Prism/features/profile_setups/domain/repositories/profile_setups_repository.dart';
import 'package:injectable/injectable.dart';

class FetchProfileSetupsParams {
  const FetchProfileSetupsParams({required this.email, required this.refresh});

  final String email;
  final bool refresh;
}

@lazySingleton
class FetchProfileSetupsUseCase implements UseCase<ProfileSetupsPage, FetchProfileSetupsParams> {
  FetchProfileSetupsUseCase(this._repository);

  final ProfileSetupsRepository _repository;

  @override
  Future<Result<ProfileSetupsPage>> call(FetchProfileSetupsParams params) {
    return _repository.fetchProfileSetups(email: params.email, refresh: params.refresh);
  }
}
