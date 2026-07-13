import 'package:flutter/material.dart';

import '../../../core/utils/service_display.dart';
import '../data/service_request_query_service.dart';
import 'request_detail_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final _service = ServiceRequestQueryService();
  late Future<List<Map<String, dynamic>>> _future;

  static const _activeStatuses = {
    'pending_payment',
    'pending',
    'searching',
    'matched',
    'started',
  };

  @override
  void initState() {
    super.initState();
    _future = _service.listMyRequests();
  }

  Future<void> _refresh() async {
    setState(() => _future = _service.listMyRequests());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
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
                  Center(child: Text('No fue posible cargar: ${snapshot.error}')),
                ],
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('Todavía no tienes solicitudes.')),
                ],
              );
            }
            final active = items
                .where(
                  (item) => _activeStatuses.contains(
                    item['status']?.toString().toLowerCase(),
                  ),
                )
                .toList();
            final history = items
                .where(
                  (item) => !_activeStatuses.contains(
                    item['status']?.toString().toLowerCase(),
                  ),
                )
                .toList();
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (active.isNotEmpty) ...[
                  const _SectionTitle('Solicitud activa'),
                  ...active.map(_requestCard),
                  const SizedBox(height: 12),
                ],
                const _SectionTitle('Histórico'),
                if (history.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aún no tienes servicios finalizados o cancelados.'),
                    ),
                  )
                else
                  ...history.map(_requestCard),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final payment = request['payment'] is Map
        ? Map<String, dynamic>.from(request['payment'] as Map)
        : <String, dynamic>{};
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: serviceStatusColor(request['status']),
          child: const Icon(Icons.people, color: Colors.white),
        ),
        title: Text(
          request['category_name']?.toString() ?? 'Acompañamiento',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${serviceStatusLabel(request['status'])}\n'
          '${request['location_text'] ?? 'Sin ubicación'}\n'
          '${formatDateTime(request['requested_start_time'])}\n'
          'Pago: ${paymentStatusLabel(payment['status'])}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => RequestDetailPage(request: request),
            ),
          );
          await _refresh();
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
