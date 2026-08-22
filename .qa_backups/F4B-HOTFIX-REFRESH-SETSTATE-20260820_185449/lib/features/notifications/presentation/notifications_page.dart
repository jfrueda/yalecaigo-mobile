import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/app_components.dart';
import '../data/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _service = NotificationService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.listNotifications();
  }

  Future<void> _refresh() async {
    setState(() => _future = _service.listNotifications());
    await _future;
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible actualizar las notificaciones.'),
        ),
      );
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) return;
    final id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;
    try {
      await _service.markRead(id);
      await _refresh();
    } catch (_) {
      // La lectura no debe bloquear la consulta.
    }
  }

  IconData _iconFor(Map<String, dynamic> notification) {
    final payload = notification['payload'];
    final event = payload is Map ? payload['event']?.toString() : null;
    switch (event) {
      case 'provider_assigned':
        return Icons.person_pin_circle_outlined;
      case 'client_arrived':
      case 'provider_arrived':
        return Icons.place_outlined;
      case 'late_notice':
        return Icons.access_time_outlined;
      case 'service_started':
        return Icons.play_circle_outline;
      case 'service_finished':
        return Icons.flag_outlined;
      case 'payment_released':
        return Icons.paid_outlined;
      case 'incident_reported':
        return Icons.report_gmailerrorred_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorFor(Map<String, dynamic> notification) {
    final payload = notification['payload'];
    final event = payload is Map ? payload['event']?.toString() : null;
    switch (event) {
      case 'payment_released':
      case 'service_finished':
        return AppColors.success;
      case 'late_notice':
        return AppColors.warning;
      case 'incident_reported':
        return AppColors.danger;
      default:
        return AppColors.primaryMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Notificaciones'),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como leídas',
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: const [
                  SizedBox(height: 140),
                  AppEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'No pudimos cargar las notificaciones',
                    message: 'Desliza hacia abajo para intentar nuevamente.',
                  ),
                ],
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  AppEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'Todo al día',
                    message:
                        'Aquí aparecerán los cambios importantes de tu cuenta y actividades.',
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = items[index];
                final color = _colorFor(item);
                final unread = item['read_at'] == null;
                return AppSurfaceCard(
                  backgroundColor: unread
                      ? AppColors.tint(AppColors.primary, 0.045)
                      : null,
                  borderColor: unread
                      ? AppColors.tint(AppColors.primary, 0.28)
                      : null,
                  onTap: () => _markRead(item),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.tint(color, 0.13),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_iconFor(item), color: color),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['title']?.toString() ?? 'Notificación',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: unread
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                        ),
                                  ),
                                ),
                                if (unread)
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: AppColors.coral,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(item['body']?.toString() ?? ''),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              formatDateTime(item['created_at']),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
