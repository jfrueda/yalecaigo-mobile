import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
      return 'Actividad en curso';
    case 'ended':
      return 'Actividad finalizada';
    case 'cancelled':
      return 'Actividad cancelada';
    case 'expired':
      return 'Solicitud vencida';
    case 'incident':
      return 'En revisión';
    default:
      return value?.toString() ?? 'Sin estado';
  }
}

Color serviceStatusColor(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'pending_payment':
      return AppColors.warning;
    case 'pending':
    case 'searching':
      return AppColors.information;
    case 'matched':
      return AppColors.primaryMedium;
    case 'started':
      return AppColors.success;
    case 'ended':
      return AppColors.secondary;
    case 'cancelled':
    case 'expired':
      return AppColors.textSecondary;
    case 'incident':
      return AppColors.danger;
    default:
      return AppColors.information;
  }
}

IconData serviceStatusIcon(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'pending_payment':
      return Icons.lock_clock_outlined;
    case 'pending':
    case 'searching':
      return Icons.search_rounded;
    case 'matched':
      return Icons.person_pin_circle_outlined;
    case 'started':
      return Icons.play_circle_outline_rounded;
    case 'ended':
      return Icons.check_circle_outline_rounded;
    case 'cancelled':
      return Icons.cancel_outlined;
    case 'expired':
      return Icons.event_busy_outlined;
    case 'incident':
      return Icons.report_gmailerrorred_outlined;
    default:
      return Icons.info_outline_rounded;
  }
}

String paymentStatusLabel(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'pending':
      return 'Pendiente';
    case 'approved':
      return 'Aprobado';
    case 'held':
      return 'Pago protegido';
    case 'release_pending':
      return 'Transferencia pendiente';
    case 'paid_to_provider':
      return 'Transferencia realizada';
    case 'refunded':
      return 'Reembolsado';
    case 'failed':
      return 'Fallido';
    default:
      return value?.toString() ?? 'Sin pago';
  }
}

Color paymentStatusColor(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'paid_to_provider':
      return AppColors.success;
    case 'held':
    case 'approved':
      return AppColors.primaryMedium;
    case 'release_pending':
    case 'pending':
      return AppColors.warning;
    case 'refunded':
      return AppColors.information;
    case 'failed':
      return AppColors.danger;
    default:
      return AppColors.textSecondary;
  }
}

String encounterStatusLabel(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'client_arrived':
      return 'El solicitante ya llegó';
    case 'provider_arrived':
      return 'El acompañante ya llegó';
    case 'both_arrived':
      return 'Ambos están en el punto';
    case 'confirmed':
      return 'Encuentro confirmado';
    case 'not_arrived':
      return 'Esperando llegada';
    default:
      return value?.toString() ?? 'Sin información';
  }
}

String formatDateTime(dynamic raw) {
  if (raw == null) {
    return '—';
  }
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) {
    return raw.toString();
  }
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String formatShortDateTime(dynamic raw) {
  if (raw == null) {
    return '—';
  }
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) {
    return raw.toString();
  }
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} · ${two(local.hour)}:${two(local.minute)}';
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
  return '\$${buffer.toString()}';
}

String formatDistance(dynamic raw) {
  final meters = double.tryParse(raw?.toString() ?? '');
  if (meters == null) {
    return 'Sin ubicación de ambas personas';
  }
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}
