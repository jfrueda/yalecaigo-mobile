import 'package:flutter/material.dart';

import '../../../core/utils/service_display.dart';
import '../data/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService();
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
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
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
                children: [
                  const SizedBox(height: 180),
                  Center(
                    child: Text('No fue posible cargar: ${snapshot.error}'),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Center(child: Text('Aún no tienes notificaciones.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(_iconFor(item))),
                    title: Text(
                      item['title']?.toString() ?? 'Notificación',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${item['body'] ?? ''}\n${formatDateTime(item['created_at'])}',
                    ),
                    isThreeLine: true,
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
