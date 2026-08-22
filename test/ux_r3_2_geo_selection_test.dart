import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/features/auth/presentation/geo_selection.dart';

void main() {
  test('geographic catalogs are deduplicated by stable identifiers', () {
    final countries = GeoSelection.uniqueCountries(<Map<String, dynamic>>[
      <String, dynamic>{'code': 'CO', 'name': 'Colombia'},
      <String, dynamic>{'code': 'CO', 'name': 'Colombia duplicada'},
      <String, dynamic>{'code': 'PE', 'name': 'Perú'},
    ]);
    final places = GeoSelection.uniquePlaces(<Map<String, dynamic>>[
      <String, dynamic>{'id': 3, 'code': '11', 'name': 'Bogotá, D.C.'},
      <String, dynamic>{'id': 3, 'code': '11', 'name': 'Bogotá duplicada'},
      <String, dynamic>{'id': 4, 'code': '25', 'name': 'Cundinamarca'},
    ]);

    expect(countries.map((item) => item['code']), <String>['CO', 'PE']);
    expect(places.map((item) => item['id']), <int>[3, 4]);
  });

  test(
    'selection survives catalog reload using stable ids instead of Map identity',
    () {
      final firstLoad = <Map<String, dynamic>>[
        <String, dynamic>{'id': 3, 'code': '11', 'name': 'Bogotá, D.C.'},
      ];
      final selectedId = GeoSelection.validPlaceId(firstLoad, 3);

      final secondLoad = <Map<String, dynamic>>[
        <String, dynamic>{'id': 3, 'code': '11', 'name': 'Bogotá, D.C.'},
      ];

      expect(identical(firstLoad.first, secondLoad.first), isFalse);
      expect(GeoSelection.validPlaceId(secondLoad, selectedId), 3);
      expect(
        GeoSelection.placeById(secondLoad, selectedId)?['name'],
        'Bogotá, D.C.',
      );
    },
  );

  test(
    'stale selections are cleared when the new catalog no longer contains them',
    () {
      final places = <Map<String, dynamic>>[
        <String, dynamic>{'id': 4, 'code': '25', 'name': 'Cundinamarca'},
      ];
      expect(GeoSelection.validPlaceId(places, 3), isNull);
      expect(
        GeoSelection.validCountryCode(<Map<String, dynamic>>[
          <String, dynamic>{'code': 'CO'},
        ], 'PE'),
        isNull,
      );
    },
  );
}
