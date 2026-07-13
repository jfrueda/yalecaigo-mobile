import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';

class ProviderRequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> request;

  const ProviderRequestDetailPage({super.key, required this.request});

  @override
  State<ProviderRequestDetailPage> createState() =>
      _ProviderRequestDetailPageState();
}

class _ProviderRequestDetailPageState extends State<ProviderRequestDetailPage> {
  bool _loading = false;
  String? _msg;
  late Map<String, dynamic> _req;

  @override
  void initState() {
    super.initState();
    _req = Map<String, dynamic>.from(widget.request);
  }

  // ---------- helpers
  String _s(dynamic v, [String fallback = '-']) {
    if (v == null) return fallback;
    final t = v.toString().trim();
    return t.isEmpty ? fallback : t;
  }

  int? _i(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  double? _d(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? get _id => _i(_req['id']);
  bool get _isPending => _s(_req['status'], '').toLowerCase() == 'pending';
  bool get _hasProvider =>
      _req.containsKey('assigned_provider') && _req['assigned_provider'] != null;

  LatLng get _latLng {
    final lat = _d(_req['location_lat']) ?? 4.6767;
    final lng = _d(_req['location_lng']) ?? -74.0482;
    return LatLng(lat, lng);
  }

  Future<void> _acceptRequest() async {
    final id = _id;
    if (id == null) {
      setState(() => _msg = '❌ No hay id de solicitud');
      return;
    }

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final res = await ApiClient.dio.post('/services/requests/$id/accept/');
      final updated = Map<String, dynamic>.from(res.data ?? {});
      if (!mounted) return;

      setState(() {
        _req = {..._req, ...updated};
        _msg = '✅ Solicitud aceptada';
      });

      // Volver a la lista marcando que hubo cambios
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      });
    } catch (e) {
      String msg = '❌ Error aceptando: $e';
      if (e is DioException) {
        msg = '❌ Error (${e.response?.statusCode}): ${e.response?.data}';
      }
      setState(() => _msg = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _mapPreview() {
    final point = _latLng;
    final marker = Marker(
      point: point,
      width: 40,
      height: 40,
      child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'opentic.co.yalecaigo',
            ),
            MarkerLayer(markers: [marker]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationText = _s(_req['location_text'], 'Sin ubicación');
    final status = _s(_req['status'], 'unknown');
    final duration = _s(_req['requested_duration_minutes']);
    final startTime = _s(_req['requested_start_time']);
    final price = _s(_req['calculated_price']);

    final preferredGender = _s(_req['preferred_gender'], 'Sin preferencia');
    final ageMin = _s(_req['preferred_age_min'], '');
    final ageMax = _s(_req['preferred_age_max'], '');
    final ageLabel =
    (ageMin.isNotEmpty && ageMin != '-' && ageMax.isNotEmpty && ageMax != '-')
        ? '$ageMin a $ageMax'
        : 'Sin preferencia';

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle (prestador)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(locationText,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Estado: $status'),
          const SizedBox(height: 8),
          Text('Duración: $duration min'),
          Text('Inicio: $startTime'),
          Text('Valor: $price COP'),
          const SizedBox(height: 12),
          _mapPreview(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preferencias',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Género: $preferredGender'),
                  Text('Edad: $ageLabel'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ✅ Solo aparece si está pending y aún no tiene proveedor
          if (_isPending && !_hasProvider)
            ElevatedButton.icon(
              onPressed: _loading ? null : _acceptRequest,
              icon: const Icon(Icons.check),
              label: _loading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Aceptar solicitud'),
            ),

          if (_msg != null) ...[
            const SizedBox(height: 12),
            Text(
              _msg!,
              style: TextStyle(
                color: _msg!.startsWith('✅') ? Colors.green : Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
