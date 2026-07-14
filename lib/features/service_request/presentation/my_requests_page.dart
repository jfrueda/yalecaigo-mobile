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

  double _toDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

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
            final totalValue = items.fold<double>(
              0,
              (sum, item) => sum + _toDouble(item['calculated_price']),
            );
            final finishedValue = history.fold<double>(
              0,
              (sum, item) => sum + _toDouble(item['calculated_price']),
            );
            final byStatus = <String, int>{};
            for (final item in items) {
              final status =
                  item['status']?.toString().toLowerCase() ?? 'unknown';
              byStatus[status] = (byStatus[status] ?? 0) + 1;
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const _SectionTitle('Dashboard del solicitante'),
                _DashboardGrid(
                  children: [
                    _MetricCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Solicitudes',
                      value: items.length.toString(),
                      subtitle: 'Total registradas',
                    ),
                    _MetricCard(
                      icon: Icons.timelapse_outlined,
                      title: 'Activas',
                      value: active.length.toString(),
                      subtitle: 'En curso o gestión',
                    ),
                    _MetricCard(
                      icon: Icons.payments_outlined,
                      title: 'Valor total',
                      value: formatCop(totalValue),
                      subtitle: 'Todas tus solicitudes',
                    ),
                    _MetricCard(
                      icon: Icons.task_alt_outlined,
                      title: 'Finalizadas',
                      value: '${byStatus['ended'] ?? 0}',
                      subtitle: formatCop(finishedValue),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(
                          label: 'Pendientes pago',
                          count: byStatus['pending_payment'] ?? 0,
                        ),
                        _StatusChip(
                          label: 'Buscando',
                          count: byStatus['searching'] ?? 0,
                        ),
                        _StatusChip(
                          label: 'Encuentro',
                          count: byStatus['matched'] ?? 0,
                        ),
                        _StatusChip(
                          label: 'En curso',
                          count: byStatus['started'] ?? 0,
                        ),
                        _StatusChip(
                          label: 'Finalizadas',
                          count: byStatus['ended'] ?? 0,
                        ),
                        _StatusChip(
                          label: 'Canceladas',
                          count: byStatus['cancelled'] ?? 0,
                        ),
                      ],
                    ),
                  ),
                ),
                if (active.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionTitle('Solicitud activa'),
                  ...active.map(_requestCard),
                ],
                const SizedBox(height: 12),
                const _SectionTitle('Histórico'),
                if (history.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Aún no tienes servicios finalizados o cancelados.',
                      ),
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
          'Valor: ${formatCop(request['calculated_price'])} · Pago: ${paymentStatusLabel(payment['status'])}',
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

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: children
          .map(
            (child) => SizedBox(
              width: (MediaQuery.of(context).size.width - 34) / 2,
              child: child,
            ),
          )
          .toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $count'));
  }
}
