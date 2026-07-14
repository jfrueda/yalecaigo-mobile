import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/app_components.dart';

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
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double _double(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _accept() async {
    final requestId = _id;
    if (requestId == null) {
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final response = await ApiClient.dio.post(
        Endpoints.acceptRequest(requestId),
      );
      if (!mounted) {
        return;
      }
      setState(
        () => _request = Map<String, dynamic>.from(response.data as Map),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final data = error.response?.data;
      setState(() {
        _message = data is Map
            ? data['detail']?.toString() ??
                  'No fue posible aceptar la actividad.'
            : 'No fue posible aceptar la actividad.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
      appBar: AppBar(title: const Text('Revisar actividad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          120,
        ),
        children: [
          AppStatusPill(
            label: 'Solicitud disponible',
            color: AppColors.primaryMedium,
            icon: Icons.work_outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _request['category_name']?.toString() ?? 'Acompañamiento',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Revisa los detalles antes de aceptar.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSurfaceCard(
            child: Column(
              children: [
                AppInfoRow(
                  icon: Icons.place_outlined,
                  label: 'Punto de encuentro',
                  value:
                      _request['location_text']?.toString() ?? 'Sin ubicación',
                ),
                const Divider(),
                AppInfoRow(
                  icon: Icons.event_available_outlined,
                  label: 'Inicio',
                  value: formatDateTime(_request['requested_start_time']),
                ),
                const Divider(),
                AppInfoRow(
                  icon: Icons.timer_outlined,
                  label: 'Duración',
                  value:
                      '${_request['requested_duration_minutes'] ?? '—'} minutos',
                ),
                const Divider(),
                AppInfoRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Ganancia estimada',
                  value: formatCop(payment['provider_amount']),
                  valueColor: AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
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
                        width: 48,
                        height: 48,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33173F4D),
                                blurRadius: 12,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSurfaceCard(
            backgroundColor: AppColors.tint(AppColors.primary, 0.06),
            borderColor: AppColors.tint(AppColors.primary, 0.22),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Condiciones de la actividad',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AppSpacing.md),
                _SafetyLine(
                  icon: Icons.store_mall_directory_outlined,
                  text: 'Punto público validado',
                ),
                _SafetyLine(
                  icon: Icons.lock_outline_rounded,
                  text: 'Pago protegido',
                ),
                _SafetyLine(
                  icon: Icons.verified_user_outlined,
                  text: 'Solicitante identificado',
                ),
              ],
            ),
          ),
          if ((_request['notes']?.toString().trim() ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppSurfaceCard(
              child: AppInfoRow(
                icon: Icons.notes_outlined,
                label: 'Indicación del solicitante',
                value: _request['notes'].toString(),
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : _accept,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_loading ? 'Aceptando…' : 'Aceptar actividad'),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('No me interesa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyLine extends StatelessWidget {
  const _SafetyLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
