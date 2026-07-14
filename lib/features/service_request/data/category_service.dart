import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.basePricePerHour,
  });

  final int id;
  final String name;
  final String description;
  final double basePricePerHour;

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

    return CategoryItem(
      id: id,
      name: name,
      description:
          rawDescription.length >= 25 &&
              !rawDescription.toLowerCase().contains('prueba')
          ? rawDescription
          : _fallbackDescription(name),
      basePricePerHour:
          double.tryParse(json['base_price_per_hour']?.toString() ?? '0') ?? 0,
    );
  }

  static String _fallbackDescription(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('dilig')) {
      return 'Acompañamiento presencial para realizar una diligencia o trámite en un lugar público.';
    }
    if (normalized.contains('médic') || normalized.contains('medic')) {
      return 'Compañía durante una cita o procedimiento ambulatorio. No incluye atención médica ni enfermería.';
    }
    if (normalized.contains('compr') || normalized.contains('merc')) {
      return 'Compañía para compras o recorridos en comercios y espacios abiertos al público.';
    }
    if (normalized.contains('camin') || normalized.contains('deport')) {
      return 'Compañía para caminar o realizar una actividad recreativa en un espacio público.';
    }
    if (normalized.contains('cultur') || normalized.contains('evento')) {
      return 'Compañía para asistir a una actividad cultural, social o recreativa abierta al público.';
    }
    return 'Acompañamiento presencial para la actividad seleccionada en un punto de encuentro público y seguro.';
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
