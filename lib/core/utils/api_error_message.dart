import 'package:dio/dio.dart';

String _humanizeField(String value) {
  const labels = <String, String>{
    'first_name': 'Nombres',
    'last_name': 'Apellidos',
    'birth_date': 'Fecha de nacimiento',
    'minimum_age': 'Mayoría de edad',
    'city': 'Ciudad',
    'country': 'País',
    'profile_photo': 'Fotografía de perfil',
    'emergency_contact': 'Contacto de emergencia',
    'biography': 'Descripción pública',
    'experience_summary': 'Experiencia',
    'spoken_languages': 'Idiomas',
    'activities': 'Actividades',
    'availability': 'Disponibilidad',
  };
  return labels[value] ?? value.replaceAll('_', ' ');
}

List<String> _collectMessages(Object? value, {String? field}) {
  if (value == null) return const [];

  if (value is Map) {
    final map = Map<Object?, Object?>.from(value);
    final labels = map['missing_field_labels'];
    if (labels is List && labels.isNotEmpty) {
      final values = labels
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (values.isNotEmpty) {
        return ['Completa: ${values.join(', ')}.'];
      }
    }

    final missing = map['missing_fields'];
    if (missing is List && missing.isNotEmpty) {
      final values = missing
          .map((item) => _humanizeField(item.toString()))
          .toList();
      return ['Completa: ${values.join(', ')}.'];
    }

    final result = <String>[];
    for (final entry in map.entries) {
      if (entry.key == 'detail' && entry.value != null) {
        final detail = entry.value.toString().trim();
        if (detail.isNotEmpty) result.add(detail);
        continue;
      }
      final nested = _collectMessages(
        entry.value,
        field: entry.key?.toString(),
      );
      for (final message in nested) {
        if (message.isEmpty) continue;
        final label = entry.key?.toString() ?? '';
        if (label.isNotEmpty &&
            label != 'non_field_errors' &&
            !message.startsWith('Completa:')) {
          result.add('${_humanizeField(label)}: $message');
        } else {
          result.add(message);
        }
      }
    }
    return result;
  }

  if (value is List) {
    return value
        .expand((item) => _collectMessages(item, field: field))
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  final text = value.toString().trim();
  return text.isEmpty ? const [] : [text];
}

String apiErrorMessage(Object error, {String fallback = 'Ocurrió un error.'}) {
  if (error is DioException) {
    final messages = _collectMessages(error.response?.data);
    if (messages.isNotEmpty) {
      return messages.toSet().take(4).join('\n');
    }
    final transport = error.message?.trim();
    if (transport != null && transport.isNotEmpty) return transport;
  }
  if (error is FormatException && error.message.isNotEmpty) {
    return error.message;
  }
  return fallback;
}
