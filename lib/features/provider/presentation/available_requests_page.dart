import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/app_components.dart';
import '../../service_request/data/service_request_query_service.dart';
import 'provider_request_detail_page.dart';

class AvailableRequestsPage extends StatefulWidget {
  const AvailableRequestsPage({
    super.key,
    this.embedded = false,
    this.onOpenOnboarding,
  });

  final bool embedded;
  final VoidCallback? onOpenOnboarding;

  @override
  State<AvailableRequestsPage> createState() => _AvailableRequestsPageState();
}

class _AvailableRequestsPageState extends State<AvailableRequestsPage> {
  final ServiceRequestQueryService _queryService = ServiceRequestQueryService();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _requests = const [];
  final Set<int> _dismissingIds = <int>{};
  bool _authorizationPending = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  int? _requestId(Map<String, dynamic> request) {
    final raw = request['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _loadRequests() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _authorizationPending = false;
      });
    }

    try {
      final response = await ApiClient.dio.get(Endpoints.availableRequests);
      final data = response.data;
      dynamic raw = data;
      if (raw is Map && raw['results'] is List) raw = raw['results'];

      final requests = raw is List
          ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() => _requests = requests);
    } on DioException catch (error) {
      if (!mounted) return;
      final status = error.response?.statusCode;
      setState(() {
        _authorizationPending = status == 403;
        _error = status == 403
            ? 'Tu cuenta aún no está autorizada. Completa los requisitos de habilitación y mantén al menos una actividad aprobada y seleccionada.'
            : apiErrorMessage(
                error,
                fallback: 'No se pudieron cargar las actividades.',
              );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No pudimos cargar las actividades disponibles.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss(Map<String, dynamic> request) async {
    final id = _requestId(request);
    if (id == null || _dismissingIds.contains(id)) return;

    setState(() => _dismissingIds.add(id));
    try {
      await _queryService.dismissRequest(id);
      if (!mounted) return;
      setState(() {
        _requests = _requests.where((item) => _requestId(item) != id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La actividad se ocultó de tu panel.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: 'No fue posible ocultar la actividad.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _dismissingIds.remove(id));
    }
  }

  Widget _card(Map<String, dynamic> request) {
    final id = _requestId(request);
    final dismissing = id != null && _dismissingIds.contains(id);
    final gender = request['preferred_gender']?.toString();
    final ageMin = request['preferred_age_min'];
    final ageMax = request['preferred_age_max'];
    final preferences = <String>[];
    if (gender != null && gender.isNotEmpty) {
      preferences.add('Género: $gender');
    }
    if (ageMin != null || ageMax != null) {
      preferences.add('Edad: ${ageMin ?? '-'} a ${ageMax ?? '-'}');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => ProviderRequestDetailPage(request: request),
                  ),
                );
                if (changed == true) await _loadRequests();
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.tint(AppColors.primary, 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.people_alt_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceActivityLabel(request),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request['location_text']?.toString() ??
                              'Sin ubicación',
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${request['requested_duration_minutes'] ?? '-'} min · '
                          '${request['calculated_price'] ?? '-'} COP',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            if (preferences.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: preferences
                    .map(
                      (item) =>
                          AppStatusPill(label: item, color: AppColors.coral),
                    )
                    .toList(),
              ),
            ],
            const Divider(height: 28),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: dismissing ? null : () => _dismiss(request),
                icon: dismissing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_off_outlined),
                label: const Text('No me interesa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _loadRequests,
      child: _loading && _requests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              children: [
                const AppSectionHeader(
                  title: 'Actividades disponibles',
                  subtitle:
                      'Solo se muestran solicitudes que coinciden con tus actividades aprobadas, preferencias aplicables y agenda disponible.',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null)
                  AppSurfaceCard(
                    backgroundColor: AppColors.coralSoft,
                    borderColor: AppColors.tint(AppColors.danger, 0.28),
                    child: Column(
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed:
                              _authorizationPending &&
                                  widget.onOpenOnboarding != null
                              ? widget.onOpenOnboarding
                              : _loadRequests,
                          icon: Icon(
                            _authorizationPending
                                ? Icons.fact_check_outlined
                                : Icons.refresh_rounded,
                          ),
                          label: Text(
                            _authorizationPending
                                ? 'Ver requisitos pendientes'
                                : 'Reintentar',
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_requests.isEmpty)
                  const AppEmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No hay actividades compatibles en este momento',
                    message:
                        'Aquí aparecerán solicitudes que coincidan con tus actividades seleccionadas, tu disponibilidad y tu agenda. Si desactivaste todas, actívalas nuevamente en Cuenta.',
                  )
                else
                  ..._requests.map(_card),
              ],
            ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividades'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _loadRequests,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }
}
