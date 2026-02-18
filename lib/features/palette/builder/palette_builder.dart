import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/palette/biz/bloc/palette_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PaletteBuilder {
  const PaletteBuilder._();

  static Widget withBloc({required Widget child, PaletteBloc? bloc}) {
    return BlocProvider<PaletteBloc>(create: (_) => bloc ?? getIt<PaletteBloc>(), child: child);
  }
}
