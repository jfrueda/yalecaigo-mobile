import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../service_request/data/location_ping_service.dart';

class ProviderActiveServicePage extends StatefulWidget {
  final Map<String, dynamic> serviceRequest;

  const ProviderActiveServicePage({super.key, required this.serviceRequest});

  @override
  State<ProviderActiveServicePage> createState() => _ProviderActiveServicePageState();
}

class _ProviderActiveServicePageState extends State<ProviderActiveServicePage> {
  final _pingService = LocationPingService();

  String? _result;
  bool _loading = false;

  int? get _srId {
    final id = widget.serviceRequest['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  double _safeDouble(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
  }

  Future<void> _sendPing() async {
    final id = _srId;
    if (id == null) {
      setState(() => _result = '❌ No tengo ID de solicitud para enviar ping');
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final lat = _safeDouble(widget.serviceRequest['location_lat'], 4.6767);
      final lng = _safeDouble(widget.serviceRequest['location_lng'], -74.0482);

      final res = await _pingService.createPing(
        serviceRequestId: id,
        locationLat: lat,
        locationLng: lng,
        recordedAt: DateTime.now(),
      );

      setState(() => _result = '✅ Ping enviado (${res.statusCode}): ${res.data}');
    } catch (e) {
      String msg = '❌ Error enviando ping: $e';
      if (e is DioException) msg = '❌ Error (${e.response?.statusCode}): ${e.response?.data}';
      setState(() => _result = msg);
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _kv(String k, dynamic v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text('$k:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(v?.toString() ?? '—')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sr = widget.serviceRequest;

    return Scaffold(
      appBar: AppBar(title: const Text('Servicio activo (Prestador)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Solicitud', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _kv('ID', sr['id']),
            _kv('Ubicación', sr['location_text']),
            _kv('Lat', sr['location_lat']),
            _kv('Lng', sr['location_lng']),
            _kv('Inicio', sr['requested_start_time']),
            _kv('Duración', sr['requested_duration_minutes']),
            _kv('Estado', sr['status'] ?? 'active'),

            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _sendPing,
              icon: const Icon(Icons.my_location),
              label: _loading ? const Text('Enviando...') : const Text('Enviar ping'),
            ),

            const SizedBox(height: 12),
            if (_result != null)
              Text(
                _result!,
                style: TextStyle(color: _result!.startsWith('✅') ? Colors.green : Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
