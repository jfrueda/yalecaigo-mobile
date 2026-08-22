import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/network/endpoints.dart';

void main() {
  test('El endpoint del teléfono de seguridad usa la ruta autenticada', () {
    expect(Endpoints.securityPhone, '/auth/security-phone/');
  });
}
