import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/token_storage.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/service_rating_dialog.dart';
import '../../auth/presentation/login_page.dart';
import '../../service_request/data/service_lifecycle_service.dart';
import '../../service_request/data/service_request_query_service.dart';
import 'provider_active_service_page.dart';
import 'provider_history_page.dart';
import 'provider_request_detail_page.dart';

class AvailableRequestsPage extends StatefulWidget {
  const AvailableRequestsPage({super.key});

  @override
  State<AvailableRequestsPage> createState() => _AvailableRequestsPageState();
}

class _AvailableRequestsPageState extends State<AvailableRequestsPage> {
  final _queryService = ServiceRequestQueryService();
  final _lifecycleService = ServiceLifecycleService();

  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  Map<String, dynamic>? _activeRequest;
  List<Map<String, dynamic>> _requests = const [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  bool _bool(dynamic value) => value == true;

  int? _requestId(Map<String, dynamic> request) {
    final value = request['id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final value = data['detail'] ?? data['score'] ?? data.values.firstOrNull;
      if (value != null) return value.toString();
    }
    return error.message ?? 'No fue posible completar la operación.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final active = await _queryService.getActiveRequest(
        fallbackToList: false,
      );
      final available = active == null
          ? await _queryService.listAvailableRequests()
          : const <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _activeRequest = active;
        _requests = available;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.response?.statusCode == 403
            ? 'La cuenta de prestador todavía no está verificada.'
            : 'No se pudo cargar el panel del prestador.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _finishAndRate(Map<String, dynamic> request) async {
    final requestId = _requestId(request);
    if (requestId == null) return;

    final rating = await showRequiredServiceRatingDialog(
      context,
      targetLabel: 'el solicitante',
    );
    if (rating == null || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      final updated = await _lifecycleService.finish(requestId);
      try {
        await _lifecycleService.rate(
          requestId: requestId,
          score: rating.score,
          comment: rating.comment,
        );
      } on DioException catch (error) {
        _showMessage(
          'La finalización quedó registrada, pero la calificación no pudo guardarse: ${_errorMessage(error)}',
        );
      }

      if (!mounted) return;
      final status = updated['status']?.toString().toLowerCase();
      _showMessage(
        status == 'ended'
            ? 'Servicio finalizado y calificación registrada.'
            : 'Finalización y calificación registradas. Falta la confirmación del solicitante.',
      );
      await _loadDashboard();
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _rateOnly(Map<String, dynamic> request) async {
    final requestId = _requestId(request);
    if (requestId == null) return;

    final rating = await showRequiredServiceRatingDialog(
      context,
      targetLabel: 'el solicitante',
      includeFinishMessage: false,
    );
    if (rating == null || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      await _lifecycleService.rate(
        requestId: requestId,
        score: rating.score,
        comment: rating.comment,
      );
      _showMessage('Calificación registrada.');
      await _loadDashboard();
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del prestador'),
        actions: [
          IconButton(
            tooltip: 'Histórico',
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const ProviderHistoryPage(),
                ),
              );
              await _loadDashboard();
            },
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
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
                padding: const EdgeInsets.all(16),
                children: [_activeCard(_activeRequest!)],
              )
            : _requests.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text('No hay solicitudes pagadas disponibles.'),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      'Solicitudes cercanas disponibles',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._requests.map(_requestCard),
                ],
              ),
      ),
    );
  }

  Widget _activeCard(Map<String, dynamic> request) {
    final status = request['status']?.toString().toLowerCase() ?? '';
    final canFinish = _bool(request['can_finish']);
    final providerFinished = request['provider_finished_at'] != null;
    final hasRating = request['my_rating'] is Map;

    return Card(
      color: serviceStatusColor(status).withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              serviceStatusLabel(status),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Solicitante: ${request['client_username'] ?? '—'}'),
            Text('Actividad: ${request['category_name'] ?? '—'}'),
            Text('Punto: ${request['location_text'] ?? '—'}'),
            Text('Hora: ${formatDateTime(request['requested_start_time'])}'),
            if (status == 'started' && providerFinished) ...[
              const SizedBox(height: 10),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.hourglass_top, color: Colors.orange),
                title: Text('Ya confirmaste la finalización'),
                subtitle: Text(
                  'Estamos esperando la confirmación del solicitante.',
                ),
              ),
            ],
            if (canFinish) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _actionLoading
                    ? null
                    : () => _finishAndRate(request),
                icon: const Icon(Icons.flag),
                label: const Text('Finalizar y calificar'),
              ),
              const Text(
                'Puedes cerrar tu parte del servicio desde esta pantalla.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ] else if (providerFinished && !hasRating) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _actionLoading ? null : () => _rateOnly(request),
                icon: const Icon(Icons.star),
                label: const Text('Calificar al solicitante'),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProviderActiveServicePage(serviceRequest: request),
                  ),
                );
                await _loadDashboard();
              },
              icon: const Icon(Icons.directions_walk),
              label: const Text('Abrir servicio activo'),
            ),
          ],
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
        leading: const CircleAvatar(child: Icon(Icons.person_search)),
        title: Text(request['category_name']?.toString() ?? 'Acompañamiento'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request['location_text']?.toString() ?? 'Sin ubicación'),
            Text('Inicio: ${formatDateTime(request['requested_start_time'])}'),
            Text(
              'Duración: ${request['requested_duration_minutes'] ?? '—'} min',
            ),
            Text(
              'Ganancia estimada: ${formatCop(payment['provider_amount'])}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => ProviderRequestDetailPage(request: request),
            ),
          );
          if (changed == true) await _loadDashboard();
        },
      ),
    );
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
