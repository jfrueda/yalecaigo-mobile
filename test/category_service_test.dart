import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/features/service_request/data/category_service.dart';

void main() {
  test('CategoryItem acepta name, title o label', () {
    expect(
      CategoryItem.fromJson({'id': 1, 'name': 'Acompañamiento'}).name,
      'Acompañamiento',
    );
    expect(CategoryItem.fromJson({'id': '2', 'title': 'Diligencias'}).id, 2);
    expect(
      CategoryItem.fromJson({'id': 3, 'label': 'Compras'}).name,
      'Compras',
    );
  });

  test('CategoryItem carga subcategorías públicas de la API', () {
    final category = CategoryItem.fromJson({
      'id': 10,
      'name': 'Actividades sociales',
      'description': 'Actividades cotidianas en espacios públicos.',
      'base_price_per_hour': '25000.00',
      'subcategories': [
        {
          'id': 101,
          'name': 'Ir al cine',
          'description': 'Acompañamiento para asistir al cine.',
        },
        {'id': '102', 'name': 'Tomar un café', 'description': ''},
      ],
    });

    expect(category.subcategories, hasLength(2));
    expect(category.subcategories.first.id, 101);
    expect(category.subcategories.first.name, 'Ir al cine');
    expect(category.subcategories.last.id, 102);
  });

  test('SubcategoryItem carga icono, aliases y actividad personalizada', () {
    final category = CategoryItem.fromJson({
      'id': 20,
      'code': 'actividades-sociales',
      'name': 'Actividades sociales',
      'description': 'Actividades cotidianas en espacios públicos y seguros.',
      'base_price_per_hour': '30000.00',
      'subcategories': [
        {
          'id': 201,
          'code': 'social-otra-actividad-cotidiana',
          'name': 'Otra actividad cotidiana',
          'description': 'Una actividad cotidiana personalizada.',
          'icon_code': 'other',
          'search_keywords': 'otra,personalizada,feria',
          'allows_custom_name': true,
        },
      ],
    });

    final subcategory = category.subcategories.single;
    expect(category.code, 'actividades-sociales');
    expect(subcategory.iconCode, 'other');
    expect(subcategory.searchKeywords, contains('feria'));
    expect(subcategory.allowsCustomName, isTrue);
    expect(
      ActivityCatalogItem(
        category: category,
        subcategory: subcategory,
      ).searchableText,
      contains('personalizada'),
    );
  });
}
