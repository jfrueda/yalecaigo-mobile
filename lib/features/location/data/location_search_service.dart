import 'package:dio/dio.dart';

class LocationRules {
  final List<String> allowedCities; // e.g. ['Bogotá', 'Bogota']
  final String countryCode; // e.g. 'co'

  /// allowedClassTypes: qué "class" de OSM aceptamos (amenity, leisure, shop, place, tourism...)
  final Set<String> allowedClassTypes;

  /// allowedPlaceTypes: por cada class, qué "type" aceptamos. '*' = cualquiera
  /// Ej: { 'amenity': {'cafe','restaurant','bar'}, 'shop': {'mall','supermarket'} }
  final Map<String, Set<String>> allowedPlaceTypes;

  /// class/type bloqueados SIEMPRE (ej: alojamiento)
  final Map<String, Set<String>> blockedClassTypes;

  /// keywords bloqueados en el display_name o name (hotel, apartamento, residencia...)
  final Set<String> blockedKeywords;

  const LocationRules({
    required this.allowedCities,
    required this.countryCode,
    required this.allowedClassTypes,
    required this.allowedPlaceTypes,
    required this.blockedClassTypes,
    required this.blockedKeywords,
  });

  /// Reglas base para Bogotá (MVP):
  /// - Solo ciudad permitida: Bogotá (variantes)
  /// - Solo lugares públicos (parques, cafés, centros comerciales, restaurantes, plazas, etc.)
  /// - Bloquea hoteles / residencias
  factory LocationRules.defaultBogota() {
    return LocationRules(
      allowedCities: const [
        'Bogotá',
        'Bogota',
        'Bogotá D.C.',
        'Bogota D.C.',
        'Bogotá, D.C.',
        'Bogota, D.C.',
      ],
      countryCode: 'co',
      allowedClassTypes: const {
        'amenity',
        'leisure',
        'shop',
        'tourism',
        'place',
        'building',
        'man_made',
        'historic',
      },
      allowedPlaceTypes: const {
        // Comida / público
        'amenity': {
          'cafe',
          'restaurant',
          'bar',
          'fast_food',
          'food_court',
          'ice_cream',
          'cinema',
          'theatre',
          'library',
          'community_centre',
          'marketplace',
          'university',
          'college',
          'school',
          'hospital',
          'clinic',
          'pharmacy',
          'police', // discutible pero público
        },

        // Parques / recreación
        'leisure': {
          'park',
          'garden',
          'playground',
          'sports_centre',
          'pitch',
          'stadium',
          'fitness_centre',
        },

        // Comercio / centros comerciales
        'shop': {'mall', 'supermarket', 'department_store', 'convenience'},

        // Turismo / público
        'tourism': {'attraction', 'museum', 'gallery', 'viewpoint', 'zoo'},

        // Lugares (plazas, barrios) – útil cuando Nominatim no clasifica como amenity/leisure
        'place': {'square', 'neighbourhood', 'suburb', 'locality'},

        // Edificios (a veces “Gran Estación” viene como building=retail o building=commercial)
        'building': {
          'retail',
          'commercial',
          'public',
          'civic',
          'yes', // algunos lugares vienen como building=yes; lo validamos por keywords
        },

        'historic': {'monument', 'memorial'},
        'man_made': {'tower', 'bridge'},
      },

      // Bloqueos duros
      blockedClassTypes: const {
        'tourism': {'hotel', 'motel', 'hostel', 'guest_house', 'apartment'},
        'building': {'residential', 'apartments', 'house', 'detached'},
      },

      blockedKeywords: const {
        // alojamiento / residencial
        'hotel',
        'hostel',
        'motel',
        'apartamento',
        'apartments',
        'residencia',
        'residential',
        'casa',
        'house',
        'condominio',
        'conjunto',
        'edificio residencial',
        'airbnb',
        'habitacion',
        'habitación',
      },
    );
  }

  bool isBlockedByKeyword(String text) {
    final t = text.toLowerCase();
    return blockedKeywords.any((k) => t.contains(k));
  }
}

class LocationPlace {
  final String title; // nombre corto
  final String displayName; // nombre largo
  final double lat;
  final double lng;

  /// Class/type de OSM si vienen
  final String? osmClass;
  final String? osmType;

  /// true si pasa reglas; si false, rejectReason explica por qué
  final bool isAllowed;
  final String? rejectReason;

  /// raw response por si necesitas debug
  final Map<String, dynamic> raw;

  LocationPlace({
    required this.title,
    required this.displayName,
    required this.lat,
    required this.lng,
    required this.isAllowed,
    this.rejectReason,
    this.osmClass,
    this.osmType,
    required this.raw,
  });
}

class LocationSearchService {
  final Dio _dio;
  final LocationRules _rules;

  LocationSearchService({Dio? dio, LocationRules? rules})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: const {
                'Accept': 'application/json',
                // Nominatim pide User-Agent identificable; pon uno simple
                'User-Agent': 'gowith-mvp/1.0 (contact: dev@local)',
              },
            ),
          ),
      _rules = rules ?? LocationRules.defaultBogota();

  // -------------------------
  // Public API
  // -------------------------

  /// Busca lugares por texto (autocomplete simple).
  /// OJO: para MVP devolvemos resultados aunque estén bloqueados,
  /// pero marcados con isAllowed=false + reason.
  Future<List<LocationPlace>> search(String query, {int limit = 8}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // Nominatim Search
    // Nota: usamos `accept-language=es` para mejor display_name en español
    final url = 'https://nominatim.openstreetmap.org/search';
    final res = await _dio.get(
      url,
      queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'addressdetails': 1,
        'limit': limit,
        'countrycodes': _rules.countryCode,
        'accept-language': 'es',
      },
    );

    final data = res.data;
    if (data is! List) return [];

    final places = <LocationPlace>[];
    for (final item in data) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);

      final displayName = (m['display_name'] ?? '').toString();
      final lat = double.tryParse((m['lat'] ?? '').toString());
      final lng = double.tryParse((m['lon'] ?? '').toString());
      if (lat == null || lng == null) continue;

      final osmClass = m['class']?.toString();
      final osmType = m['type']?.toString();

      final title = _bestTitle(m);

      final v = _validate(
        m,
        displayName: displayName,
        osmClass: osmClass,
        osmType: osmType,
      );
      places.add(
        LocationPlace(
          title: title,
          displayName: displayName,
          lat: lat,
          lng: lng,
          osmClass: osmClass,
          osmType: osmType,
          isAllowed: v.$1,
          rejectReason: v.$2,
          raw: m,
        ),
      );
    }

    // Orden: primero los permitidos, luego los bloqueados
    places.sort((a, b) {
      if (a.isAllowed == b.isAllowed) return 0;
      return a.isAllowed ? -1 : 1;
    });

    return places;
  }

  /// Reverse geocode para obtener nombre desde lat/lng.
  Future<LocationPlace?> reverse(double lat, double lng) async {
    final url = 'https://nominatim.openstreetmap.org/reverse';
    final res = await _dio.get(
      url,
      queryParameters: {
        'lat': lat,
        'lon': lng,
        'format': 'jsonv2',
        'addressdetails': 1,
        'zoom': 18,
        'accept-language': 'es',
      },
    );

    final data = res.data;
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);

    final displayName = (m['display_name'] ?? '').toString();
    final osmClass = m['class']?.toString();
    final osmType = m['type']?.toString();

    final v = _validate(
      m,
      displayName: displayName,
      osmClass: osmClass,
      osmType: osmType,
    );
    return LocationPlace(
      title: _bestTitle(m),
      displayName: displayName,
      lat: lat,
      lng: lng,
      osmClass: osmClass,
      osmType: osmType,
      isAllowed: v.$1,
      rejectReason: v.$2,
      raw: m,
    );
  }

  // -------------------------
  // Internal validation
  // -------------------------

  (bool, String?) _validate(
    Map<String, dynamic> raw, {
    required String displayName,
    required String? osmClass,
    required String? osmType,
  }) {
    // 1) Bloqueo por keywords (hotel/residencia)
    final nameToCheck = '${_bestTitle(raw)} $displayName'.toLowerCase();
    if (_rules.isBlockedByKeyword(nameToCheck)) {
      return (
        false,
        'Lugar no permitido (hotel/residencia). Elige un punto público.',
      );
    }

    // 2) Ciudad permitida (match flexible)
    if (!_isInAllowedCity(raw, displayName)) {
      return (false, 'Fuera de la ciudad permitida.');
    }

    // 3) Bloqueo por class/type duros
    if (osmClass != null) {
      final blockedTypes = _rules.blockedClassTypes[osmClass];
      if (blockedTypes != null &&
          osmType != null &&
          blockedTypes.contains(osmType)) {
        return (
          false,
          'Lugar no permitido por tipo (alojamiento/residencial).',
        );
      }
    }

    // 4) Validación de "lugar público"
    // Si viene class/type, usamos allowlist.
    final looksAllowedByClassType = _isAllowedByClassType(osmClass, osmType);

    // Si no pasó por class/type, intentamos por keywords de lugar público.
    final looksPublicByKeywords = _looksPublicByKeywords(nameToCheck);

    if (looksAllowedByClassType || looksPublicByKeywords) {
      return (true, null);
    }

    // Si no se pudo clasificar, lo marcamos bloqueado pero con mensaje claro.
    return (
      false,
      'No parece un punto público válido. Prueba parque, café o centro comercial.',
    );
  }

  bool _isAllowedByClassType(String? osmClass, String? osmType) {
    if (osmClass == null) return false;
    if (!_rules.allowedClassTypes.contains(osmClass)) return false;

    final allowedTypes = _rules.allowedPlaceTypes[osmClass];
    if (allowedTypes == null) return false;

    if (allowedTypes.contains('*')) return true;
    if (osmType == null) return false;

    return allowedTypes.contains(osmType);
  }

  bool _looksPublicByKeywords(String lowerText) {
    // Heurística MVP para cuando Nominatim devuelve building=yes o place=locality etc.
    const publicKeywords = [
      'parque',
      'plaza',
      'centro comercial',
      'cc ',
      'mall',
      'café',
      'cafe',
      'restaurante',
      'restaurant',
      'bar',
      'biblioteca',
      'museo',
      'cinema',
      'cine',
      'universidad',
      'campus',
      'estadio',
      'coliseo',
      'teatro',
      'galeria',
      'galería',
      'mirador',
      'mercado',
      'market',
    ];
    return publicKeywords.any((k) => lowerText.contains(k));
  }

  bool _isInAllowedCity(Map<String, dynamic> raw, String displayName) {
    final allowed = _rules.allowedCities.map((e) => e.toLowerCase()).toList();

    // 1) buscar en address fields
    final address = raw['address'];
    if (address is Map) {
      final a = Map<String, dynamic>.from(address);
      final candidates = <String>[
        a['city']?.toString() ?? '',
        a['town']?.toString() ?? '',
        a['municipality']?.toString() ?? '',
        a['county']?.toString() ?? '',
        a['state']?.toString() ?? '',
        a['region']?.toString() ?? '',
      ].map((s) => s.toLowerCase()).where((s) => s.isNotEmpty).toList();

      for (final c in candidates) {
        // match flexible: si contiene "bogota" ya sirve
        if (c.contains('bogota') || c.contains('bogotá')) return true;
        if (allowed.any((x) => c.contains(x))) return true;
      }
    }

    // 2) fallback por display_name
    final d = displayName.toLowerCase();
    if (d.contains('bogota') || d.contains('bogotá')) return true;
    if (allowed.any((x) => d.contains(x))) return true;

    return false;
  }

  String _bestTitle(Map<String, dynamic> raw) {
    final name = raw['name']?.toString();
    if (name != null && name.trim().isNotEmpty) return name.trim();

    // a veces viene "display_name" como "Parque de la 93, Chicó, Bogotá..."
    final display = raw['display_name']?.toString() ?? '';
    if (display.trim().isEmpty) return 'Ubicación';

    final first = display.split(',').first.trim();
    return first.isEmpty ? 'Ubicación' : first;
  }
}
