import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/utils/service_display.dart';

class ProviderRequestDetailPage extends StatefulWidget {
  const ProviderRequestDetailPage({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  State<ProviderRequestDetailPage> createState() =>
      _ProviderRequestDetailPageState();
}

class _ProviderRequestDetailPageState extends State<ProviderRequestDetailPage> {
  late Map<String, dynamic> _request;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _request = Map<String, dynamic>.from(widget.request);
  }

  int? get _id {
    final value = _request['id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  double _double(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _accept() async {
    final requestId = _id;
    if (requestId == null) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final response = await ApiClient.dio.post(
        Endpoints.acceptRequest(requestId),
      );
      if (!mounted) return;
      setState(
        () => _request = Map<String, dynamic>.from(response.data as Map),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      setState(() {
        _message = data is Map
            ? data['detail']?.toString() ?? 'No fue posible aceptar.'
            : 'No fue posible aceptar.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(
      _double(_request['location_lat'], 4.6767),
      _double(_request['location_lng'], -74.0482),
    );
    final payment = _request['payment'] is Map
        ? Map<String, dynamic>.from(_request['payment'] as Map)
        : <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de solicitud')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _request['category_name']?.toString() ?? 'Acompañamiento',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_request['location_text']?.toString() ?? 'Sin ubicación'),
          Text('Inicio: ${formatDateTime(_request['requested_start_time'])}'),
          Text(
            'Duración: ${_request['requested_duration_minutes'] ?? '—'} min',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(initialCenter: point, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'opentic.co.yalecaigo',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.location_pin,
                          size: 44,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pago y ganancia',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Pago: ${paymentStatusLabel(payment['status'])}'),
                  Text('Valor total: ${formatCop(payment['amount_total'])}'),
                  Text('Comisión: ${formatCop(payment['platform_fee'])}'),
                  Text(
                    'Recibirías: ${formatCop(payment['provider_amount'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          if ((_request['notes']?.toString().trim() ?? '').isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Notas: ${_request['notes']}'),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _accept,
            icon: const Icon(Icons.check),
            label: Text(_loading ? 'Aceptando…' : 'Aceptar solicitud'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
