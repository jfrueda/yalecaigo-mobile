import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/network/endpoints.dart';

void main() {
  test('expone rutas de seguridad de cuenta', () {
    expect(Endpoints.changePassword, '/auth/change-password/');
    expect(Endpoints.socialUnlink('GOOGLE'), '/auth/social/google/unlink/');
  });
}
