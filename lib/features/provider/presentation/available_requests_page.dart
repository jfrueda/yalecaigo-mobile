import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'provider_request_detail_page.dart';

class AvailableRequestsPage extends StatefulWidget {
  const AvailableRequestsPage({super.key});

  @override
  State<AvailableRequestsPage> createState() => _AvailableRequestsPageState();
}

class _AvailableRequestsPageState extends State<AvailableRequestsPage> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.dio.get('/services/requests/available/');
      final data = List<Map<String, dynamic>>.from(res.data);
      setState(() => _requests = data);
    } catch (e) {
      if (e is DioException) {
        _error = e.response?.data.toString();
      } else {
        _error = e.toString();
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _card(Map<String, dynamic> r) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(r['location_text'] ?? 'Sin ubicación'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duración: ${r['requested_duration_minutes']} min'),
            Text('Inicio: ${r['requested_start_time']}'),
            Text('Valor: ${r['calculated_price'] ?? '-'} COP'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProviderRequestDetailPage(request: r),
            ),
          );

          // Si aceptó, refrescamos lista
          if (changed == true) {
            _loadRequests();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes disponibles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('❌ $_error'))
          : _requests.isEmpty
          ? const Center(child: Text('No hay solicitudes disponibles'))
          : ListView(
        padding: const EdgeInsets.all(12),
        children: _requests.map(_card).toList(),
      ),
    );
  }
}
