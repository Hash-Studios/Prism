import 'package:Prism/data/categories/categories.dart' as category_data;
import 'package:Prism/features/category_feed/category_feed.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/global/categoryMenu.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

CategoryMenu _toMenu(CategoryEntity category) => CategoryMenu(
      name: category.name,
      provider: category.provider,
      image: category.image,
    );

CategoryEntity _toEntity(CategoryMenu choice, List<CategoryEntity> categories) {
  final selectedName = (choice.name ?? '').trim();
  for (final category in categories) {
    if (category.name == selectedName) {
      return category;
    }
  }
  return CategoryEntity(
    name: choice.name ?? '',
    provider: choice.provider ?? '',
    type: 'search',
    image: choice.image ?? '',
  );
}

final List<CategoryMenu> categoryChoices = category_data.categories
    .map(
      (rawCategory) => CategoryMenu(
        name: rawCategory['name'].toString(),
        provider: rawCategory['provider'].toString(),
        image: rawCategory['image'].toString(),
      ),
    )
    .toList(growable: false);

extension CategoryFeedLegacyBridgeX on BuildContext {
  CategoryFeedBloc _categoryFeedBloc(bool listen) => listen ? watch<CategoryFeedBloc>() : read<CategoryFeedBloc>();

  List<CategoryMenu> categoryChoiceList({bool listen = true}) {
    final categories = _categoryFeedBloc(listen).state.categories;
    if (categories.isEmpty) {
      return categoryChoices;
    }
    return categories.map(_toMenu).toList(growable: false);
  }

  CategoryMenu categorySelectedChoice({bool listen = true}) {
    final state = _categoryFeedBloc(listen).state;
    final selected = state.selectedCategory;
    if (selected == null) {
      return categoryChoiceList(listen: listen).first;
    }
    return _toMenu(selected);
  }

  String? categoryCurrentChoice({bool listen = true}) => categorySelectedChoice(listen: listen).name;

  Future<List<dynamic>> categoryChangeWallpaperFuture(CategoryMenu choice, String mode) async {
    final bloc = _categoryFeedBloc(false);
    final category = _toEntity(choice, bloc.state.categories);
    if (mode == 'r') {
      bloc.add(CategoryFeedEvent.categorySelected(category: category));
    } else {
      final current = bloc.state.selectedCategory;
      if (current == null || current.name != category.name) {
        bloc.add(CategoryFeedEvent.categorySelected(category: category));
      } else {
        bloc.add(const CategoryFeedEvent.fetchMoreRequested());
      }
    }
    return <dynamic>[];
  }
}
