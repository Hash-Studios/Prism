import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/setups/domain/entities/setups_page.dart';
import 'package:Prism/features/setups/domain/repositories/setups_repository.dart';
import 'package:injectable/injectable.dart';

class FetchSetupsParams {
  const FetchSetupsParams({required this.refresh});

  final bool refresh;
}

@lazySingleton
class FetchSetupsUseCase implements UseCase<SetupsPage, FetchSetupsParams> {
  FetchSetupsUseCase(this._repository);

  final SetupsRepository _repository;

  @override
  Future<Result<SetupsPage>> call(FetchSetupsParams params) {
    return _repository.fetchSetups(refresh: params.refresh);
  }
}
