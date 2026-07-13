import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/location_ping_service.dart';
import '../data/service_request_query_service.dart';

class RequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> request;

  const RequestDetailPage({super.key, required this.request});

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  final _queryService = ServiceRequestQueryService();
  final _pingService = LocationPingService();

  Map<String, dynamic> _request = {};
  Timer? _refreshTimer;
  Timer? _pingTimer;

  bool _refreshing = false;
  bool _sendingPing = false;

  static const _activeStatuses = ['pending', 'matched', 'started'];

  @override
  void initState() {
    super.initState();
    _request = Map<String, dynamic>.from(widget.request);
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }

  // -----------------------------
  // Helpers (null-safe)
  // -----------------------------
  int? _requestId() {
    final v = _request['id'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  String _s(dynamic v, {String fallback = '-'}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool _isActiveStatus() {
    final status = _s(_request['status'], fallback: 'unknown');
    return _activeStatuses.contains(status);
  }

  // -----------------------------
  // Auto-refresh (B)
  // -----------------------------
  void _startAutoRefresh() {
    _refreshTimer?.cancel();

    // Polling cada 10s para traer cambios de estado/datos
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _reloadFromBackend();
    });
  }

  Future<void> _reloadFromBackend() async {
    final id = _requestId();
    if (id == null) return;

    if (mounted) setState(() => _refreshing = true);
    try {
      final fresh = await _queryService.getRequestById(id);
      if (!mounted) return;

      if (fresh != null) {
        // ✅ IMPORTANTE: actualiza pero NO rompe el detalle/UX
        setState(() => _request = fresh);

        // Si ya NO está activa, detenemos auto ping (si estaba corriendo)
        if (!_isActiveStatus()) {
          _pingTimer?.cancel();
          _pingTimer = null;
        }
      }
    } catch (_) {
      // MVP: silencioso para no molestar al usuario
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  // -----------------------------
  // Ping manual y auto ping
  // -----------------------------
  Future<void> _sendPingOnce() async {
    final id = _requestId();
    if (id == null) {
      _snack('❌ No tengo ID válido de solicitud.');
      return;
    }

    // MVP: si ya no está activa, no enviamos pings
    if (!_isActiveStatus()) {
      _snack('ℹ️ La solicitud no está activa. No se envían pings.');
      return;
    }

    final lat = _d(_request['location_lat']) ?? _d(_request['latitude']) ?? 4.6767;
    final lng = _d(_request['location_lng']) ?? _d(_request['longitude']) ?? -74.0482;

    setState(() => _sendingPing = true);
    try {
      final res = await _pingService.createPing(
        serviceRequestId: id,
        locationLat: lat,
        locationLng: lng,
        recordedAt: DateTime.now(),
      );

      final data = res.data;
      _snack('✅ Ping enviado (201): $data');

      // opcional: refrescar inmediatamente para ver cambios de backend
      await _reloadFromBackend();
    } on DioException catch (e) {
      _snack('❌ Error (${e.response?.statusCode}): ${e.response?.data}');
    } catch (e) {
      _snack('❌ Error enviando ping: $e');
    } finally {
      if (mounted) setState(() => _sendingPing = false);
    }
  }

  void _startAutoPing() {
    final id = _requestId();
    if (id == null) {
      _snack('❌ No tengo ID válido de solicitud.');
      return;
    }
    if (!_isActiveStatus()) {
      _snack('ℹ️ La solicitud no está activa. No se inicia auto-ping.');
      return;
    }

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _sendPingOnce();
    });

    _snack('📍 Auto-ping iniciado (cada 15s)');
  }

  void _stopAutoPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _snack('🛑 Auto-ping detenido');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final id = _requestId();
    final status = _s(_request['status'], fallback: 'unknown');

    final locationText = _s(_request['location_text']);
    final start = _s(_request['requested_start_time']);
    final duration = _s(_request['requested_duration_minutes']);
    final createdAt = _s(_request['created_at']);
    final endedAt = _s(_request['ended_at']);

    final preferredGender = _s(_request['preferred_gender'], fallback: 'Sin preferencia');
    final ageMin = _request['preferred_age_min'];
    final ageMax = _request['preferred_age_max'];
    final prefAge = (ageMin == null && ageMax == null)
        ? 'Sin preferencia'
        : '${_s(ageMin, fallback: '-') } - ${_s(ageMax, fallback: '-') }';

    final price = _request['calculated_price']; // por ahora puede ser 0 en MVP

    final isActive = _activeStatuses.contains(status);

    return Scaffold(
      appBar: AppBar(
        title: Text(id == null ? 'Solicitud' : 'Solicitud #$id'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _reloadFromBackend,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _StatusBadge(status: status),
            const SizedBox(height: 12),

            _kv('Estado', status),
            _kv('Ubicación', locationText),
            _kv('Inicio', start),
            _kv('Duración (min)', duration),
            _kv('Creada', createdAt),
            _kv('Finalizada', endedAt),

            const Divider(height: 32),

            const Text('Preferencias', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _kv('Género', preferredGender),
            _kv('Edad', prefAge),

            const Divider(height: 32),

            const Text('Valor', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _kv('Valor estimado', _s(price, fallback: '0')),

            const Divider(height: 32),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendingPing ? null : _sendPingOnce,
                    icon: const Icon(Icons.my_location),
                    label: Text(_sendingPing ? 'Enviando…' : 'Ping manual'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_pingTimer == null && isActive) ? _startAutoPing : null,
                    child: const Text('Iniciar auto-ping'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_pingTimer != null) ? _stopAutoPing : null,
                    child: const Text('Detener auto-ping'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_refreshing)
              const Text(
                'Actualizando estado…',
                style: TextStyle(color: Colors.grey),
              ),

            if (!isActive) ...[
              const SizedBox(height: 8),
              Text(
                'ℹ️ Esta solicitud ya no está activa. Puedes crear una nueva desde Home.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text('$k:')),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color _color(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'matched':
        return Colors.blue;
      case 'started':
        return Colors.green;
      case 'expired':
      case 'ended':
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = status.trim().isEmpty ? 'unknown' : status;
    return Chip(
      label: Text(
        s.toUpperCase(),
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: _color(s),
    );
  }
}
