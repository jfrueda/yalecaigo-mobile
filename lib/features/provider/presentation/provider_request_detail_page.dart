import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../service_request/data/service_request_query_service.dart';

class ProviderRequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> request;

  const ProviderRequestDetailPage({super.key, required this.request});

  @override
  State<ProviderRequestDetailPage> createState() =>
      _ProviderRequestDetailPageState();
}

class _ProviderRequestDetailPageState extends State<ProviderRequestDetailPage> {
  final _queryService = ServiceRequestQueryService();

  bool _loading = false;
  String? _message;
  late Map<String, dynamic> _request;

  @override
  void initState() {
    super.initState();
    _request = Map<String, dynamic>.from(widget.request);
  }

  String _string(dynamic value, [String fallback = '-']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int? _integer(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? get _id => _integer(_request['id']);

  bool get _isPending {
    final status = _string(_request['status'], '').toLowerCase();
    return const {'pending', 'searching'}.contains(status);
  }

  bool get _hasProvider => _request['assigned_provider'] != null;

  LatLng get _position => LatLng(
    _double(_request['location_lat']) ?? 4.6767,
    _double(_request['location_lng']) ?? -74.0482,
  );

  Future<void> _acceptRequest() async {
    final id = _id;
    if (id == null) {
      setState(
        () => _message = 'No se encontró el identificador de la solicitud.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final response = await ApiClient.dio.post<dynamic>(
        Endpoints.acceptRequest(id),
      );
      final data = response.data;
      if (data is Map) {
        _request = {..._request, ...Map<String, dynamic>.from(data)};
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _apiMessage(error, 'No fue posible aceptar la solicitud.');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _dismissRequest() async {
    final id = _id;
    if (id == null) {
      setState(
        () => _message = 'No se encontró el identificador de la solicitud.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ocultar esta actividad'),
        content: const Text(
          'La actividad dejará de aparecer en tu panel. Esta acción no afecta '
          'a otros acompañantes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('No me interesa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await _queryService.dismissRequest(id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _apiMessage(error, 'No fue posible ocultar la actividad.');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _apiMessage(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail != null) return detail.toString();
    }
    return fallback;
  }

  Widget _mapPreview() {
    final point = _position;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 210,
        child: FlutterMap(
          options: MapOptions(initialCenter: point, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'opentic.co.gowith',
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
                    color: AppColors.coral,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = _string(_request['location_text'], 'Sin ubicación');
    final status = _string(_request['status'], 'unknown');
    final duration = _string(_request['requested_duration_minutes']);
    final startTime = _string(_request['requested_start_time']);
    final price = _string(_request['calculated_price']);
    final preferredGender = _string(
      _request['preferred_gender_label'] ?? _request['preferred_gender'],
      'Sin preferencia',
    );
    final ageMin = _integer(_request['preferred_age_min']);
    final ageMax = _integer(_request['preferred_age_max']);
    final ageLabel = ageMin == null && ageMax == null
        ? 'Sin preferencia'
        : '${ageMin ?? '—'} a ${ageMax ?? '—'} años';

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de actividad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            location,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 8),
          Text('Estado: $status'),
          Text('Duración: $duration min'),
          Text('Inicio: $startTime'),
          Text('Valor: $price COP'),
          const SizedBox(height: 16),
          _mapPreview(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preferencias solicitadas',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text('Género: $preferredGender'),
                  Text('Edad: $ageLabel'),
                  const SizedBox(height: 10),
                  const Text(
                    'Esta actividad solo aparece si tu perfil cumple las '
                    'preferencias y tienes la categoría aprobada.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_isPending && !_hasProvider) ...[
            FilledButton.icon(
              onPressed: _loading ? null : _acceptRequest,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_loading ? 'Procesando…' : 'Aceptar actividad'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loading ? null : _dismissRequest,
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('No me interesa'),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 14),
            Text(
              _message!,
              style: const TextStyle(
                color: AppColors.coral,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
