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
    case 'no_show':
      return 'No presentado';
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
    case 'no_show':
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
    case 'no_show':
      return Icons.person_off_outlined;
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

String serviceActivityLabel(Map<String, dynamic> request) {
  final activityName = request['activity_name']?.toString().trim() ?? '';
  if (activityName.isNotEmpty) return activityName;
  final custom = request['custom_activity_name']?.toString().trim() ?? '';
  if (custom.isNotEmpty) return custom;
  final subcategory = request['subcategory_name']?.toString().trim() ?? '';
  if (subcategory.isNotEmpty) return subcategory;
  final category = request['category_name']?.toString().trim() ?? '';
  return category.isNotEmpty ? category : 'Actividad';
}

String serviceCategoryLabel(Map<String, dynamic> request) {
  final category = request['category_name']?.toString().trim() ?? '';
  return category.isNotEmpty ? category : 'Sin categoría';
}

IconData activityIconFromCode(dynamic rawCode) {
  switch (rawCode?.toString().toLowerCase()) {
    case 'movie':
      return Icons.movie_outlined;
    case 'restaurant':
      return Icons.restaurant_outlined;
    case 'coffee':
      return Icons.local_cafe_outlined;
    case 'music':
      return Icons.music_note_outlined;
    case 'event':
    case 'festival':
      return Icons.event_outlined;
    case 'museum':
    case 'gallery':
      return Icons.museum_outlined;
    case 'chat':
      return Icons.forum_outlined;
    case 'groups':
      return Icons.groups_outlined;
    case 'park':
    case 'nature':
      return Icons.park_outlined;
    case 'hiking':
      return Icons.hiking_outlined;
    case 'tour':
      return Icons.tour_outlined;
    case 'sports':
      return Icons.sports_soccer_outlined;
    case 'games':
      return Icons.casino_outlined;
    case 'celebration':
      return Icons.celebration_outlined;
    case 'camera':
      return Icons.photo_camera_outlined;
    case 'shopping_cart':
      return Icons.shopping_cart_outlined;
    case 'apparel':
      return Icons.checkroom_outlined;
    case 'shopping_bag':
      return Icons.shopping_bag_outlined;
    case 'package':
      return Icons.inventory_2_outlined;
    case 'mall':
      return Icons.store_mall_directory_outlined;
    case 'task':
      return Icons.task_alt_outlined;
    case 'description':
      return Icons.description_outlined;
    case 'business':
      return Icons.business_outlined;
    case 'directions_walk':
      return Icons.directions_walk_outlined;
    case 'fitness':
      return Icons.fitness_center_outlined;
    case 'class':
      return Icons.co_present_outlined;
    case 'spa':
      return Icons.spa_outlined;
    case 'self_care':
      return Icons.self_improvement_outlined;
    case 'library':
      return Icons.local_library_outlined;
    case 'record_voice':
      return Icons.record_voice_over_outlined;
    case 'workshop':
      return Icons.handyman_outlined;
    case 'language':
      return Icons.language_outlined;
    case 'history':
      return Icons.history_edu_outlined;
    case 'school':
      return Icons.school_outlined;
    case 'pets':
    case 'pets_park':
    case 'pet_store':
    case 'pet_activity':
      return Icons.pets_outlined;
    case 'other':
      return Icons.auto_awesome_outlined;
    default:
      return Icons.category_outlined;
  }
}

String operationalStageLabel(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'pending_payment':
      return 'Pendiente de pago';
    case 'published':
      return 'Publicada';
    case 'accepted':
      return 'Aceptada';
    case 'confirmed':
      return 'Confirmada';
    case 'en_route':
      return 'Acompañante en camino';
    case 'arrival_partial':
      return 'Llegada parcial';
    case 'ready_to_start':
      return 'Listos para iniciar';
    case 'in_progress':
      return 'En curso';
    case 'completion_pending':
      return 'Pendiente de confirmar cierre';
    case 'completed':
      return 'Finalizada';
    case 'cancelled':
      return 'Cancelada';
    case 'no_show':
      return 'No presentado';
    case 'incident':
      return 'En revisión';
    case 'expired':
      return 'Vencida';
    default:
      return value?.toString() ?? 'Sin estado';
  }
}

IconData operationalStageIcon(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'confirmed':
      return Icons.verified_outlined;
    case 'en_route':
      return Icons.directions_walk_outlined;
    case 'arrival_partial':
      return Icons.location_on_outlined;
    case 'ready_to_start':
      return Icons.handshake_outlined;
    case 'in_progress':
      return Icons.play_circle_outline_rounded;
    case 'completion_pending':
      return Icons.fact_check_outlined;
    case 'completed':
      return Icons.check_circle_outline_rounded;
    case 'cancelled':
      return Icons.cancel_outlined;
    case 'no_show':
      return Icons.person_off_outlined;
    case 'incident':
      return Icons.report_gmailerrorred_outlined;
    case 'accepted':
      return Icons.event_available_outlined;
    case 'published':
      return Icons.campaign_outlined;
    default:
      return Icons.info_outline_rounded;
  }
}
