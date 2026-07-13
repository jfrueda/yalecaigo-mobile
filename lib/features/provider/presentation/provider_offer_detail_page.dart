import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/provider_offer_service.dart';
import 'provider_active_service_page.dart';

class ProviderOfferDetailPage extends StatefulWidget {
  final Map<String, dynamic> offer;

  const ProviderOfferDetailPage({super.key, required this.offer});

  @override
  State<ProviderOfferDetailPage> createState() => _ProviderOfferDetailPageState();
}

class _ProviderOfferDetailPageState extends State<ProviderOfferDetailPage> {
  final _service = ProviderOfferService();

  bool _loading = false;
  String? _result;

  Map<String, dynamic> get _offer => widget.offer;
  Map<String, dynamic>? get _sr => (_offer['service_request'] is Map)
      ? Map<String, dynamic>.from(_offer['service_request'])
      : null;

  Future<void> _accept() async {
    final id = _offer['id'];
    if (id is! int) {
      setState(() => _result = '❌ Oferta sin id válido');
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final res = await _service.acceptOffer(id);

      // intentamos usar data retornada; si no, usamos la solicitud embebida
      final data = (res.data is Map) ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};
      final sr = data['service_request'] is Map
          ? Map<String, dynamic>.from(data['service_request'])
          : (_sr ?? <String, dynamic>{});

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProviderActiveServicePage(serviceRequest: sr),
        ),
      );
    } catch (e) {
      String msg = '❌ Error aceptando: $e';
      if (e is DioException) msg = '❌ Error (${e.response?.statusCode}): ${e.response?.data}';
      setState(() => _result = msg);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final id = _offer['id'];
    if (id is! int) {
      setState(() => _result = '❌ Oferta sin id válido');
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      await _service.rejectOffer(id);
      if (!mounted) return;
      Navigator.of(context).pop(); // vuelve a la lista
    } catch (e) {
      String msg = '❌ Error rechazando: $e';
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
          SizedBox(width: 170, child: Text('$k:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(v?.toString() ?? '—')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sr = _sr;
    final offerId = _offer['id']?.toString() ?? '—';

    return Scaffold(
      appBar: AppBar(title: Text('Oferta #$offerId')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Detalle de solicitud', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _kv('Ubicación', sr?['location_text']),
            _kv('Latitud', sr?['location_lat']),
            _kv('Longitud', sr?['location_lng']),
            _kv('Inicio', sr?['requested_start_time']),
            _kv('Duración (min)', sr?['requested_duration_minutes']),
            _kv('Preferencia género', sr?['preferred_gender']),
            _kv('Edad min', sr?['preferred_age_min']),
            _kv('Edad max', sr?['preferred_age_max']),
            _kv('Estado', sr?['status'] ?? _offer['status']),
            _kv('Precio', _offer['proposed_price'] ?? sr?['calculated_price']),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _accept,
                    icon: const Icon(Icons.check),
                    label: _loading ? const Text('Procesando...') : const Text('Aceptar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _reject,
                    icon: const Icon(Icons.close),
                    label: const Text('Rechazar'),
                  ),
                ),
              ],
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
