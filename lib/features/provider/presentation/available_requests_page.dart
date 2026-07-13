import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/token_storage.dart';
import '../../auth/presentation/login_page.dart';
import '../../service_request/data/service_request_query_service.dart';
import 'provider_active_service_page.dart';
import 'provider_request_detail_page.dart';

class AvailableRequestsPage extends StatefulWidget {
  const AvailableRequestsPage({super.key});

  @override
  State<AvailableRequestsPage> createState() => _AvailableRequestsPageState();
}

class _AvailableRequestsPageState extends State<AvailableRequestsPage> {
  final _queryService = ServiceRequestQueryService();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _activeRequest;
  List<Map<String, dynamic>> _requests = const [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final active = await _queryService.getActiveRequest(
        fallbackToList: false,
      );

      List<Map<String, dynamic>> requests = const [];
      if (active == null) {
        final response = await ApiClient.dio.get(Endpoints.availableRequests);
        requests = _asList(response.data);
      }

      if (!mounted) return;
      setState(() {
        _activeRequest = active;
        _requests = requests;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final status = error.response?.statusCode;
      setState(() {
        _error = status == 403
            ? 'La cuenta de prestador todavía no está verificada o no tiene permiso.'
            : 'No se pudo cargar el panel del prestador '
                  '(HTTP ${status ?? '-'}).';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'La respuesta del backend no es válida.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    dynamic raw = data;
    if (raw is Map && raw['results'] is List) {
      raw = raw['results'];
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _logout() async {
    await TokenStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Widget _activeCard(Map<String, dynamic> request) {
    final status = request['status']?.toString() ?? '-';
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tienes un servicio activo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(request['location_text']?.toString() ?? 'Sin ubicación'),
            Text('Estado: $status'),
            Text('Cliente: ${request['client_username']?.toString() ?? '-'}'),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.directions_walk),
              label: const Text('Abrir servicio activo'),
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProviderActiveServicePage(serviceRequest: request),
                  ),
                );
                await _loadDashboard();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(request['location_text']?.toString() ?? 'Sin ubicación'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categoría: ${request['category_name']?.toString() ?? '-'}'),
            Text(
              'Duración: '
              '${request['requested_duration_minutes'] ?? '-'} min',
            ),
            Text('Inicio: ${request['requested_start_time'] ?? '-'}'),
            Text('Valor: ${request['calculated_price'] ?? '-'} COP'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => ProviderRequestDetailPage(request: request),
            ),
          );
          if (changed == true) await _loadDashboard();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del prestador'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadDashboard,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _loading && _activeRequest == null && _requests.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              )
            : _activeRequest != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [_activeCard(_activeRequest!)],
              )
            : _requests.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('No hay solicitudes disponibles')),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: _requests.map(_requestCard).toList(),
              ),
      ),
    );
  }
}
