import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/service_rating_dialog.dart';
import '../../../shared/widgets/service_schedule_dialogs.dart';
import '../../safety/presentation/service_sos_panel.dart';
import '../../tracking/data/device_location_service.dart';
import '../../tracking/presentation/service_tracking_panel.dart';
import '../../trust/presentation/provider_reputation_page.dart';
import '../../trust/presentation/trust_dialogs.dart';
import '../data/location_ping_service.dart';
import '../data/payment_service.dart';
import '../data/service_lifecycle_service.dart';
import '../data/service_request_query_service.dart';
import '../data/trust_service.dart';

class RequestDetailPage extends StatefulWidget {
  const RequestDetailPage({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  final _queryService = ServiceRequestQueryService();
  final _paymentService = PaymentService();
  final _lifecycleService = ServiceLifecycleService();
  final _pingService = LocationPingService();
  final _deviceLocationService = DeviceLocationService();
  final _trustService = TrustService();

  late Map<String, dynamic> _request;
  Timer? _timer;
  bool _loading = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _request = Map<String, dynamic>.from(widget.request);
    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _reload(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int? get _id {
    final value = _request['id'];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String get _status => _request['status']?.toString().toLowerCase() ?? '';

  Map<String, dynamic> get _payment {
    final raw = _request['payment'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  double _double(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  bool _bool(dynamic value) => value == true;

  Future<void> _reload({bool silent = false}) async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }
    if (!silent) {
      setState(() => _refreshing = true);
    }
    try {
      final fresh = await _queryService.getRequestById(requestId);
      if (!mounted || fresh == null) {
        return;
      }
      setState(() => _request = fresh);
    } on DioException catch (error) {
      if (!silent) {
        _showMessage(_errorMessage(error));
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<bool> _runAction(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    setState(() => _loading = true);
    try {
      final updated = await action();
      if (!mounted) {
        return false;
      }
      setState(() => _request = updated);
      return true;
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
      return false;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['code'] ?? data.values.firstOrNull;
      if (detail != null) {
        return detail.toString();
      }
    }
    return error.message ?? 'No fue posible completar la operación.';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _simulatePayment() async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      await _paymentService.simulateApproval(requestId);
      await _reload();
      _showMessage('Pago demo aprobado. Ya estamos buscando acompañante.');
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirmParticipation() async {
    final requestId = _id;
    if (requestId == null) return;
    final succeeded = await _runAction(
      () => _lifecycleService.confirmParticipation(requestId),
    );
    if (succeeded) {
      _showMessage('Tu participación quedó confirmada.');
    }
  }

  Future<void> _reportNoShow() async {
    final requestId = _id;
    if (requestId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar que no se presentó'),
        content: const Text(
          'Usa esta opción únicamente si ya estás en el punto, pasó el tiempo de espera y el acompañante no llegó.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reportar ausencia'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final succeeded = await _runAction(
      () => _lifecycleService.reportNoShow(requestId),
    );
    if (succeeded) {
      _showMessage('La actividad quedó cerrada por ausencia.');
    }
  }

  Future<void> _confirmArrival() async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final position = await _deviceLocationService.currentPosition();
      await _pingService.createPing(
        serviceRequestId: requestId,
        locationLat: position.latitude,
        locationLng: position.longitude,
        accuracy: position.accuracy,
        source: 'arrival_confirmation_gps',
      );
      final updated = await _lifecycleService.arrive(requestId);
      if (!mounted) {
        return;
      }
      setState(() => _request = updated);
      _showMessage('Llegada confirmada con la ubicación real del dispositivo.');
    } on DeviceLocationException catch (error) {
      _showMessage(error.message);
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } catch (error) {
      _showMessage('No fue posible obtener la ubicación: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cancel() async {
    final requestId = _id;
    if (requestId == null) return;
    final result = await showServiceCancellationDialog(
      context,
      isProvider: false,
    );
    if (result == null) return;
    await _runAction(
      () => _lifecycleService.cancel(
        requestId: requestId,
        reasonCode: result.code,
        reason: result.reason,
      ),
    );
  }

  Future<void> _reportRisk() async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }
    final result = await showDialog<_RiskReportData>(
      context: context,
      builder: (_) => const _RiskReportDialog(isProvider: false),
    );
    if (result == null) {
      return;
    }
    try {
      await _lifecycleService.reportRisk(
        requestId: requestId,
        reason: '[${result.level}] ${result.reason}: ${result.details}'.trim(),
        latitude: _double(_request['location_lat'], 4.6767),
        longitude: _double(_request['location_lng'], -74.0482),
      );
      await _reload();
      _showMessage(
        'Reporte de riesgo enviado. Si es una emergencia real, comunícate de inmediato con la línea local de emergencias.',
      );
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    }
  }

  Future<void> _confirmCompletion() async {
    final requestId = _id;
    if (requestId == null) return;
    final succeeded = await _runAction(
      () => _lifecycleService.confirmCompletion(requestId),
    );
    if (!succeeded) return;
    await _reload();
    if (_status == 'ended') {
      _showMessage(
        'Actividad finalizada. Ambas personas confirmaron el cierre.',
      );
    } else {
      _showMessage(
        'Confirmaste el cierre. Falta la confirmación del acompañante.',
      );
    }
  }

  Future<void> _rate() async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }
    final result = await showRequiredServiceRatingDialog(
      context,
      targetLabel: 'el acompañante',
      includeFinishMessage: false,
    );
    if (result == null) {
      return;
    }
    try {
      await _lifecycleService.rate(
        requestId: requestId,
        score: result.score,
        privateComment: result.privateComment,
        publicComment: result.publicComment,
      );
      await _reload();
      _showMessage(
        'Calificación registrada. El comentario público pasará por moderación.',
      );
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    }
  }

  Future<void> _reportBehavior() async {
    final requestId = _id;
    if (requestId == null) return;
    final result = await showBehaviorReportDialog(
      context,
      targetLabel: 'el acompañante',
    );
    if (result == null) return;
    setState(() => _loading = true);
    try {
      await _trustService.reportBehavior(
        requestId: requestId,
        category: result.category,
        description: result.description,
      );
      _showMessage('Reporte enviado de forma privada a GoWith.');
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _blockProvider() async {
    final requestId = _id;
    final providerId = _int(_request['assigned_provider']);
    if (requestId == null || providerId == null) return;
    final result = await showUserBlockDialog(
      context,
      targetLabel:
          _request['assigned_provider_username']?.toString() ??
          'el acompañante',
    );
    if (result == null) return;
    setState(() => _loading = true);
    try {
      await _trustService.blockUser(
        userId: providerId,
        sourceServiceId: requestId,
        reason: result.reason,
      );
      _showMessage(
        'Usuario bloqueado. No volverán a ser emparejados en nuevas actividades.',
      );
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openProviderReputation() async {
    final providerId = _int(_request['assigned_provider']);
    if (providerId == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProviderReputationPage(
          providerId: providerId,
          providerName:
              _request['assigned_provider_username']?.toString() ??
              'Acompañante',
        ),
      ),
    );
  }

  Map<String, dynamic>? _latestLateNotice(List<Map<String, dynamic>> timeline) {
    for (final event in timeline.reversed) {
      if (event['event_type']?.toString() == 'late_notice') {
        return event;
      }
    }
    return null;
  }

  Future<void> _notifyLateArrival() async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }
    final result = await showDialog<_LateArrivalData>(
      context: context,
      builder: (_) => const _LateArrivalDialog(),
    );
    if (result == null) {
      return;
    }
    await _runAction(
      () => _lifecycleService.notifyLateArrival(
        requestId: requestId,
        etaMinutes: result.etaMinutes,
        message: result.message,
      ),
    );
    _showMessage('Se notificó a la otra parte que llegarás tarde.');
  }

  Future<void> _proposeReschedule() async {
    final requestId = _id;
    final currentStart = DateTime.tryParse(
      _request['requested_start_time']?.toString() ?? '',
    )?.toLocal();
    if (requestId == null || currentStart == null) return;
    final proposal = await showServiceRescheduleDialog(
      context,
      currentStartTime: currentStart,
    );
    if (proposal == null) return;
    final succeeded = await _runAction(
      () => _lifecycleService.proposeReschedule(
        requestId: requestId,
        proposedStartTime: proposal.proposedStartTime,
        reason: proposal.reason,
      ),
    );
    if (succeeded) {
      _showMessage('La propuesta de nueva hora fue enviada.');
    }
  }

  Future<void> _respondReschedule(bool accept) async {
    final requestId = _id;
    if (requestId == null) return;
    final succeeded = await _runAction(
      () => _lifecycleService.respondReschedule(
        requestId: requestId,
        accept: accept,
      ),
    );
    if (succeeded) {
      _showMessage(
        accept
            ? 'La nueva hora quedó confirmada.'
            : 'Se conserva la hora original de la actividad.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestId = _id;
    final paymentStatus = _payment['status'];
    final timeline = (_request['timeline'] is List)
        ? List<Map<String, dynamic>>.from(
            (_request['timeline'] as List).whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
          )
        : const <Map<String, dynamic>>[];
    final lateNotice = _latestLateNotice(timeline);

    return Scaffold(
      appBar: AppBar(
        title: Text(requestId == null ? 'Solicitud' : 'Solicitud #$requestId'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refreshing ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _statusCard(),
          if (lateNotice != null) ...[
            const SizedBox(height: 12),
            _lateNoticeCard(lateNotice),
          ],
          if (_status == 'matched' &&
              _request['encounter_status']?.toString() == 'both_arrived') ...[
            const SizedBox(height: 12),
            _startCodeHeroCard(),
          ],
          const SizedBox(height: 12),
          _serviceCard(),
          if (_request['pending_reschedule'] is Map) ...[
            const SizedBox(height: 12),
            _rescheduleCard(),
          ],
          const SizedBox(height: 12),
          _paymentCard(paymentStatus),
          if (_status == 'matched') ...[
            const SizedBox(height: 12),
            _proximityCard(),
          ],
          if ((_status == 'matched' || _status == 'started') &&
              requestId != null) ...[
            const SizedBox(height: 12),
            ServiceTrackingPanel(serviceRequestId: requestId, status: _status),
          ],
          if (requestId != null &&
              const {'matched', 'started', 'incident'}.contains(_status)) ...[
            const SizedBox(height: 12),
            ServiceSosPanel(
              serviceRequestId: requestId,
              status: _status,
              onSosConfirmed: () => _reload(),
            ),
          ],
          if (_status == 'matched' || _status == 'started') ...[
            const SizedBox(height: 12),
            _encounterCard(),
          ],
          if (_status == 'ended') ...[
            const SizedBox(height: 12),
            _ratingCard(),
          ],
          if (const {
                'ended',
                'cancelled',
                'no_show',
                'incident',
              }.contains(_status) &&
              _request['assigned_provider'] != null) ...[
            const SizedBox(height: 12),
            _trustCard(),
          ],
          const SizedBox(height: 12),
          _actionsCard(),
          if (timeline.isNotEmpty) ...[
            const SizedBox(height: 12),
            _timelineCard(timeline),
          ],
          if (_refreshing) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return Card(
      color: serviceStatusColor(_status).withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(
              serviceStatusIcon(_status),
              color: serviceStatusColor(_status),
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceStatusLabel(_status),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_request['assigned_provider_username'] != null)
                    Text(
                      'Acompañante: ${_request['assigned_provider_username']}',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalle de la actividad',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _row('Actividad', serviceActivityLabel(_request)),
            _row('Punto', _request['location_text']),
            _row('Inicio', formatDateTime(_request['requested_start_time'])),
            _row(
              'Duración',
              '${_request['requested_duration_minutes'] ?? '—'} min',
            ),
            _row('Valor', formatCop(_request['calculated_price'])),
            if ((_request['notes']?.toString().trim() ?? '').isNotEmpty)
              _row('Notas', _request['notes']),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard(dynamic paymentStatus) {
    final isPending =
        _status == 'pending_payment' && paymentStatus == 'pending';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Pago', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _row('Estado', paymentStatusLabel(paymentStatus)),
            _row(
              'Total',
              formatCop(
                _payment['amount_total'] ?? _request['calculated_price'],
              ),
            ),
            _row('Comisión demo', formatCop(_payment['platform_fee'])),
            if (isPending) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _simulatePayment,
                icon: const Icon(Icons.credit_card),
                label: const Text('Simular pago aprobado'),
              ),
              const Text(
                'Este botón reemplaza temporalmente la pasarela real para el video del MVP.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
            if (!isPending && paymentStatus == 'release_pending') ...[
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.schedule_send_outlined,
                  color: AppColors.warning,
                ),
                title: Text('Transferencia pendiente'),
                subtitle: Text(
                  'La actividad ya terminó y el pago está listo para ser transferido al prestador.',
                ),
              ),
            ],
            if (paymentStatus == 'paid_to_provider') ...[
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle, color: AppColors.success),
                title: Text('Transferencia realizada'),
                subtitle: Text(
                  'La plataforma registró que el valor fue transferido a la cuenta del prestador.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _proximityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cercanía con el acompañante',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _request['proximity_label']?.toString() ??
                  'Esperando ubicaciones',
              style: const TextStyle(fontSize: 17),
            ),
            Text(
              'Distancia aproximada: ${formatDistance(_request['distance_meters'])}',
            ),
            const SizedBox(height: 8),
            const Text(
              'La cercanía es informativa. Al tocar “Ya llegué” se registra tu ubicación en el punto.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lateNoticeCard(Map<String, dynamic> event) {
    final metadata = event['metadata'] is Map
        ? Map<String, dynamic>.from(event['metadata'] as Map)
        : <String, dynamic>{};
    final eta = metadata['eta_minutes'];
    final actor = event['actor_username']?.toString() ?? 'La otra persona';
    return Card(
      color: AppColors.tint(AppColors.warning, 0.08),
      child: ListTile(
        leading: const Icon(
          Icons.access_time_filled_outlined,
          color: AppColors.warning,
        ),
        title: Text('$actor informó que llegará tarde'),
        subtitle: Text(
          eta == null
              ? event['description']?.toString() ?? 'Llegará tarde.'
              : 'Tiempo estimado: $eta minutos.\n${event['description'] ?? ''}',
        ),
      ),
    );
  }

  Widget _startCodeHeroCard() {
    final startCode = _request['start_code_for_client']?.toString() ?? '';
    return Card(
      color: AppColors.tint(AppColors.primary, 0.07),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Icon(Icons.pin_outlined, size: 34, color: AppColors.primary),
            const SizedBox(height: 6),
            const Text(
              'Ambos están en el punto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text('Muéstrale este código al prestador para iniciar.'),
            const SizedBox(height: 12),
            SelectableText(
              startCode,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encounterCard() {
    final canArrive = _bool(_request['can_arrive']);
    final canConfirmCompletion = _bool(_request['can_confirm_completion']);
    final canConfirmParticipation = _bool(
      _request['can_confirm_participation'],
    );
    final canReportNoShow = _bool(_request['can_report_no_show']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Encuentro',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(operationalStageIcon(_request['operational_stage'])),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _request['operational_stage_label']?.toString() ??
                        operationalStageLabel(_request['operational_stage']),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(encounterStatusLabel(_request['encounter_status'])),
            if (canConfirmParticipation) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _confirmParticipation,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Confirmar participación'),
              ),
            ],
            if (canArrive) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _confirmArrival,
                icon: const Icon(Icons.place),
                label: const Text('Ya llegué'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _notifyLateArrival,
                icon: const Icon(Icons.access_time_outlined),
                label: const Text('Llegaré tarde, ¿me puedes esperar?'),
              ),
              const Text(
                'Un solo toque confirma tu llegada usando el GPS real del dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
            if (_status == 'matched' && !canArrive) ...[
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle, color: AppColors.success),
                title: Text('Tu llegada ya está confirmada'),
                subtitle: Text(
                  'El código aparecerá arriba cuando el prestador también llegue.',
                ),
              ),
            ],
            if (_status == 'started') ...[
              const SizedBox(height: 8),
              Text(
                'Inicio confirmado: ${formatDateTime(_request['started_at'])}',
              ),
            ],
            if (canConfirmCompletion) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading || _id == null ? null : _confirmCompletion,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Confirmar que la actividad terminó'),
              ),
              const Text(
                'GoWith cerrará la actividad cuando ambas personas confirmen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
            if (_request['completion_waiting_for']?.toString() == 'client') ...[
              const SizedBox(height: 8),
              const Text(
                'El acompañante ya confirmó el cierre. Falta tu confirmación.',
              ),
            ],
            if (canReportNoShow) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _reportNoShow,
                icon: const Icon(Icons.person_off_outlined),
                label: const Text('El acompañante no se presentó'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rescheduleCard() {
    final raw = _request['pending_reschedule'];
    if (raw is! Map) return const SizedBox.shrink();
    final proposal = Map<String, dynamic>.from(raw);
    final canRespond = proposal['can_respond'] == true;
    final proposedByMe = proposal['proposed_by_me'] == true;
    return Card(
      color: AppColors.tint(AppColors.warning, 0.08),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule_send_outlined, color: AppColors.warning),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Cambio de horario solicitado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Hora actual: ${formatDateTime(proposal['original_start_time'])}',
            ),
            Text(
              'Nueva hora: ${formatDateTime(proposal['proposed_start_time'])}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if ((proposal['reason']?.toString().trim() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('Motivo: ${proposal['reason']}'),
              ),
            const SizedBox(height: AppSpacing.md),
            if (proposedByMe)
              const Text(
                'Esperando la respuesta del acompañante. La hora original sigue vigente.',
              ),
            if (canRespond) ...[
              OutlinedButton(
                onPressed: _loading ? null : () => _respondReschedule(false),
                child: const Text('Rechazar y conservar hora'),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: _loading ? null : () => _respondReschedule(true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Aceptar nueva hora'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _moderationLabel(dynamic value) {
    switch (value?.toString().toUpperCase()) {
      case 'APPROVED':
        return 'Aprobado y visible';
      case 'REJECTED':
        return 'No aprobado para publicación';
      case 'HIDDEN':
        return 'Oculto por moderación';
      default:
        return 'Pendiente de moderación';
    }
  }

  Widget _ratingCard() {
    final rating = _request['my_rating'];
    if (rating is Map) {
      final data = Map<String, dynamic>.from(rating);
      final privateComment =
          (data['private_comment'] ?? data['comment'])?.toString().trim() ?? '';
      final publicComment = data['public_comment']?.toString().trim() ?? '';
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu calificación: ${data['score']}/5',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (publicComment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Comentario público: $publicComment'),
                Text(
                  _moderationLabel(data['public_comment_status']),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              if (privateComment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Nota privada para GoWith: $privateComment'),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _openProviderReputation,
                icon: const Icon(Icons.insights_outlined),
                label: const Text('Ver reputación del acompañante'),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Cómo fue el servicio?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _rate,
              icon: const Icon(Icons.star),
              label: const Text('Calificar al acompañante'),
            ),
            TextButton.icon(
              onPressed: _openProviderReputation,
              icon: const Icon(Icons.insights_outlined),
              label: const Text('Ver reputación del acompañante'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trustCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Confianza y convivencia',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Estas acciones quedan asociadas al servicio cerrado. Los reportes son privados y los bloqueos evitan futuros emparejamientos.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loading ? null : _reportBehavior,
              icon: const Icon(Icons.report_outlined),
              label: const Text('Reportar comportamiento'),
            ),
            TextButton.icon(
              onPressed: _loading ? null : _blockProvider,
              icon: const Icon(Icons.block_outlined),
              label: const Text('Bloquear acompañante'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard() {
    final canCancel = _bool(_request['can_cancel']);
    final canPropose = _bool(_request['can_propose_reschedule']);
    final riskEnabled = const {'matched', 'started', 'ended'}.contains(_status);
    if (!canCancel && !canPropose && !riskEnabled) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ayuda y seguridad',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Usa estas opciones solo si necesitas apoyo, reprogramación o reportar una novedad de seguridad.',
              style: TextStyle(color: Colors.grey),
            ),
            if (canPropose)
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _proposeReschedule,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Proponer nueva hora'),
              ),
            if (canCancel)
              OutlinedButton.icon(
                onPressed: _loading ? null : _cancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar actividad'),
              ),
            if (riskEnabled)
              TextButton.icon(
                onPressed: _loading ? null : _reportRisk,
                icon: const Icon(Icons.warning_amber, color: AppColors.danger),
                label: const Text('Reportar una situación'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _timelineCard(List<Map<String, dynamic>> timeline) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Línea de tiempo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...timeline.reversed.map(
              (event) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle, size: 12),
                title: Text(
                  event['description']?.toString() ??
                      event['event_type'].toString(),
                ),
                subtitle: Text(formatDateTime(event['created_at'])),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value?.toString() ?? '—')),
        ],
      ),
    );
  }
}

class _LateArrivalData {
  const _LateArrivalData(this.etaMinutes, this.message);

  final int etaMinutes;
  final String message;
}

class _LateArrivalDialog extends StatefulWidget {
  const _LateArrivalDialog();

  @override
  State<_LateArrivalDialog> createState() => _LateArrivalDialogState();
}

class _LateArrivalDialogState extends State<_LateArrivalDialog> {
  int _eta = 10;
  final _messageCtrl = TextEditingController();
  static const _etas = [5, 10, 15, 20, 30, 45, 60];

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Llegaré tarde'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _eta,
            decoration: const InputDecoration(
              labelText: '¿En cuánto tiempo llegarás?',
            ),
            items: _etas
                .map(
                  (value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value minutos'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _eta = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Mensaje opcional',
              hintText: 'Ej. Estoy en camino pero hay tráfico.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _LateArrivalData(_eta, _messageCtrl.text.trim()),
          ),
          child: const Text('Avisar'),
        ),
      ],
    );
  }
}

class _RiskReportData {
  const _RiskReportData(this.level, this.reason, this.details);

  final String level;
  final String reason;
  final String details;
}

class _RiskReportDialog extends StatefulWidget {
  const _RiskReportDialog({required this.isProvider});

  final bool isProvider;

  @override
  State<_RiskReportDialog> createState() => _RiskReportDialogState();
}

class _RiskReportDialogState extends State<_RiskReportDialog> {
  String _level = 'media';
  String _reason = 'conducta_inapropiada';
  final _detailsCtrl = TextEditingController();

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.isProvider
        ? const {
            'conducta_inapropiada': 'Conducta inapropiada',
            'sitio_inseguro': 'Sitio inseguro',
            'presion_o_amenaza': 'Presión o amenaza',
            'incumplimiento': 'Incumplimiento del acuerdo',
            'otro': 'Otro',
          }
        : const {
            'conducta_inapropiada': 'Conducta inapropiada',
            'sitio_inseguro': 'Sitio inseguro',
            'acoso': 'Acoso o presión',
            'incumplimiento': 'Incumplimiento del acuerdo',
            'otro': 'Otro',
          };
    return AlertDialog(
      title: const Text('Reportar una situación'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: 'Nivel de urgencia'),
              items: const [
                DropdownMenuItem(value: 'baja', child: Text('Baja')),
                DropdownMenuItem(value: 'media', child: Text('Media')),
                DropdownMenuItem(value: 'alta', child: Text('Alta')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _level = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Motivo principal'),
              items: reasons.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _reason = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalle',
                hintText: 'Describe brevemente lo ocurrido.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Importante: este reporte deja trazabilidad en la plataforma. En una emergencia real debes comunicarte de inmediato con la línea local de emergencias.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _RiskReportData(_level, _reason, _detailsCtrl.text.trim()),
          ),
          child: const Text('Enviar reporte'),
        ),
      ],
    );
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
