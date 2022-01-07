import 'package:flutter/material.dart';
import 'package:prism/model/setup/setup_model.dart';
import 'package:prism/model/setup/setup_upload_state.dart';
import 'package:prism/model/wallhaven/wallhaven_search_state.dart';
import 'package:prism/services/locator.dart';
import 'package:prism/services/setup_service.dart';

class SetupController extends ChangeNotifier {
  final SetupService _setupService = locator<SetupService>();

  Stream<List<Setup>> get setupSearchStream => _setupService.setupSearchStream;
  List<Setup>? get setupSearch => _setupService.setupSearchStream.valueOrNull;
  Stream<SearchState> get searchStateStream => _setupService.searchStateStream;
  SearchState? get searchState => _setupService.searchStateStream.valueOrNull;

  Stream<SetupUploadState> get setupUploadStateStream =>
      _setupService.setupUploadStateStream;
  SetupUploadState? get setupUploadState =>
      _setupService.setupUploadStateStream.valueOrNull;

  Future<void> getSearchResults() async {
    await _setupService.getSearchResults();
    notifyListeners();
  }

  Future<void> clearSearchResults() async {
    await _setupService.clearSearchResults();
    notifyListeners();
  }

  Future<void> getMoreSearchResults() async {
    await _setupService.getMoreSearchResults();
    notifyListeners();
  }

  Future<Setup?> getSetupFromName(String name) async {
    return await _setupService.getSetupFromName(name);
  }

  Future<void> uploadSetup(Setup _setup) async {
    await _setupService.uploadSetup(_setup);
    notifyListeners();
  }

  Future<void> editSetup(String setupDocId, Setup _setup) async {
    await _setupService.editSetup(setupDocId, _setup);
    notifyListeners();
  }

  Future<void> draftSetup(Setup _setup) async {
    await _setupService.draftSetup(_setup);
    notifyListeners();
  }

  Future<void> deleteSetup(String setupDocId) async {
    await _setupService.deleteSetup(setupDocId);
    notifyListeners();
  }
}
