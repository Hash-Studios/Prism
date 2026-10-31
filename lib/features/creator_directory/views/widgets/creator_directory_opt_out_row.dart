import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// Settings switch that lists the signed-in viewer in the creator directory. Off writes `creatorDirectoryOptOut`.
class CreatorDirectoryOptOutRow extends StatefulWidget {
  const CreatorDirectoryOptOutRow({super.key});

  @override
  State<CreatorDirectoryOptOutRow> createState() => _CreatorDirectoryOptOutRowState();
}

class _CreatorDirectoryOptOutRowState extends State<CreatorDirectoryOptOutRow> {
  final String _uid = app_state.prismUser.id;
  bool _optOut = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bool? optOut = await getIt<FirestoreClient>().getById(
        FirebaseCollections.usersV2,
        _uid,
        (data, _) => data['creatorDirectoryOptOut'] == true,
        sourceTag: 'creator_directory.opt_out.read',
      );
      if (!mounted) return;
      setState(() {
        _optOut = optOut ?? false;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _set(bool show) async {
    final bool previous = _optOut;
    setState(() => _optOut = !show);
    try {
      await getIt<FirestoreClient>().updateDoc(FirebaseCollections.usersV2, _uid, <String, dynamic>{
        'creatorDirectoryOptOut': !show,
      }, sourceTag: 'creator_directory.opt_out.write');
    } catch (_) {
      if (!mounted) return;
      setState(() => _optOut = previous);
      toasts.error(context.l10n.coreSomethingWentWrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismSwitchRow(
      icon: Icons.person_search_rounded,
      title: context.l10n.creatorsShowMeTitle,
      subtitle: context.l10n.creatorsShowMeBody,
      value: !_optOut,
      onChanged: _loaded ? (bool show) => _set(show) : null,
    );
  }
}
