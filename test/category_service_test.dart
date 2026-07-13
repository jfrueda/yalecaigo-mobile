import 'package:flutter_test/flutter_test.dart';
import 'package:yalecaigo/features/service_request/data/category_service.dart';

void main() {
  test('CategoryItem acepta name, title o label', () {
    expect(
      CategoryItem.fromJson({'id': 1, 'name': 'Acompañamiento'}).name,
      'Acompañamiento',
    );
    expect(
      CategoryItem.fromJson({'id': '2', 'title': 'Diligencias'}).id,
      2,
    );
    expect(
      CategoryItem.fromJson({'id': 3, 'label': 'Compras'}).name,
      'Compras',
    );
  });
}
