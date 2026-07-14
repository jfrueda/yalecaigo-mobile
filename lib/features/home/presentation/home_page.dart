import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/token_storage.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/service_rating_dialog.dart';
import '../../auth/data/me_service.dart';
import '../../auth/presentation/login_page.dart';
import '../../service_request/data/service_lifecycle_service.dart';
import '../../service_request/data/service_request_query_service.dart';
import '../../service_request/presentation/create_request_page.dart';
import '../../service_request/presentation/my_requests_page.dart';
import '../../service_request/presentation/request_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _queryService = ServiceRequestQueryService();
  final _meService = MeService();
  final _lifecycleService = ServiceLifecycleService();

  Map<String, dynamic>? _activeRequest;
  Map<String, dynamic>? _me;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _meService.getMe();
      final active = await _queryService.getActiveRequest();
      if (!mounted) return;
      setState(() {
        _me = me;
        _activeRequest = active;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar la información del usuario.');
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

  Future<void> _openActive() async {
    final request = _activeRequest;
    if (request == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RequestDetailPage(request: request),
      ),
    );
    await _load();
  }

  Future<void> _finishAndRate(Map<String, dynamic> request) async {
    final requestId = _requestId(request);
    if (requestId == null) return;

    final rating = await showRequiredServiceRatingDialog(
      context,
      targetLabel: 'el prestador',
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
            : 'Finalización y calificación registradas. Falta la confirmación del prestador.',
      );
      await _load();
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
      targetLabel: 'el prestador',
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
      await _load();
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
        title: const Text('YaLeCaigo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Hola, ${_me?['username'] ?? 'usuario'}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Solicita compañía para una actividad o diligencia.',
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!),
                      ),
                    )
                  else if (_activeRequest != null)
                    _activeCard(_activeRequest!)
                  else
                    _newRequestCard(),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyRequestsPage(),
                        ),
                      );
                      await _load();
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('Ver mis solicitudes'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _newRequestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.people_alt_outlined, size: 54),
            const SizedBox(height: 12),
            const Text(
              '¿Necesitas acompañamiento?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea una solicitud, confirma el pago demo y encuentra un prestador disponible.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateRequestPage(),
                  ),
                );
                await _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear solicitud'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeCard(Map<String, dynamic> request) {
    final payment = request['payment'] is Map
        ? Map<String, dynamic>.from(request['payment'] as Map)
        : <String, dynamic>{};
    final status = request['status']?.toString().toLowerCase() ?? '';
    final canFinish = _bool(request['can_finish']);
    final clientFinished = request['client_finished_at'] != null;
    final hasRating = request['my_rating'] is Map;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.timelapse, color: serviceStatusColor(status)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    serviceStatusLabel(status),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(request['category_name']?.toString() ?? 'Acompañamiento'),
            Text(request['location_text']?.toString() ?? 'Sin ubicación'),
            Text('Inicio: ${formatDateTime(request['requested_start_time'])}'),
            if (request['assigned_provider_username'] != null)
              Text('Prestador: ${request['assigned_provider_username']}'),
            const Divider(height: 24),
            Text('Pago: ${paymentStatusLabel(payment['status'])}'),
            if (status == 'started' && clientFinished) ...[
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.hourglass_top, color: Colors.orange),
                title: Text('Ya confirmaste la finalización'),
                subtitle: Text(
                  'Estamos esperando la confirmación del prestador.',
                ),
              ),
            ],
            if (canFinish) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _actionLoading
                    ? null
                    : () => _finishAndRate(request),
                icon: const Icon(Icons.flag),
                label: const Text('Finalizar y calificar'),
              ),
              const Text(
                'Puedes cerrar tu parte del servicio sin entrar al detalle.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ] else if (clientFinished && !hasRating) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _actionLoading ? null : () => _rateOnly(request),
                icon: const Icon(Icons.star),
                label: const Text('Calificar al prestador'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openActive,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ver servicio activo'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mientras esta solicitud siga activa no podrás crear otra.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
