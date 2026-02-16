import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/profile_walls/domain/entities/profile_walls_page.dart';
import 'package:Prism/features/profile_walls/domain/repositories/profile_walls_repository.dart';
import 'package:injectable/injectable.dart';

class FetchProfileWallsParams {
  const FetchProfileWallsParams({required this.email, required this.refresh});

  final String email;
  final bool refresh;
}

@lazySingleton
class FetchProfileWallsUseCase
    implements UseCase<ProfileWallsPage, FetchProfileWallsParams> {
  FetchProfileWallsUseCase(this._repository);

  final ProfileWallsRepository _repository;

  @override
  Future<Result<ProfileWallsPage>> call(FetchProfileWallsParams params) {
    return _repository.fetchProfileWalls(
        email: params.email, refresh: params.refresh);
  }
}
