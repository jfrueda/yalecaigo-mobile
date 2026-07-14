import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/service_rating_dialog.dart';
import '../../service_request/data/location_ping_service.dart';
import '../../service_request/data/service_lifecycle_service.dart';
import '../../service_request/data/service_request_query_service.dart';

class ProviderActiveServicePage extends StatefulWidget {
  const ProviderActiveServicePage({super.key, required this.serviceRequest});

  final Map<String, dynamic> serviceRequest;

  @override
  State<ProviderActiveServicePage> createState() =>
      _ProviderActiveServicePageState();
}

class _ProviderActiveServicePageState extends State<ProviderActiveServicePage> {
  final _queryService = ServiceRequestQueryService();
  final _lifecycleService = ServiceLifecycleService();
  final _pingService = LocationPingService();
  final _codeCtrl = TextEditingController();

  late Map<String, dynamic> _request;
  Timer? _timer;
  bool _loading = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _request = Map<String, dynamic>.from(widget.serviceRequest);
    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _reload(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  int? get _id {
    final value = _request['id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String get _status => _request['status']?.toString().toLowerCase() ?? '';

  Map<String, dynamic> get _payment {
    final raw = _request['payment'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  double _double(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _bool(dynamic value) => value == true;

  Future<void> _reload({bool silent = false}) async {
    final requestId = _id;
    if (requestId == null) return;
    if (!silent) setState(() => _refreshing = true);
    try {
      final fresh = await _queryService.getRequestById(requestId);
      if (!mounted || fresh == null) return;
      setState(() => _request = fresh);
    } finally {
      if (mounted && !silent) setState(() => _refreshing = false);
    }
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final value = data['detail'] ?? data['code'];
      if (value != null) return value.toString();
    }
    return error.message ?? 'No fue posible completar la operación.';
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _loading = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _request = updated);
    } on DioException catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendDemoLocation({required bool meetingPoint}) async {
    final requestId = _id;
    if (requestId == null) return;
    final baseLat = _double(_request['location_lat'], 4.6767);
    final baseLng = _double(_request['location_lng'], -74.0482);
    final latitude = meetingPoint ? baseLat : baseLat - 0.011;
    final longitude = meetingPoint ? baseLng : baseLng - 0.007;
    setState(() => _loading = true);
    try {
      await _pingService.createPing(
        serviceRequestId: requestId,
        locationLat: latitude,
        locationLng: longitude,
        source: meetingPoint ? 'simulated_meeting_point' : 'simulated_far',
      );
      await _reload();
      _message(
        meetingPoint
            ? 'Ubicación enviada en el punto.'
            : 'Ubicación lejana enviada.',
      );
    } on DioException catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmArrival() async {
    final requestId = _id;
    if (requestId == null) return;
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
      if (!mounted) return;
      setState(() => _request = updated);
      _message(
        'Llegada confirmada. La ubicación se actualizó automáticamente.',
      );
    } on DioException catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startService() async {
    final requestId = _id;
    if (requestId == null) return;
    if (_codeCtrl.text.trim().length != 4) {
      _message('Ingresa el código de cuatro dígitos del solicitante.');
      return;
    }
    await _run(() => _lifecycleService.start(requestId, _codeCtrl.text));
  }

  Future<void> _cancel() async {
    final requestId = _id;
    if (requestId == null) return;
    String code = 'cannot_arrive';
    final reasonCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cancelar servicio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: code,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: const [
                  DropdownMenuItem(
                    value: 'cannot_arrive',
                    child: Text('No puedo llegar'),
                  ),
                  DropdownMenuItem(
                    value: 'client_no_show',
                    child: Text('El solicitante no se presentó'),
                  ),
                  DropdownMenuItem(
                    value: 'activity_mismatch',
                    child: Text('La actividad no coincide'),
                  ),
                  DropdownMenuItem(
                    value: 'unsafe',
                    child: Text('No me siento seguro'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Otro')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => code = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detalle (opcional)',
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
              onPressed: () => Navigator.pop(context, {
                'code': code,
                'reason': reasonCtrl.text,
              }),
              child: const Text('Cancelar servicio'),
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
    if (result == null) return;
    await _run(
      () => _lifecycleService.cancel(
        requestId: requestId,
        reasonCode: result['code'] ?? 'other',
        reason: result['reason'] ?? '',
      ),
    );
  }

  Future<void> _reportRisk() async {
    final requestId = _id;
    if (requestId == null) return;
    final result = await showDialog<_RiskReportData>(
      context: context,
      builder: (_) => const _RiskReportDialog(isProvider: true),
    );
    if (result == null) return;
    try {
      await _lifecycleService.reportRisk(
        requestId: requestId,
        reason: '[${result.level}] ${result.reason}: ${result.details}'.trim(),
        latitude: _double(_request['location_lat'], 4.6767),
        longitude: _double(_request['location_lng'], -74.0482),
      );
      await _reload();
      _message(
        'Reporte de riesgo enviado. Si es una emergencia real, comunícate de inmediato con la línea local de emergencias.',
      );
    } on DioException catch (error) {
      _message(_errorMessage(error));
    }
  }

  Future<void> _finishAndRate() async {
    final requestId = _id;
    if (requestId == null) return;

    final rating = await showRequiredServiceRatingDialog(
      context,
      targetLabel: 'el solicitante',
    );
    if (rating == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final updated = await _lifecycleService.finish(requestId);
      if (!mounted) return;
      setState(() => _request = updated);

      try {
        await _lifecycleService.rate(
          requestId: requestId,
          score: rating.score,
          comment: rating.comment,
        );
      } on DioException catch (error) {
        _message(
          'La finalización quedó registrada, pero la calificación no pudo guardarse: ${_errorMessage(error)}',
        );
      }

      await _reload();
      final status = _request['status']?.toString().toLowerCase();
      _message(
        status == 'ended'
            ? 'Servicio finalizado y calificación registrada.'
            : 'Finalización y calificación registradas. Falta la confirmación del solicitante.',
      );
    } on DioException catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rateClient() async {
    final requestId = _id;
    if (requestId == null) return;
    final result = await showRequiredServiceRatingDialog(
      context,
      targetLabel: 'el solicitante',
      includeFinishMessage: false,
    );
    if (result == null) return;
    try {
      await _lifecycleService.rate(
        requestId: requestId,
        score: result.score,
        comment: result.comment,
      );
      await _reload();
      _message('Calificación registrada.');
    } on DioException catch (error) {
      _message(_errorMessage(error));
    }
  }

  Map<String, dynamic>? _latestLateNotice(List<Map<String, dynamic>> timeline) {
    for (final event in timeline.reversed) {
      if (event['event_type']?.toString() == 'late_notice') return event;
    }
    return null;
  }

  Future<void> _notifyLateArrival() async {
    final requestId = _id;
    if (requestId == null) return;
    final result = await showDialog<_LateArrivalData>(
      context: context,
      builder: (_) => const _LateArrivalDialog(),
    );
    if (result == null) return;
    await _run(
      () => _lifecycleService.notifyLateArrival(
        requestId: requestId,
        etaMinutes: result.etaMinutes,
        message: result.message,
      ),
    );
    _message('Se notificó al solicitante que llegarás tarde.');
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Servicio del prestador'),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : () => _reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          if (lateNotice != null) ...[
            const SizedBox(height: 12),
            _lateNoticeCard(lateNotice),
          ],
          if (_bool(_request['can_start'])) ...[
            const SizedBox(height: 12),
            _startCodeEntryCard(),
          ],
          const SizedBox(height: 12),
          _operationalCard(),
          if (_status == 'matched') ...[
            const SizedBox(height: 12),
            _proximityCard(),
          ],
          const SizedBox(height: 12),
          _paymentCard(),
          if (_status == 'ended') ...[
            const SizedBox(height: 12),
            _ratingCard(),
          ],
          const SizedBox(height: 12),
          _actionCard(),
          if (timeline.isNotEmpty) ...[
            const SizedBox(height: 12),
            _timelineCard(timeline),
          ],
          if (_refreshing) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Card(
      color: serviceStatusColor(_status).withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              serviceStatusLabel(_status),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Solicitante: ${_request['client_username'] ?? '—'}'),
            Text('Actividad: ${_request['category_name'] ?? '—'}'),
            Text('Punto: ${_request['location_text'] ?? '—'}'),
            Text('Hora: ${formatDateTime(_request['requested_start_time'])}'),
            Text(
              'Duración: ${_request['requested_duration_minutes'] ?? '—'} min',
            ),
            if ((_request['notes']?.toString().trim() ?? '').isNotEmpty)
              Text('Notas: ${_request['notes']}'),
          ],
        ),
      ),
    );
  }

  Widget _operationalCard() {
    final canArrive = _bool(_request['can_arrive']);
    final canFinish = _bool(_request['can_finish']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Operación del servicio',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(encounterStatusLabel(_request['encounter_status'])),
            if (canArrive) ...[
              const SizedBox(height: 10),
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
                'Un solo toque confirma la llegada y registra la ubicación demo en el punto.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
            if (_status == 'matched' && !canArrive) ...[
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Tu llegada ya está confirmada'),
                subtitle: Text(
                  'El campo del código aparecerá arriba cuando el solicitante también llegue.',
                ),
              ),
            ],
            if (_status == 'started')
              Text(
                'Servicio iniciado: ${formatDateTime(_request['started_at'])}',
              ),
            if (canFinish) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading || _id == null ? null : _finishAndRate,
                icon: const Icon(Icons.flag),
                label: const Text('Finalizar y calificar'),
              ),
              const Text(
                'El cierre queda pendiente hasta que el solicitante también confirme.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
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
      color: Colors.orange.shade50,
      child: ListTile(
        leading: const Icon(
          Icons.access_time_filled_outlined,
          color: Colors.orange,
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

  Widget _startCodeEntryCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.pin_outlined, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ambos están en el punto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Pide al solicitante su código de cuatro dígitos.'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 10,
              ),
              decoration: const InputDecoration(
                hintText: '0000',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (!_loading) _startService();
              },
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _startService,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Validar código e iniciar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proximityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cercanía con el solicitante',
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
              'La cercanía es informativa y se actualiza automáticamente al confirmar “Ya llegué”.',
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

  Widget _paymentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ganancia del servicio',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Estado: ${paymentStatusLabel(_payment['status'])}'),
            Text('Valor bruto: ${formatCop(_payment['amount_total'])}'),
            Text('Comisión: ${formatCop(_payment['platform_fee'])}'),
            Text(
              'Valor neto: ${formatCop(_payment['provider_amount'])}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_payment['status']?.toString().toLowerCase() ==
                'release_pending')
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.schedule_send_outlined,
                  color: Colors.orange,
                ),
                title: Text('Transferencia pendiente'),
                subtitle: Text(
                  'La actividad ya terminó y el valor está pendiente de transferirse a tu cuenta.',
                ),
              ),
            if (_payment['status']?.toString().toLowerCase() ==
                'paid_to_provider')
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Transferencia realizada'),
                subtitle: Text('La plataforma registró el envío a tu cuenta.'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ratingCard() {
    final rating = _request['my_rating'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: rating is Map
            ? Text(
                'Tu calificación al solicitante: ${rating['score']}/5\n${rating['comment'] ?? ''}',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '¿Cómo fue el solicitante?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _loading ? null : _rateClient,
                    icon: const Icon(Icons.star),
                    label: const Text('Calificar solicitante'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _actionCard() {
    final canCancel = _bool(_request['can_cancel']);
    final riskEnabled = const {'matched', 'started', 'ended'}.contains(_status);
    if (!canCancel && !riskEnabled) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ayuda y seguridad',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Usa estas opciones si necesitas reportar una novedad importante o una situación de seguridad.',
              style: TextStyle(color: Colors.grey),
            ),
            if (canCancel)
              OutlinedButton.icon(
                onPressed: _loading ? null : _cancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar servicio'),
              ),
            if (riskEnabled)
              TextButton.icon(
                onPressed: _loading ? null : _reportRisk,
                icon: const Icon(Icons.warning_amber, color: Colors.red),
                label: const Text('Reportar un caso de riesgo'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _timelineCard(List<Map<String, dynamic>> timeline) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Línea de tiempo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
              if (value != null) setState(() => _eta = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Mensaje opcional',
              hintText: 'Ej. Voy en camino pero hay tráfico.',
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
    final reasons = const {
      'conducta_inapropiada': 'Conducta inapropiada',
      'sitio_inseguro': 'Sitio inseguro',
      'presion_o_amenaza': 'Presión o amenaza',
      'incumplimiento': 'Incumplimiento del acuerdo',
      'otro': 'Otro',
    };
    return AlertDialog(
      title: const Text('Reportar un caso de riesgo'),
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
                if (value != null) setState(() => _level = value);
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
                if (value != null) setState(() => _reason = value);
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
