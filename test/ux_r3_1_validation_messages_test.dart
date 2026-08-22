import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/features/auth/presentation/auth_error.dart';

void main() {
  test('registration validation reports every field with a friendly label', () {
    final request = RequestOptions(path: '/auth/register');
    final error = DioException(
      requestOptions: request,
      response: Response<dynamic>(
        requestOptions: request,
        statusCode: 400,
        data: <String, dynamic>{
          'email': <String>['Ya existe una cuenta con este correo.'],
          'gender': <String>['Este campo es obligatorio.'],
        },
      ),
    );

    final message = readableAuthError(error);
    expect(message, contains('Correo'));
    expect(message, contains('Sexo'));
    expect(message, contains('Ya existe una cuenta'));
  });

  test('missing field labels are preferred over a generic detail', () {
    final request = RequestOptions(path: '/provider/submit');
    final error = DioException(
      requestOptions: request,
      response: Response<dynamic>(
        requestOptions: request,
        statusCode: 400,
        data: <String, dynamic>{
          'detail': 'El perfil todavía tiene información pendiente.',
          'missing_field_labels': <String>[
            'Descripción pública',
            'Persona de confianza',
          ],
        },
      ),
    );

    final message = readableAuthError(error);
    expect(message, contains('Descripción pública'));
    expect(message, contains('Persona de confianza'));
    expect(message, isNot(contains('información pendiente')));
  });
}
