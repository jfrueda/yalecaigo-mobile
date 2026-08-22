import 'package:dio/dio.dart';

const Map<String, String> _authFieldLabels = {
  'first_name': 'Nombres',
  'last_name': 'Apellidos',
  'birth_date': 'Fecha de nacimiento',
  'gender': 'Sexo',
  'email': 'Correo',
  'phone_number': 'Celular',
  'password': 'Contraseña',
  'country_code': 'País',
  'residence_place_id': 'Ciudad o municipio',
  'legal_document_ids': 'Términos y política de privacidad',
  'registration_token': 'Registro social',
};

String _labelForField(Object? key) {
  final raw = key?.toString() ?? '';
  return _authFieldLabels[raw] ?? raw.replaceAll('_', ' ');
}

List<String> _valueMessages(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .expand(_valueMessages)
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  if (value is Map) {
    final result = <String>[];
    for (final entry in value.entries) {
      for (final message in _valueMessages(entry.value)) {
        result.add('${_labelForField(entry.key)}: $message');
      }
    }
    return result;
  }
  final message = value.toString().trim();
  return message.isEmpty ? const [] : [message];
}

String readableAuthError(Object error) {
  if (error is FormatException) return error.message;
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final missingLabels = data['missing_field_labels'];
      if (missingLabels is List && missingLabels.isNotEmpty) {
        final labels = missingLabels
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        if (labels.isNotEmpty) {
          return 'Para continuar completa: ${labels.join(', ')}.';
        }
      }

      final fieldMessages = <String>[];
      for (final entry in data.entries) {
        final key = entry.key.toString();
        if ({
          'detail',
          'missing_fields',
          'missing_field_labels',
          'missing_details',
          'next_action',
        }.contains(key)) {
          continue;
        }
        final messages = _valueMessages(entry.value);
        for (final message in messages) {
          fieldMessages.add('${_labelForField(key)}: $message');
        }
      }
      if (fieldMessages.isNotEmpty) {
        return 'Revisa la siguiente información:\n• ${fieldMessages.join('\n• ')}';
      }

      final detail = data['detail'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'No pudimos conectarnos. Revisa tu conexión e intenta nuevamente.';
    }
    return 'No pudimos completar la solicitud. Intenta nuevamente.';
  }
  return 'No fue posible completar la operación.';
}
