import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class CategoryItem {
  const CategoryItem({required this.id, required this.name});

  final int id;
  final String name;

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) {
      throw const FormatException('La categoría no contiene un id válido.');
    }

    final rawName = json['name'] ?? json['title'] ?? json['label'];
    return CategoryItem(
      id: id,
      name: rawName?.toString().trim().isNotEmpty == true
          ? rawName.toString().trim()
          : 'Sin nombre',
    );
  }
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
        .toList();
  }
}
