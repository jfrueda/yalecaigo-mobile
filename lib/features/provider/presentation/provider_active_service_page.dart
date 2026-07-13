import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../service_request/data/location_ping_service.dart';
import '../../service_request/data/service_request_query_service.dart';

class ProviderActiveServicePage extends StatefulWidget {
  const ProviderActiveServicePage({super.key, required this.serviceRequest});

  final Map<String, dynamic> serviceRequest;

  @override
  State<ProviderActiveServicePage> createState() =>
      _ProviderActiveServicePageState();
}

class _ProviderActiveServicePageState extends State<ProviderActiveServicePage> {
  final _pingService = LocationPingService();
  final _queryService = ServiceRequestQueryService();

  late Map<String, dynamic> _request;
  String? _result;
  bool _loading = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _request = Map<String, dynamic>.from(widget.serviceRequest);
  }

  int? get _requestId {
    final id = _request['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _refresh() async {
    final id = _requestId;
    if (id == null) return;
    setState(() => _refreshing = true);
    try {
      final fresh = await _queryService.getRequestById(id);
      if (!mounted) return;
      if (fresh != null) setState(() => _request = fresh);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _result =
            'No se pudo actualizar (HTTP '
            '${error.response?.statusCode ?? '-'}).';
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _sendPing() async {
    final id = _requestId;
    if (id == null) {
      setState(() => _result = 'No hay un ID válido de solicitud.');
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final latitude = _asDouble(_request['location_lat'], 4.6767);
      final longitude = _asDouble(_request['location_lng'], -74.0482);
      await _pingService.createPing(
        serviceRequestId: id,
        locationLat: latitude,
        locationLng: longitude,
        source: 'simulated',
      );
      if (!mounted) return;
      setState(() => _result = 'Ping de prueba enviado correctamente.');
      await _refresh();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _result =
            'Error ${error.response?.statusCode ?? '-'}: '
            '${error.response?.data ?? error.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _result = 'No fue posible enviar el ping de prueba.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value?.toString() ?? '—')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicio activo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_refreshing) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          _row('ID', _request['id']),
          _row('Categoría', _request['category_name']),
          _row('Ubicación', _request['location_text']),
          _row('Inicio', _request['requested_start_time']),
          _row('Duración', _request['requested_duration_minutes']),
          _row('Estado', _request['status']),
          _row('Cliente', _request['client_username']),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Modo de desarrollo: este botón usa las coordenadas del punto '
                'de encuentro. Todavía no captura el GPS real del teléfono.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _sendPing,
            icon: const Icon(Icons.my_location),
            label: Text(_loading ? 'Enviando…' : 'Enviar ping de prueba'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(_result!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
