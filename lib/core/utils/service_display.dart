import 'package:flutter/material.dart';

String serviceStatusLabel(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'pending_payment':
      return 'Pendiente de pago';
    case 'pending':
      return 'Pendiente';
    case 'searching':
      return 'Buscando acompañante';
    case 'matched':
      return 'Pendiente de encuentro';
    case 'started':
      return 'Servicio en curso';
    case 'ended':
      return 'Servicio finalizado';
    case 'cancelled':
      return 'Servicio cancelado';
    case 'expired':
      return 'Solicitud vencida';
    case 'incident':
      return 'Servicio en revisión';
    default:
      return value?.toString() ?? 'Sin estado';
  }
}

Color serviceStatusColor(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'pending_payment':
      return Colors.deepOrange;
    case 'pending':
    case 'searching':
      return Colors.amber.shade800;
    case 'matched':
      return Colors.blue;
    case 'started':
      return Colors.green;
    case 'ended':
      return Colors.teal;
    case 'cancelled':
    case 'expired':
      return Colors.grey;
    case 'incident':
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

String paymentStatusLabel(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'pending':
      return 'Pendiente';
    case 'approved':
      return 'Aprobado';
    case 'held':
      return 'Pago reservado';
    case 'release_pending':
      return 'Pendiente de transferir';
    case 'paid_to_provider':
      return 'Pagado al prestador';
    case 'refunded':
      return 'Reembolsado';
    case 'failed':
      return 'Fallido';
    default:
      return value?.toString() ?? 'Sin pago';
  }
}

String encounterStatusLabel(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'client_arrived':
      return 'El solicitante llegó';
    case 'provider_arrived':
      return 'El prestador llegó';
    case 'both_arrived':
      return 'Ambos confirmaron llegada';
    case 'confirmed':
      return 'Encuentro confirmado';
    case 'not_arrived':
      return 'Esperando llegada';
    default:
      return value?.toString() ?? 'Sin información';
  }
}

String formatDateTime(dynamic raw) {
  if (raw == null) return '—';
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return raw.toString();
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String formatCop(dynamic raw) {
  final value = double.tryParse(raw?.toString() ?? '0') ?? 0;
  final integer = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < integer.length; index++) {
    final remaining = integer.length - index;
    buffer.write(integer[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }
  return '\$${buffer.toString()} COP';
}

String formatDistance(dynamic raw) {
  final meters = double.tryParse(raw?.toString() ?? '');
  if (meters == null) return 'Sin ubicación de ambas personas';
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}
