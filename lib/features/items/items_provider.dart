import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/search_engine.dart';

class CatalogState {
  final List<ItemWithRelations> allItems;
  final List<CategoryModel> categories;
  final List<UnitModel> units;
  final String searchQuery;
  final int? selectedCategoryId;
  final bool isLoading;
  final int? lastUsedCategoryId;
  final int? lastUsedRetailUnitId;
  final int? lastUsedWholesaleUnitId;

  const CatalogState({
    this.allItems = const [],
    this.categories = const [],
    this.units = const [],
    this.searchQuery = '',
    this.selectedCategoryId,
    this.isLoading = true,
    this.lastUsedCategoryId,
    this.lastUsedRetailUnitId,
    this.lastUsedWholesaleUnitId,
  });

  /// Daftar hasil yang telah disaring dan diurutkan di memori
  List<ItemWithRelations> get filteredItems {
    final searchable = allItems
        .map(
          (item) => SearchableItem<ItemWithRelations>(
            data: item,
            name: item.name,
            nameSearch: item.nameSearch,
            categoryId: item.categoryId,
            barcode: item.barcode,
          ),
        )
        .toList();

    return SearchEngine.search<ItemWithRelations>(
      items: searchable,
      rawQuery: searchQuery,
      selectedCategoryId: selectedCategoryId,
    );
  }

  CatalogState copyWith({
    List<ItemWithRelations>? allItems,
    List<CategoryModel>? categories,
    List<UnitModel>? units,
    String? searchQuery,
    int? selectedCategoryId,
    bool clearSelectedCategory = false,
    bool? isLoading,
    int? lastUsedCategoryId,
    int? lastUsedRetailUnitId,
    int? lastUsedWholesaleUnitId,
  }) {
    return CatalogState(
      allItems: allItems ?? this.allItems,
      categories: categories ?? this.categories,
      units: units ?? this.units,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId:
          clearSelectedCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      isLoading: isLoading ?? this.isLoading,
      lastUsedCategoryId: lastUsedCategoryId ?? this.lastUsedCategoryId,
      lastUsedRetailUnitId: lastUsedRetailUnitId ?? this.lastUsedRetailUnitId,
      lastUsedWholesaleUnitId: lastUsedWholesaleUnitId ?? this.lastUsedWholesaleUnitId,
    );
  }
}

class CatalogNotifier extends StateNotifier<CatalogState> {
  CatalogNotifier() : super(const CatalogState()) {
    refreshAll();
  }

  final _db = AppDatabase.instance;

  Future<void> refreshAll() async {
    final categories = await _db.getAllCategories();
    final units = await _db.getAllUnits();
    final items = await _db.getAllItemsWithRelations();

    state = state.copyWith(
      allItems: items,
      categories: categories,
      units: units,
      isLoading: false,
      lastUsedCategoryId: state.lastUsedCategoryId ??
          (categories.isNotEmpty ? categories.first.id : null),
      lastUsedRetailUnitId: state.lastUsedRetailUnitId ??
          (units.isNotEmpty ? units.first.id : null),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategoryFilter(int? categoryId) {
    if (categoryId == null || state.selectedCategoryId == categoryId) {
      state = state.copyWith(clearSelectedCategory: true);
    } else {
      state = state.copyWith(selectedCategoryId: categoryId);
    }
  }

  void rememberLastUsed({
    required int categoryId,
    required int retailUnitId,
    int? wholesaleUnitId,
  }) {
    state = state.copyWith(
      lastUsedCategoryId: categoryId,
      lastUsedRetailUnitId: retailUnitId,
      lastUsedWholesaleUnitId: wholesaleUnitId,
    );
  }

  Future<void> restoreDeletedItem(ItemWithRelations item) async {
    await _db.insertItem(
      explicitId: item.id,
      name: item.name,
      categoryId: item.categoryId,
      barcode: item.barcode,
      retailPrice: item.retailPrice,
      retailUnitId: item.retailUnitId,
      wholesalePrice: item.wholesalePrice,
      wholesaleUnitId: item.wholesaleUnitId,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
    await refreshAll();
  }
}

final catalogProvider = StateNotifierProvider<CatalogNotifier, CatalogState>((ref) {
  return CatalogNotifier();
});