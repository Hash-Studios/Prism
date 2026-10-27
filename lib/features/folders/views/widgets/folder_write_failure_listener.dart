import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter_bloc/flutter_bloc.dart';

class FolderWriteFailureListener extends BlocListener<FoldersBloc, FoldersState> {
  FolderWriteFailureListener({super.key, super.child})
    : super(
        listenWhen: (previous, current) =>
            current.queuedWriteFailure != null && current.queuedWriteFailure != previous.queuedWriteFailure,
        listener: (context, state) => toasts.error(context.l10n.foldersSaveFailed),
      );
}
