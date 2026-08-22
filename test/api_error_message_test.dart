import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/utils/api_error_message.dart';

void main() {
  test('muestra requisitos pendientes con etiquetas legibles', () {
    final error = DioException(
      requestOptions: RequestOptions(
        path: '/api/auth/provider-profile/submit-review/',
      ),
      response: Response<dynamic>(
        requestOptions: RequestOptions(
          path: '/api/auth/provider-profile/submit-review/',
        ),
        statusCode: 400,
        data: <String, dynamic>{
          'detail': 'El perfil todavía tiene información pendiente.',
          'missing_field_labels': <String>[
            'Contacto de emergencia',
            'Disponibilidad configurada',
          ],
        },
      ),
    );

    final message = apiErrorMessage(error);
    expect(message, contains('Contacto de emergencia'));
    expect(message, contains('Disponibilidad configurada'));
  });
}
