import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/service_rating_dialog.dart';
import '../data/location_ping_service.dart';
import '../data/payment_service.dart';
import '../data/service_lifecycle_service.dart';
import '../data/service_request_query_service.dart';

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
    } finally {
      if (mounted && !silent) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _runAction(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    setState(() => _loading = true);
    try {
      final updated = await action();
      if (!mounted) {
        return;
      }
      setState(() => _request = updated);
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
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

  Future<void> _sendDemoLocation({required bool meetingPoint}) async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }
    final baseLat = _double(_request['location_lat'], 4.6767);
    final baseLng = _double(_request['location_lng'], -74.0482);
    final latitude = meetingPoint ? baseLat : baseLat + 0.012;
    final longitude = meetingPoint ? baseLng : baseLng + 0.006;

    setState(() => _loading = true);
    try {
      await _pingService.createPing(
        serviceRequestId: requestId,
        locationLat: latitude,
        locationLng: longitude,
        source: meetingPoint ? 'simulated_meeting_point' : 'simulated_far',
      );
      await _reload();
      _showMessage(
        meetingPoint
            ? 'Ubicación demo enviada en el punto de encuentro.'
            : 'Ubicación demo enviada lejos del punto.',
      );
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirmArrival() async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }
    final baseLat = _double(_request['location_lat'], 4.6767);
    final baseLng = _double(_request['location_lng'], -74.0482);

    setState(() => _loading = true);
    try {
      await _pingService.createPing(
        serviceRequestId: requestId,
        locationLat: baseLat,
        locationLng: baseLng,
        source: 'arrival_confirmation',
      );
      final updated = await _lifecycleService.arrive(requestId);
      if (!mounted) {
        return;
      }
      setState(() => _request = updated);
      _showMessage(
        'Llegada confirmada. La ubicación se actualizó automáticamente.',
      );
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cancel() async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }
    final result = await showDialog<_CancellationData>(
      context: context,
      builder: (_) => const _CancellationDialog(isProvider: false),
    );
    if (result == null) {
      return;
    }
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

  Future<void> _finishAndRate() async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }

    final rating = await showRequiredServiceRatingDialog(
      context,
      targetLabel: 'el acompañante',
    );
    if (rating == null || !mounted) {
      return;
    }

    setState(() => _loading = true);
    try {
      final updated = await _lifecycleService.finish(requestId);
      if (!mounted) {
        return;
      }
      setState(() => _request = updated);

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

      await _reload();
      final status = _request['status']?.toString().toLowerCase();
      _showMessage(
        status == 'ended'
            ? 'Actividad finalizada y calificación registrada.'
            : 'Finalización y calificación registradas. Falta la confirmación del prestador.',
      );
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
        comment: result.comment,
      );
      await _reload();
      _showMessage('Calificación registrada.');
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    }
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
          const SizedBox(height: 12),
          _paymentCard(paymentStatus),
          if (_status == 'matched') ...[
            const SizedBox(height: 12),
            _proximityCard(),
            const SizedBox(height: 12),
            _encounterCard(),
          ],
          if (_status == 'ended') ...[
            const SizedBox(height: 12),
            _ratingCard(),
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
            _row('Actividad', _request['category_name']),
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
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _sendDemoLocation(meetingPoint: false),
              icon: const Icon(Icons.route_outlined),
              label: const Text('Demo: simular que estoy lejos'),
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
    final canFinish = _bool(_request['can_finish']);
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
            Text(encounterStatusLabel(_request['encounter_status'])),
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
                'Un solo toque confirma tu llegada y actualiza la ubicación demo.',
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
            if (canFinish) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading || _id == null ? null : _finishAndRate,
                icon: const Icon(Icons.flag),
                label: const Text('Finalizar y calificar'),
              ),
              const Text(
                'El servicio se cerrará cuando el prestador también confirme.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ratingCard() {
    final rating = _request['my_rating'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: rating is Map
            ? Text(
                'Tu calificación: ${rating['score']}/5\n${rating['comment'] ?? ''}',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '¿Cómo fue el servicio?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _rate,
                    icon: const Icon(Icons.star),
                    label: const Text('Calificar al prestador'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _actionsCard() {
    final canCancel = _bool(_request['can_cancel']);
    final riskEnabled = const {'matched', 'started', 'ended'}.contains(_status);
    if (!canCancel && !riskEnabled) {
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

class _CancellationData {
  const _CancellationData(this.code, this.reason);

  final String code;
  final String reason;
}

class _CancellationDialog extends StatefulWidget {
  const _CancellationDialog({required this.isProvider});

  final bool isProvider;

  @override
  State<_CancellationDialog> createState() => _CancellationDialogState();
}

class _CancellationDialogState extends State<_CancellationDialog> {
  String _code = 'no_longer_needed';
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.isProvider
        ? const {
            'cannot_arrive': 'No puedo llegar',
            'client_no_show': 'El solicitante no se presentó',
            'activity_mismatch': 'La actividad no coincide',
            'unsafe': 'No me siento seguro',
            'other': 'Otro',
          }
        : const {
            'no_longer_needed': 'Ya no necesito el servicio',
            'provider_no_show': 'El prestador no llegó',
            'unsafe': 'No me siento seguro',
            'activity_changed': 'La actividad cambió',
            'other': 'Otro',
          };
    if (!options.containsKey(_code)) {
      _code = options.keys.first;
    }

    return AlertDialog(
      title: const Text('Cancelar actividad'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _code,
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: options.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _code = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalle (opcional)',
                border: OutlineInputBorder(),
              ),
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
            _CancellationData(_code, _reasonCtrl.text),
          ),
          child: const Text('Confirmar cancelación'),
        ),
      ],
    );
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
