import 'package:flutter/material.dart';

import '../../../core/utils/service_display.dart';
import '../../service_request/data/service_request_query_service.dart';
import 'provider_active_service_page.dart';

class ProviderHistoryPage extends StatefulWidget {
  const ProviderHistoryPage({super.key});

  @override
  State<ProviderHistoryPage> createState() => _ProviderHistoryPageState();
}

class _ProviderHistoryPageState extends State<ProviderHistoryPage> {
  final _queryService = ServiceRequestQueryService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _queryService.listProviderHistory();
  }

  Future<void> _refresh() async {
    setState(() => _future = _queryService.listProviderHistory());
    await _future;
  }

  double _toDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis servicios')),
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
            final requests = snapshot.data ?? const [];
            if (requests.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('Todavía no tienes servicios asignados.')),
                ],
              );
            }

            final finished = requests
                .where(
                  (item) => item['status']?.toString().toLowerCase() == 'ended',
                )
                .toList();
            final transferPending = requests.where((item) {
              final payment = item['payment'] is Map
                  ? Map<String, dynamic>.from(item['payment'] as Map)
                  : <String, dynamic>{};
              return payment['status']?.toString().toLowerCase() ==
                  'release_pending';
            }).toList();
            final transferred = requests.where((item) {
              final payment = item['payment'] is Map
                  ? Map<String, dynamic>.from(item['payment'] as Map)
                  : <String, dynamic>{};
              return payment['status']?.toString().toLowerCase() ==
                  'paid_to_provider';
            }).toList();
            final gross = requests.fold<double>(0, (sum, item) {
              final payment = item['payment'] is Map
                  ? Map<String, dynamic>.from(item['payment'] as Map)
                  : <String, dynamic>{};
              return sum + _toDouble(payment['amount_total']);
            });
            final net = requests.fold<double>(0, (sum, item) {
              final payment = item['payment'] is Map
                  ? Map<String, dynamic>.from(item['payment'] as Map)
                  : <String, dynamic>{};
              return sum + _toDouble(payment['provider_amount']);
            });
            final transferredValue = transferred.fold<double>(0, (sum, item) {
              final payment = item['payment'] is Map
                  ? Map<String, dynamic>.from(item['payment'] as Map)
                  : <String, dynamic>{};
              return sum + _toDouble(payment['provider_amount']);
            });

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const _SectionTitle('Dashboard del prestador'),
                _DashboardGrid(
                  children: [
                    _MetricCard(
                      icon: Icons.task_alt_outlined,
                      title: 'Servicios',
                      value: requests.length.toString(),
                      subtitle: 'Total aprobados/asignados',
                    ),
                    _MetricCard(
                      icon: Icons.verified_outlined,
                      title: 'Finalizados',
                      value: finished.length.toString(),
                      subtitle: 'Servicios completados',
                    ),
                    _MetricCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Cuenta esperada',
                      value: formatCop(net),
                      subtitle: 'Valor neto acumulado',
                    ),
                    _MetricCard(
                      icon: Icons.paid_outlined,
                      title: 'Transferido',
                      value: formatCop(transferredValue),
                      subtitle:
                          '${transferred.length} transferencias completas',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estado de cuenta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        _accountRow('Valor bruto gestionado', formatCop(gross)),
                        _accountRow('Valor neto acumulado', formatCop(net)),
                        _accountRow(
                          'Pendiente por transferir',
                          '${transferPending.length} servicio(s)',
                        ),
                        _accountRow(
                          'Transferencias realizadas',
                          '${transferred.length} servicio(s)',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionTitle('Histórico detallado'),
                ...requests.map(_card),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _accountRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> request) {
    final payment = request['payment'] is Map
        ? Map<String, dynamic>.from(request['payment'] as Map)
        : <String, dynamic>{};
    final transferDone =
        payment['status']?.toString().toLowerCase() == 'paid_to_provider';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: serviceStatusColor(request['status']),
          child: const Icon(Icons.work_outline, color: Colors.white),
        ),
        title: Text(request['category_name']?.toString() ?? 'Acompañamiento'),
        subtitle: Text(
          '${serviceStatusLabel(request['status'])}\n'
          '${formatDateTime(request['requested_start_time'])}\n'
          'Ganancia: ${formatCop(payment['provider_amount'])}\n'
          'Pago: ${paymentStatusLabel(payment['status'])}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (transferDone)
              const Icon(Icons.check_circle, color: Colors.green)
            else
              const Icon(Icons.schedule, color: Colors.orange),
            const SizedBox(height: 4),
            Text(
              transferDone ? 'Transferido' : 'Pendiente',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ProviderActiveServicePage(serviceRequest: request),
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
