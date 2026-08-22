import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class SubcategoryItem {
  const SubcategoryItem({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.iconCode,
    required this.searchKeywords,
    required this.allowsCustomName,
  });

  final int id;
  final String code;
  final String name;
  final String description;
  final String iconCode;
  final List<String> searchKeywords;
  final bool allowsCustomName;

  String get searchableText =>
      <String>[name, description, ...searchKeywords].join(' ').toLowerCase();

  factory SubcategoryItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) {
      throw const FormatException('La subcategoría no contiene un id válido.');
    }
    final rawKeywords = json['search_keywords']?.toString() ?? '';
    return SubcategoryItem(
      id: id,
      code: json['code']?.toString().trim() ?? '',
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString().trim()
          : 'Actividad',
      description: json['description']?.toString().trim() ?? '',
      iconCode: json['icon_code']?.toString().trim().isNotEmpty == true
          ? json['icon_code'].toString().trim()
          : 'category',
      searchKeywords: rawKeywords
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      allowsCustomName: json['allows_custom_name'] == true,
    );
  }
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.basePricePerHour,
    required this.subcategories,
  });

  final int id;
  final String code;
  final String name;
  final String description;
  final double basePricePerHour;
  final List<SubcategoryItem> subcategories;

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) {
      throw const FormatException('La categoría no contiene un id válido.');
    }

    final rawName = json['name'] ?? json['title'] ?? json['label'];
    final name = rawName?.toString().trim().isNotEmpty == true
        ? rawName.toString().trim()
        : 'Sin nombre';
    final rawDescription = json['description']?.toString().trim() ?? '';
    final rawSubcategories = json['subcategories'];
    final subcategories = rawSubcategories is List
        ? rawSubcategories
              .whereType<Map>()
              .map(
                (item) =>
                    SubcategoryItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <SubcategoryItem>[];

    return CategoryItem(
      id: id,
      code: json['code']?.toString().trim() ?? '',
      name: name,
      description:
          rawDescription.length >= 25 &&
              !rawDescription.toLowerCase().contains('prueba')
          ? rawDescription
          : _fallbackDescription(name),
      basePricePerHour:
          double.tryParse(json['base_price_per_hour']?.toString() ?? '0') ?? 0,
      subcategories: subcategories,
    );
  }

  static String _fallbackDescription(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('dilig')) {
      return 'Acompañamiento presencial para una diligencia cotidiana en un lugar público.';
    }
    if (normalized.contains('compr') || normalized.contains('merc')) {
      return 'Compañía para compras o recorridos en comercios y espacios abiertos al público.';
    }
    if (normalized.contains('camin') || normalized.contains('recre')) {
      return 'Compañía para caminar o realizar una actividad recreativa en un espacio público.';
    }
    if (normalized.contains('cultur') || normalized.contains('evento')) {
      return 'Compañía para asistir a una actividad cultural, social o recreativa.';
    }
    return 'Acompañamiento presencial para una actividad cotidiana en un punto de encuentro público y seguro.';
  }
}

class ActivityCatalogItem {
  const ActivityCatalogItem({
    required this.category,
    required this.subcategory,
  });

  final CategoryItem category;
  final SubcategoryItem subcategory;

  String get searchableText => <String>[
    category.name,
    subcategory.searchableText,
  ].join(' ').toLowerCase();
}

class CategoryService {
  Future<List<CategoryItem>> listCategories() async {
    final response = await ApiClient.dio.get(Endpoints.categories);
    dynamic raw = response.data;
    if (raw is Map && raw['results'] is List) {
      raw = raw['results'];
    }
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => CategoryItem.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.subcategories.isNotEmpty)
        .toList();
  }
}
