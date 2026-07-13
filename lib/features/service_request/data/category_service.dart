import '../../../core/network/api_client.dart';

class CategoryItem {
  final int id;
  final String name;

  const CategoryItem({required this.id, required this.name});

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'] ?? json['title'] ?? json['label'] ?? 'Sin nombre';
    return CategoryItem(
      id: (id is int) ? id : int.parse(id.toString()),
      name: name.toString(),
    );
  }
}

class CategoryService {
  /// Espera que exista un endpoint tipo:
  /// GET /api/services/categories/  -> [{id, name}, ...]
  /// (BaseUrl ya trae /api si tu ApiClient está configurado como antes)
  Future<List<CategoryItem>> listCategories() async {
    final res = await ApiClient.dio.get('/services/categories/');
    final data = res.data;

    if (data is List) {
      return data
          .map((e) => CategoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    // Soporte por si viene paginado: {results:[...]}
    if (data is Map && data['results'] is List) {
      final results = data['results'] as List;
      return results
          .map((e) => CategoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return [];
  }
}
