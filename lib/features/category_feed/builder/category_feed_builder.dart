import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CategoryFeedBuilder {
  const CategoryFeedBuilder._();

  static Widget withBloc({required Widget child, CategoryFeedBloc? bloc}) {
    return BlocProvider<CategoryFeedBloc>(
      create: (_) => bloc ?? getIt<CategoryFeedBloc>(),
      child: child,
    );
  }
}
