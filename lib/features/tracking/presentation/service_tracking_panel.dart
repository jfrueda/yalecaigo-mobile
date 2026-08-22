import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_spacing.dart';
import '../../service_request/data/location_ping_service.dart';
import '../data/device_location_service.dart';
import '../data/tracking_service.dart';

class ServiceTrackingPanel extends StatefulWidget {
  const ServiceTrackingPanel({
    super.key,
    required this.serviceRequestId,
    required this.status,
  });

  final int serviceRequestId;
  final String status;

  @override
  State<ServiceTrackingPanel> createState() => _ServiceTrackingPanelState();
}

class _ServiceTrackingPanelState extends State<ServiceTrackingPanel> {
  final _trackingService = TrackingService();
  final _locationService = DeviceLocationService();
  final _pingService = LocationPingService();

  Timer? _snapshotTimer;
  Timer? _pingTimer;
  Timer? _clockTimer;

  Map<String, dynamic>? _snapshot;
  Map<String, dynamic>? _safetyTimer;
  String? _shareUrl;
  DateTime? _shareExpiresAt;

  bool _loadingSnapshot = false;
  bool _sendingLocation = false;
  bool _liveSharing = false;
  bool _shareAction = false;
  bool _timerAction = false;

  bool get _isActive => const {'matched', 'started'}.contains(widget.status);

  @override
  void initState() {
    super.initState();
    if (_isActive) {
      _loadAll();
      _snapshotTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _loadSnapshot(silent: true),
      );
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _safetyTimer != null) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant ServiceTrackingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status && !_isActive) {
      _stopLiveSharing();
      _snapshotTimer?.cancel();
      _clockTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _snapshotTimer?.cancel();
    _pingTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait<void>([_loadSnapshot(), _loadSafetyTimer()]);
  }

  Future<void> _loadSnapshot({bool silent = false}) async {
    if (!_isActive || _loadingSnapshot) return;
    if (!silent && mounted) setState(() => _loadingSnapshot = true);
    try {
      final data = await _trackingService.snapshot(widget.serviceRequestId);
      if (!mounted) return;
      setState(() => _snapshot = data);
    } on DioException catch (error) {
      if (!silent) _message(_errorMessage(error));
    } finally {
      if (mounted && !silent) setState(() => _loadingSnapshot = false);
    }
  }

  Future<void> _loadSafetyTimer() async {
    if (!_isActive) return;
    try {
      final timer = await _trackingService.currentSafetyTimer(
        widget.serviceRequestId,
      );
      if (!mounted) return;
      setState(() => _safetyTimer = timer);
    } on DioException catch (error) {
      _message(_errorMessage(error));
    }
  }

  Future<bool> _sendCurrentLocation({String source = 'device_gps'}) async {
    if (!_isActive || _sendingLocation) return false;
    setState(() => _sendingLocation = true);
    var succeeded = false;
    try {
      final position = await _locationService.currentPosition();
      await _pingService.createPing(
        serviceRequestId: widget.serviceRequestId,
        locationLat: position.latitude,
        locationLng: position.longitude,
        accuracy: position.accuracy,
        source: source,
      );
      await _loadSnapshot(silent: true);
      succeeded = true;
    } on DeviceLocationException catch (error) {
      _message(error.message);
      _stopLiveSharing();
    } on DioException catch (error) {
      _message(_errorMessage(error));
      _stopLiveSharing();
    } catch (error) {
      _message('No fue posible obtener la ubicación: $error');
      _stopLiveSharing();
    } finally {
      if (mounted) setState(() => _sendingLocation = false);
    }
    return succeeded;
  }

  Future<void> _startLiveSharing() async {
    if (!_isActive || _liveSharing) return;
    final succeeded = await _sendCurrentLocation(source: 'live_tracking');
    if (!mounted || !succeeded) return;
    setState(() => _liveSharing = true);
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendCurrentLocation(source: 'live_tracking'),
    );
    _message(
      'Ubicación en vivo activada mientras esta pantalla permanezca abierta.',
    );
  }

  void _stopLiveSharing() {
    _pingTimer?.cancel();
    _pingTimer = null;
    if (mounted && _liveSharing) setState(() => _liveSharing = false);
  }

  Future<void> _createShareLink() async {
    final duration = await _chooseDuration(
      title: 'Compartir actividad',
      subtitle:
          'El enlace es temporal y solo publica tu ubicación, nunca la de la contraparte.',
      options: const [15, 60, 360, 1440],
      suffix: 'min',
    );
    if (duration == null || !mounted) return;

    setState(() => _shareAction = true);
    try {
      if (!_liveSharing) {
        final locationSent = await _sendCurrentLocation(source: 'share_link');
        if (!locationSent) return;
      }
      final data = await _trackingService.createShareLink(
        requestId: widget.serviceRequestId,
        durationMinutes: duration,
      );
      if (!mounted) return;
      final url = data['share_url']?.toString();
      final expiresAt = DateTime.tryParse(data['expires_at']?.toString() ?? '');
      setState(() {
        _shareUrl = url;
        _shareExpiresAt = expiresAt?.toLocal();
      });
      if (url != null && url.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: url));
        _message('Enlace creado y copiado al portapapeles.');
      }
    } on DioException catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _shareAction = false);
    }
  }

  Future<void> _revokeShareLink() async {
    setState(() => _shareAction = true);
    try {
      final revoked = await _trackingService.revokeShareLinks(
        widget.serviceRequestId,
      );
      if (!mounted) return;
      setState(() {
        _shareUrl = null;
        _shareExpiresAt = null;
      });
      _message(
        revoked > 0
            ? 'Enlace de actividad revocado.'
            : 'No había un enlace activo para revocar.',
      );
    } on DioException catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _shareAction = false);
    }
  }

  Future<void> _startSafetyTimer() async {
    final duration = await _chooseDuration(
      title: 'Temporizador de seguridad',
      subtitle:
          'GoWith registrará el vencimiento. El escalamiento SOS se implementa en la Fase 5B.',
      options: const [5, 15, 30, 60, 120, 240],
      suffix: 'min',
    );
    if (duration == null || !mounted) return;

    setState(() => _timerAction = true);
    try {
      final timer = await _trackingService.startSafetyTimer(
        requestId: widget.serviceRequestId,
        durationMinutes: duration,
      );
      if (!mounted) return;
      setState(() => _safetyTimer = timer);
      _message('Temporizador de seguridad iniciado.');
    } on DioException catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _timerAction = false);
    }
  }

  Future<void> _cancelSafetyTimer() async {
    setState(() => _timerAction = true);
    try {
      final timer = await _trackingService.cancelSafetyTimer(
        widget.serviceRequestId,
      );
      if (!mounted) return;
      setState(() => _safetyTimer = timer);
      _message('Temporizador cancelado.');
    } on DioException catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _timerAction = false);
    }
  }

  Future<int?> _chooseDuration({
    required String title,
    required String subtitle,
    required List<int> options,
    required String suffix,
  }) {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in options)
                  ActionChip(
                    label: Text('$value $suffix'),
                    onPressed: () => Navigator.of(context).pop(value),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  LatLng? _point(Map<String, dynamic>? location) {
    if (location == null) return null;
    final lat = _double(location['latitude']);
    final lng = _double(location['longitude']);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String _locationAge(Map<String, dynamic>? location) {
    if (location == null) return 'Sin ubicación registrada';
    final at = DateTime.tryParse(location['created_at']?.toString() ?? '');
    if (at == null) return 'Ubicación registrada';
    final diff = DateTime.now().difference(at.toLocal());
    if (diff.inSeconds < 60) return 'Actualizada hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'Actualizada hace ${diff.inMinutes} min';
    return 'Actualizada hace ${diff.inHours} h';
  }

  String _timerStatusLabel() {
    final timer = _safetyTimer;
    if (timer == null) return 'Sin temporizador activo';
    final status = timer['status']?.toString().toUpperCase() ?? '';
    if (status != 'ACTIVE') {
      return switch (status) {
        'EXPIRED' => 'Temporizador vencido',
        'CANCELLED' => 'Temporizador cancelado',
        'COMPLETED' => 'Temporizador cerrado con la actividad',
        _ => 'Temporizador: $status',
      };
    }
    final expiresAt = DateTime.tryParse(timer['expires_at']?.toString() ?? '');
    if (expiresAt == null) return 'Temporizador activo';
    final remaining = expiresAt.toLocal().difference(DateTime.now());
    if (remaining.isNegative) return 'Temporizador venciendo…';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    if (hours > 0) {
      return 'Restan ${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return 'Restan ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail != null) return detail.toString();
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value != null) return value.toString();
      }
    }
    return error.message ?? 'No fue posible completar la operación.';
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isActive) return const SizedBox.shrink();

    final meeting = _mapValue(_snapshot?['meeting_point']);
    final client = _mapValue(_snapshot?['client_location']);
    final provider = _mapValue(_snapshot?['provider_location']);
    final meetingPoint = _point(meeting);
    final clientPoint = _point(client);
    final providerPoint = _point(provider);
    final center =
        clientPoint ??
        providerPoint ??
        meetingPoint ??
        const LatLng(4.6767, -74.0482);
    final distance = _double(_snapshot?['distance_meters']);
    final proximity = _snapshot?['proximity_label']?.toString();
    final timerStatus = _safetyTimer?['status']?.toString().toUpperCase() ?? '';

    final markers = <Marker>[
      if (meetingPoint != null)
        Marker(
          point: meetingPoint,
          width: 44,
          height: 44,
          child: const Tooltip(
            message: 'Punto de encuentro',
            child: Icon(Icons.place, size: 38, color: Colors.deepOrange),
          ),
        ),
      if (clientPoint != null)
        Marker(
          point: clientPoint,
          width: 44,
          height: 44,
          child: const Tooltip(
            message: 'Solicitante',
            child: Icon(Icons.person_pin_circle, size: 38, color: Colors.blue),
          ),
        ),
      if (providerPoint != null)
        Marker(
          point: providerPoint,
          width: 44,
          height: 44,
          child: const Tooltip(
            message: 'Acompañante',
            child: Icon(
              Icons.assistant_navigation,
              size: 38,
              color: Colors.green,
            ),
          ),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ubicación y seguridad',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar mapa',
                  onPressed: _loadingSnapshot ? null : _loadSnapshot,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const Text(
              'El mapa solo está disponible para las personas que participan en esta actividad.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 230,
                child: _snapshot == null
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 15.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'opentic.co.gowith',
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            if (meeting != null)
              Text('Punto de encuentro: ${meeting['text'] ?? '—'}'),
            Text('Solicitante: ${_locationAge(client)}'),
            Text('Acompañante: ${_locationAge(provider)}'),
            if (distance != null)
              Text(
                'Distancia entre participantes: ${distance < 1000 ? '${distance.toStringAsFixed(0)} m' : '${(distance / 1000).toStringAsFixed(2)} km'}${proximity == null ? '' : ' · $proximity'}',
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sendingLocation
                  ? null
                  : (_liveSharing ? _stopLiveSharing : _startLiveSharing),
              icon: Icon(
                _liveSharing ? Icons.location_disabled : Icons.my_location,
              ),
              label: Text(
                _liveSharing
                    ? 'Detener ubicación en vivo'
                    : 'Activar ubicación en vivo',
              ),
            ),
            if (_liveSharing)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Se envía tu GPS aproximadamente cada 15 segundos mientras esta pantalla permanezca abierta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            const Divider(height: 28),
            const Text(
              'Compartir actividad',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Genera un enlace temporal. El enlace público muestra únicamente la ubicación que tú decidiste compartir.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _shareAction ? null : _createShareLink,
                  icon: const Icon(Icons.link),
                  label: const Text('Generar enlace'),
                ),
                OutlinedButton.icon(
                  onPressed: _shareAction ? null : _revokeShareLink,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Revocar'),
                ),
              ],
            ),
            if (_shareUrl != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                _shareUrl!,
                maxLines: 3,
                style: const TextStyle(fontSize: 12),
              ),
              if (_shareExpiresAt != null)
                Text(
                  'Vence: ${_shareExpiresAt!.toString().substring(0, 16)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _shareUrl!));
                  _message('Enlace copiado.');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar enlace'),
              ),
            ],
            const Divider(height: 28),
            const Text(
              'Temporizador de seguridad',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(_timerStatusLabel()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _timerAction ? null : _startSafetyTimer,
                  icon: const Icon(Icons.timer_outlined),
                  label: Text(
                    timerStatus == 'ACTIVE'
                        ? 'Reiniciar temporizador'
                        : 'Iniciar temporizador',
                  ),
                ),
                if (timerStatus == 'ACTIVE')
                  OutlinedButton.icon(
                    onPressed: _timerAction ? null : _cancelSafetyTimer,
                    icon: const Icon(Icons.timer_off_outlined),
                    label: const Text('Cancelar'),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Fase 5A registra y controla el temporizador. La alerta SOS y el escalamiento a contactos se incorporan en Fase 5B.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
