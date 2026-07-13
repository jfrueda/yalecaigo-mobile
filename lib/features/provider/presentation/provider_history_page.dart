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
                  Center(child: Text('No fue posible cargar: ${snapshot.error}')),
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
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: requests.length,
              itemBuilder: (context, index) => _card(requests[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> request) {
    final payment = request['payment'] is Map
        ? Map<String, dynamic>.from(request['payment'] as Map)
        : <String, dynamic>{};
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
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ProviderActiveServicePage(serviceRequest: request),
            ),
          );
          await _refresh();
        },
      ),
    );
  }
}
