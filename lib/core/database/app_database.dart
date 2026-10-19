import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/formatters.dart';

class CategoryModel {
  final int id;
  final String name;
  final String iconKey;
  final String? colorHex;
  final int sortOrder;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconKey,
    this.colorHex,
    required this.sortOrder,
  });

  bool get isDefaultLainnya => name.toLowerCase() == 'lainnya';

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int,
      name: map['name'] as String,
      iconKey: map['icon_key'] as String,
      colorHex: map['color_hex'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}

class UnitModel {
  final int id;
  final String name;
  final bool isDefault;

  const UnitModel({
    required this.id,
    required this.name,
    required this.isDefault,
  });

  factory UnitModel.fromMap(Map<String, dynamic> map) {
    return UnitModel(
      id: map['id'] as int,
      name: map['name'] as String,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }
}

class ItemWithRelations {
  final int id;
  final String name;
  final String nameSearch;
  final int categoryId;
  final String categoryName;
  final String categoryIconKey;
  final String? barcode;
  final int retailPrice;
  final int retailUnitId;
  final String retailUnitName;
  final int? wholesalePrice;
  final int? wholesaleUnitId;
  final String? wholesaleUnitName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItemWithRelations({
    required this.id,
    required this.name,
    required this.nameSearch,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIconKey,
    this.barcode,
    required this.retailPrice,
    required this.retailUnitId,
    required this.retailUnitName,
    this.wholesalePrice,
    this.wholesaleUnitId,
    this.wholesaleUnitName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ItemWithRelations.fromMap(Map<String, dynamic> map) {
    return ItemWithRelations(
      id: map['id'] as int,
      name: map['name'] as String,
      nameSearch: map['name_search'] as String,
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String? ?? 'Lainnya',
      categoryIconKey: map['category_icon_key'] as String? ?? 'category',
      barcode: map['barcode'] as String?,
      retailPrice: map['retail_price'] as int,
      retailUnitId: map['retail_unit_id'] as int,
      retailUnitName: map['retail_unit_name'] as String? ?? 'pcs',
      wholesalePrice: map['wholesale_price'] as int?,
      wholesaleUnitId: map['wholesale_unit_id'] as int?,
      wholesaleUnitName: map['wholesale_unit_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('banderol.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          icon_key TEXT NOT NULL,
          color_hex TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await txn.execute('''
        CREATE TABLE units (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          is_default INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await txn.execute('''
        CREATE TABLE items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          name_search TEXT NOT NULL,
          category_id INTEGER NOT NULL,
          barcode TEXT UNIQUE,
          retail_price INTEGER NOT NULL,
          retail_unit_id INTEGER NOT NULL,
          wholesale_price INTEGER,
          wholesale_unit_id INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT,
          FOREIGN KEY (retail_unit_id) REFERENCES units (id) ON DELETE RESTRICT,
          FOREIGN KEY (wholesale_unit_id) REFERENCES units (id) ON DELETE RESTRICT
        )
      ''');

      // Indeks sesuai Bab 10 PRD
      await txn.execute('CREATE INDEX idx_items_name_search ON items(name_search)');
      await txn.execute('CREATE INDEX idx_items_barcode ON items(barcode)');
      await txn.execute('CREATE INDEX idx_items_category_id ON items(category_id)');

      // Kategori bawaan wajib "Lainnya" (FR-31) + kategori sembako umum
      final initialCategories = [
        {'name': 'Lainnya', 'icon_key': 'category', 'sort_order': 0},
        {'name': 'Sembako Pokok', 'icon_key': 'rice_bowl', 'sort_order': 1},
        {'name': 'Minuman', 'icon_key': 'local_drink', 'sort_order': 2},
        {'name': 'Mi & Instan', 'icon_key': 'ramen_dining', 'sort_order': 3},
        {'name': 'Bumbu & Dapur', 'icon_key': 'kitchen', 'sort_order': 4},
        {'name': 'Sabun & Cuci', 'icon_key': 'cleaning_services', 'sort_order': 5},
        {'name': 'Camilan', 'icon_key': 'cookie', 'sort_order': 6},
      ];

      for (final cat in initialCategories) {
        await txn.insert('categories', cat);
      }

      // 14 Satuan bawaan sesuai Bab 19 PRD (FR-40)
      const defaultUnits = [
        'pcs',
        'bungkus',
        'sachet',
        'botol',
        'kaleng',
        'pak',
        'dus',
        'karton',
        'bal',
        'karung',
        'kg',
        'gram',
        'liter',
        'lusin',
      ];

      for (final unit in defaultUnits) {
        await txn.insert('units', {'name': unit, 'is_default': 1});
      }
    });
  }

  // ==================== KATEGORI ====================

  Future<List<CategoryModel>> getAllCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'sort_order ASC, name ASC');
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<int> insertCategory({
    required String name,
    required String iconKey,
    String? colorHex,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      return await txn.insert('categories', {
        'name': name.trim(),
        'icon_key': iconKey,
        'color_hex': colorHex,
        'sort_order': 99,
      });
    });
  }

  Future<void> updateCategory(CategoryModel category) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'categories',
        {
          'name': category.name.trim(),
          'icon_key': category.iconKey,
          'color_hex': category.colorHex,
          'sort_order': category.sortOrder,
        },
        where: 'id = ?',
        whereArgs: [category.id],
      );
    });
  }

  Future<void> deleteCategory(int categoryId) async {
    final db = await database;
    await db.transaction((txn) async {
      final catRows = await txn.query('categories', where: 'id = ?', whereArgs: [categoryId]);
      if (catRows.isNotEmpty &&
          (catRows.first['name'] as String).toLowerCase() == 'lainnya') {
        throw Exception('Kategori bawaan "Lainnya" tidak dapat dihapus.');
      }

      final count = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM items WHERE category_id = ?',
            [categoryId],
          )) ??
          0;
      if (count > 0) {
        throw Exception(
          'Kategori ini masih memiliki $count barang. Pindahkan barang terlebih dahulu sebelum menghapus.',
        );
      }

      await txn.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
    });
  }

  // ==================== SATUAN ====================

  Future<List<UnitModel>> getAllUnits() async {
    final db = await database;
    final rows = await db.query('units', orderBy: 'name ASC');
    return rows.map(UnitModel.fromMap).toList();
  }

  Future<int> insertUnit(String name) async {
    final db = await database;
    return await db.transaction((txn) async {
      return await txn.insert('units', {
        'name': name.trim(),
        'is_default': 0,
      });
    });
  }

  Future<void> updateUnit(int id, String newName) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'units',
        {'name': newName.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deleteUnit(int unitId) async {
    final db = await database;
    await db.transaction((txn) async {
      final count = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM items WHERE retail_unit_id = ? OR wholesale_unit_id = ?',
            [unitId, unitId],
          )) ??
          0;
      if (count > 0) {
        throw Exception('Satuan ini masih dipakai oleh $count barang dan tidak bisa dihapus.');
      }
      await txn.delete('units', where: 'id = ?', whereArgs: [unitId]);
    });
  }

  // ==================== BARANG (ITEMS) ====================

  Future<List<ItemWithRelations>> getAllItemsWithRelations() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT 
        i.*,
        c.name AS category_name,
        c.icon_key AS category_icon_key,
        ru.name AS retail_unit_name,
        wu.name AS wholesale_unit_name
      FROM items i
      INNER JOIN categories c ON i.category_id = c.id
      INNER JOIN units ru ON i.retail_unit_id = ru.id
      LEFT JOIN units wu ON i.wholesale_unit_id = wu.id
      ORDER BY i.name COLLATE NOCASE ASC
    ''');
    return rows.map(ItemWithRelations.fromMap).toList();
  }

  Future<ItemWithRelations?> findItemByBarcode(String barcode) async {
    final db = await database;
    final clean = barcode.trim();
    if (clean.isEmpty) return null;
    final rows = await db.rawQuery('''
      SELECT 
        i.*,
        c.name AS category_name,
        c.icon_key AS category_icon_key,
        ru.name AS retail_unit_name,
        wu.name AS wholesale_unit_name
      FROM items i
      INNER JOIN categories c ON i.category_id = c.id
      INNER JOIN units ru ON i.retail_unit_id = ru.id
      LEFT JOIN units wu ON i.wholesale_unit_id = wu.id
      WHERE i.barcode = ?
      LIMIT 1
    ''', [clean]);
    if (rows.isEmpty) return null;
    return ItemWithRelations.fromMap(rows.first);
  }

  Future<ItemWithRelations?> findItemByExactName(String name, {int? excludeId}) async {
    final db = await database;
    final clean = name.trim().toLowerCase();
    final rows = await db.rawQuery('''
      SELECT 
        i.*,
        c.name AS category_name,
        c.icon_key AS category_icon_key,
        ru.name AS retail_unit_name,
        wu.name AS wholesale_unit_name
      FROM items i
      INNER JOIN categories c ON i.category_id = c.id
      INNER JOIN units ru ON i.retail_unit_id = ru.id
      LEFT JOIN units wu ON i.wholesale_unit_id = wu.id
      WHERE LOWER(i.name) = ? ${excludeId != null ? 'AND i.id != ?' : ''}
      LIMIT 1
    ''', excludeId != null ? [clean, excludeId] : [clean]);
    if (rows.isEmpty) return null;
    return ItemWithRelations.fromMap(rows.first);
  }

  Future<int> insertItem({
    int? explicitId,
    required String name,
    required int categoryId,
    String? barcode,
    required int retailPrice,
    required int retailUnitId,
    int? wholesalePrice,
    int? wholesaleUnitId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final db = await database;
    final cleanName = name.trim();
    final cleanBarcode = (barcode == null || barcode.trim().isEmpty) ? null : barcode.trim();
    final nowIso = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      final data = <String, dynamic>{
        'name': cleanName,
        'name_search': AppFormatters.normalizeSearchText(cleanName),
        'category_id': categoryId,
        'barcode': cleanBarcode,
        'retail_price': retailPrice,
        'retail_unit_id': retailUnitId,
        'wholesale_price': wholesalePrice,
        'wholesale_unit_id': wholesalePrice != null ? wholesaleUnitId : null,
        'created_at': (createdAt?.toIso8601String()) ?? nowIso,
        'updated_at': (updatedAt?.toIso8601String()) ?? nowIso,
      };
      if (explicitId != null) {
        data['id'] = explicitId;
      }
      return await txn.insert('items', data);
    });
  }

  Future<void> updateItem({
    required int id,
    required String name,
    required int categoryId,
    String? barcode,
    required int retailPrice,
    required int retailUnitId,
    int? wholesalePrice,
    int? wholesaleUnitId,
  }) async {
    final db = await database;
    final cleanName = name.trim();
    final cleanBarcode = (barcode == null || barcode.trim().isEmpty) ? null : barcode.trim();

    await db.transaction((txn) async {
      await txn.update(
        'items',
        {
          'name': cleanName,
          'name_search': AppFormatters.normalizeSearchText(cleanName),
          'category_id': categoryId,
          'barcode': cleanBarcode,
          'retail_price': retailPrice,
          'retail_unit_id': retailUnitId,
          'wholesale_price': wholesalePrice,
          'wholesale_unit_id': wholesalePrice != null ? wholesaleUnitId : null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deleteItem(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('items', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Generator data contoh (600 s.d. 5.000 barang) untuk pengujian performa & portofolio (Bab 16 PRD)
  Future<void> generateSampleItems(int count) async {
    final db = await database;
    final categories = await getAllCategories();
    final units = await getAllUnits();
    final pcsUnit = units.firstWhere((u) => u.name == 'pcs', orElse: () => units.first);
    final dusUnit = units.firstWhere((u) => u.name == 'dus', orElse: () => units.last);

    const baseNames = [
      'Gula Pasir Gulaku',
      'Minyak Goreng Bimoli',
      'Indomie Goreng Spesial',
      'Indomie Soto Mie',
      'Beras Ramos Super',
      'Kopi Kapal Api Special',
      'Teh Celup Sariwangi',
      'Susu Kental Manis Frisian Flag',
      'Sabun Mandi Lifebuoy',
      'Sampo Sunsilk Black',
      'Deterjen Rinso Anti Noda',
      'Kecap Manis Bango',
      'Saus Sambal ABC',
      'Tepung Terigu Segitiga Biru',
      'Mentega Blue Band',
      'Telur Ayam Negeri',
      'Garam Dapur Refina',
      'Air Mineral Aqua',
      'Biskuit Roma Kelapa',
      'Obat Nyamuk Hit Aerosol',
    ];

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      for (int i = 1; i <= count; i++) {
        final base = baseNames[i % baseNames.length];
        final size = '${(i % 10 + 1) * 100}gr Varian $i';
        final fullName = '$base $size';
        final cat = categories[i % categories.length];
        final retailPrice = ((i % 45) + 3) * 1000;
        final wholesalePrice = retailPrice * 12 - 5000;
        final barcode = (8990000000000 + i).toString();

        await txn.insert(
          'items',
          {
            'name': fullName,
            'name_search': AppFormatters.normalizeSearchText(fullName),
            'category_id': cat.id,
            'barcode': barcode,
            'retail_price': retailPrice,
            'retail_unit_id': pcsUnit.id,
            'wholesale_price': wholesalePrice,
            'wholesale_unit_id': dusUnit.id,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }
}