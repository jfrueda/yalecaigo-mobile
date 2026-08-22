import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/features/account/data/account_service.dart';
import 'package:gowith/features/account/presentation/provider_capabilities_page.dart';

class _FakeAccountService extends AccountService {
  List<int>? savedCategoryIds;
  List<int>? savedSubcategoryIds;

  Map<String, dynamic> _payload(List<int> selectedSubcategoryIds) {
    return {
      'available_categories': [
        {
          'id': 10,
          'name': 'Actividades sociales',
          'description': 'Actividades cotidianas en espacios públicos.',
          'subcategories': [
            {'id': 101, 'name': 'Ir al cine', 'icon_code': 'movie'},
            {'id': 102, 'name': 'Tomar un café', 'icon_code': 'coffee'},
          ],
        },
      ],
      'capabilities': [
        {
          'id': 1,
          'category_id': 10,
          'is_selected': true,
          'is_active': true,
          'status': 'APPROVED',
          'selected_subcategory_ids': selectedSubcategoryIds,
        },
      ],
      'selected_subcategory_ids': selectedSubcategoryIds,
      'save_summary': {'message': 'Las actividades fueron guardadas.'},
    };
  }

  @override
  Future<Map<String, dynamic>> getProviderCapabilities() async {
    return _payload([101]);
  }

  @override
  Future<Map<String, dynamic>> getAvailability() async {
    return {
      'is_available': true,
      'operationally_available': true,
      'message': 'Tu perfil está disponible.',
    };
  }

  @override
  Future<Map<String, dynamic>> updateProviderCapabilities({
    required List<int> categoryIds,
    required List<int> subcategoryIds,
  }) async {
    savedCategoryIds = List<int>.from(categoryIds);
    savedSubcategoryIds = List<int>.from(subcategoryIds);
    return _payload(subcategoryIds);
  }
}

void main() {
  testWidgets('guarda actividades específicas dentro de una categoría', (
    tester,
  ) async {
    final service = _FakeAccountService();
    await tester.pumpWidget(
      MaterialApp(home: ProviderCapabilitiesPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ir al cine'), findsOneWidget);
    expect(find.text('Tomar un café'), findsOneWidget);
    expect(find.text('1 actividad seleccionada'), findsOneWidget);

    final coffeeChip = find.widgetWithText(ChoiceChip, 'Tomar un café');
    expect(coffeeChip, findsOneWidget);
    await tester.ensureVisible(coffeeChip);
    await tester.pumpAndSettle();
    await tester.tap(coffeeChip);
    await tester.pumpAndSettle();

    // El resumen superior puede dejar de estar construido cuando la lista se
    // desplaza en el viewport de 800 x 600 de flutter test. Verificamos el
    // estado real del control y el contador del botón, que permanece ligado
    // a la misma selección.
    expect(tester.widget<ChoiceChip>(coffeeChip).selected, isTrue);

    final saveButton = find.text('Guardar 2 actividades');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(service.savedCategoryIds, [10]);
    expect(service.savedSubcategoryIds, [101, 102]);
    expect(find.text('Las actividades fueron guardadas.'), findsOneWidget);
  });
}
