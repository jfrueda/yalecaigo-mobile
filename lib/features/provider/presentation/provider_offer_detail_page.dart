import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/provider_offer_service.dart';
import 'provider_active_service_page.dart';

class ProviderOfferDetailPage extends StatefulWidget {
  final Map<String, dynamic> offer;

  const ProviderOfferDetailPage({super.key, required this.offer});

  @override
  State<ProviderOfferDetailPage> createState() =>
      _ProviderOfferDetailPageState();
}

class _ProviderOfferDetailPageState extends State<ProviderOfferDetailPage> {
  final _service = ProviderOfferService();

  bool _loading = false;
  String? _result;

  Map<String, dynamic> get _offer => widget.offer;

  Map<String, dynamic>? get _serviceRequest => _offer['service_request'] is Map
      ? Map<String, dynamic>.from(_offer['service_request'] as Map)
      : null;

  Future<void> _accept() async {
    final id = _offer['id'];
    if (id is! int) {
      setState(() => _result = 'Oferta sin identificador válido.');
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final response = await _service.acceptOffer(id);
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final serviceRequest = data['service_request'] is Map
          ? Map<String, dynamic>.from(data['service_request'] as Map)
          : (_serviceRequest ?? <String, dynamic>{});

      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ProviderActiveServicePage(serviceRequest: serviceRequest),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result =
            'Error (${error.response?.statusCode ?? '-'}): '
            '${error.response?.data ?? error.message}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _result = 'No fue posible aceptar la oferta: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reject() async {
    final id = _offer['id'];
    if (id is! int) {
      setState(() => _result = 'Oferta sin identificador válido.');
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      await _service.rejectOffer(id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result =
            'Error (${error.response?.statusCode ?? '-'}): '
            '${error.response?.data ?? error.message}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _result = 'No fue posible ocultar la oferta: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _item(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
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
    final request = _serviceRequest;
    final offerId = _offer['id']?.toString() ?? '—';

    return Scaffold(
      appBar: AppBar(title: Text('Oferta #$offerId')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Detalle de solicitud',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _item('Ubicación', request?['location_text']),
            _item('Latitud', request?['location_lat']),
            _item('Longitud', request?['location_lng']),
            _item('Inicio', request?['requested_start_time']),
            _item('Duración (min)', request?['requested_duration_minutes']),
            _item('Preferencia género', request?['preferred_gender']),
            _item('Edad mínima', request?['preferred_age_min']),
            _item('Edad máxima', request?['preferred_age_max']),
            _item('Estado', request?['status'] ?? _offer['status']),
            _item(
              'Precio',
              _offer['proposed_price'] ?? request?['calculated_price'],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _accept,
                    icon: const Icon(Icons.check),
                    label: Text(_loading ? 'Procesando...' : 'Aceptar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _reject,
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('No me interesa'),
                  ),
                ),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(
                _result!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
