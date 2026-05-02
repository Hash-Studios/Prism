import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/categories.dart' as category_data;
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/global/categoryMenu.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

CategoryMenu _toMenu(CategoryEntity category) => CategoryMenu(
  name: category.name,
  provider: category.source.legacyProviderString,
  image: category.image,
  image2: category.image2,
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
    source: WallpaperSourceX.fromWire(choice.provider),
    searchType: CategorySearchType.search,
    image: choice.image ?? '',
    image2: choice.image2 ?? '',
  );
}

final List<CategoryMenu> categoryChoices = category_data.categoryDefinitions
    .map(
      (def) => CategoryMenu(
        name: def.name,
        provider: def.source.legacyProviderString,
        image: def.imageUrl,
        image2: def.secondaryImageUrl,
      ),
    )
    .toList(growable: false);

extension CategoryFeedBlocAdapterX on BuildContext {
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

  Future<void> categoryChangeWallpaperFuture(CategoryMenu choice, String mode) async {
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
  }
}
