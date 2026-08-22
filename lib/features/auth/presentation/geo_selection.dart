class GeoSelection {
  const GeoSelection._();

  static List<Map<String, dynamic>> uniqueCountries(
    Iterable<Map<String, dynamic>> items,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      final code = item['code']?.toString().trim() ?? '';
      if (code.isEmpty || !seen.add(code)) continue;
      result.add(item);
    }
    return result;
  }

  static List<Map<String, dynamic>> uniquePlaces(
    Iterable<Map<String, dynamic>> items,
  ) {
    final seen = <int>{};
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = int.tryParse(item['id']?.toString() ?? '');
      if (id == null || !seen.add(id)) continue;
      result.add(item);
    }
    return result;
  }

  static String? validCountryCode(
    Iterable<Map<String, dynamic>> items,
    String? selectedCode,
  ) {
    if (selectedCode == null || selectedCode.isEmpty) return null;
    return items.any((item) => item['code']?.toString() == selectedCode)
        ? selectedCode
        : null;
  }

  static int? validPlaceId(
    Iterable<Map<String, dynamic>> items,
    int? selectedId,
  ) {
    if (selectedId == null) return null;
    return items.any(
          (item) => int.tryParse(item['id']?.toString() ?? '') == selectedId,
        )
        ? selectedId
        : null;
  }

  static Map<String, dynamic>? countryByCode(
    Iterable<Map<String, dynamic>> items,
    String? code,
  ) {
    if (code == null) return null;
    for (final item in items) {
      if (item['code']?.toString() == code) return item;
    }
    return null;
  }

  static Map<String, dynamic>? placeById(
    Iterable<Map<String, dynamic>> items,
    int? id,
  ) {
    if (id == null) return null;
    for (final item in items) {
      if (int.tryParse(item['id']?.toString() ?? '') == id) return item;
    }
    return null;
  }
}
