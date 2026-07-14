import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/service_rating_dialog.dart';
import '../../account/presentation/account_overview_page.dart';
import '../../auth/data/me_service.dart';
import '../../auth/presentation/login_page.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../service_request/data/service_lifecycle_service.dart';
import '../../service_request/data/service_request_query_service.dart';
import 'provider_active_service_page.dart';
import 'provider_history_page.dart';
import 'provider_request_detail_page.dart';

class AvailableRequestsPage extends StatefulWidget {
  const AvailableRequestsPage({super.key});

  @override
  State<AvailableRequestsPage> createState() => _AvailableRequestsPageState();
}

class _AvailableRequestsPageState extends State<AvailableRequestsPage> {
  final _queryService = ServiceRequestQueryService();
  final _lifecycleService = ServiceLifecycleService();
  final _meService = MeService();

  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  Map<String, dynamic>? _activeRequest;
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _requests = const [];
  List<Map<String, dynamic>> _history = const [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  bool _bool(dynamic value) => value == true;
  double _money(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

  int? _requestId(Map<String, dynamic> request) {
    final value = request['id'];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final value = data['detail'] ?? data['score'] ?? data.values.firstOrNull;
      if (value != null) {
        return value.toString();
      }
    }
    return error.message ?? 'No fue posible completar la operación.';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        _meService.getMe(),
        _queryService.getActiveRequest(fallbackToList: false),
        _queryService.listProviderHistory(),
      ]);
      final me = Map<String, dynamic>.from(results[0] as Map);
      final active = results[1] as Map<String, dynamic>?;
      final history = List<Map<String, dynamic>>.from(results[2] as List);
      final available = active == null
          ? await _queryService.listAvailableRequests()
          : const <Map<String, dynamic>>[];

      if (!mounted) {
        return;
      }
      setState(() {
        _me = me;
        _activeRequest = active;
        _requests = available;
        _history = history;
      });
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.response?.statusCode == 403
            ? 'Tu cuenta de acompañante todavía no está verificada.'
            : 'No pudimos cargar tu panel.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clear();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _openActive() async {
    final request = _activeRequest;
    if (request == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProviderActiveServicePage(serviceRequest: request),
      ),
    );
    await _loadDashboard();
  }

  Future<void> _finishAndRate(Map<String, dynamic> request) async {
    final requestId = _requestId(request);
    if (requestId == null) {
      return;
    }
    final rating = await showRequiredServiceRatingDialog(
      context,
      targetLabel: 'el solicitante',
    );
    if (rating == null || !mounted) {
      return;
    }

    setState(() => _actionLoading = true);
    try {
      await _lifecycleService.finish(requestId);
      try {
        await _lifecycleService.rate(
          requestId: requestId,
          score: rating.score,
          comment: rating.comment,
        );
      } on DioException catch (error) {
        _showMessage(
          'La finalización quedó registrada, pero la calificación no pudo guardarse: ${_errorMessage(error)}',
        );
      }
      _showMessage(
        'Actividad finalizada y valor transferido a tu cuenta demo.',
      );
      await _loadDashboard();
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _rateOnly(Map<String, dynamic> request) async {
    final requestId = _requestId(request);
    if (requestId == null) {
      return;
    }
    final rating = await showRequiredServiceRatingDialog(
      context,
      targetLabel: 'el solicitante',
      includeFinishMessage: false,
    );
    if (rating == null || !mounted) {
      return;
    }

    setState(() => _actionLoading = true);
    try {
      await _lifecycleService.rate(
        requestId: requestId,
        score: rating.score,
        comment: rating.comment,
      );
      _showMessage('Calificación registrada.');
      await _loadDashboard();
    } on DioException catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  String get _title {
    switch (_selectedIndex) {
      case 1:
        return 'Servicios';
      case 2:
        return 'Ganancias';
      case 3:
        return 'Cuenta';
      default:
        return 'YaLeCaigo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              tooltip: 'Notificaciones',
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          if (_selectedIndex != 3)
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? null : _loadDashboard,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _homeTab(),
                _servicesTab(),
                ProviderHistoryPage(
                  embedded: true,
                  initialItems: _history,
                  onChanged: _loadDashboard,
                ),
                AccountOverviewPage(
                  profile: _me,
                  onLogout: _logout,
                  providerMode: true,
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work_rounded),
            label: 'Servicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Ganancias',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }

  Widget _homeTab() {
    final username = _me?['first_name']?.toString().trim().isNotEmpty == true
        ? _me!['first_name'].toString().trim()
        : _me?['username']?.toString() ?? 'acompañante';
    final finished = _history
        .where((item) => item['status']?.toString().toLowerCase() == 'ended')
        .toList();
    final net = finished.fold<double>(0, (sum, item) {
      final payment = item['payment'] is Map
          ? Map<String, dynamic>.from(item['payment'] as Map)
          : <String, dynamic>{};
      return sum + _money(payment['provider_amount']);
    });

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'Hola, $username',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '¿Listo para acompañar?',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null)
            AppSurfaceCard(
              backgroundColor: AppColors.tint(AppColors.danger, 0.07),
              borderColor: AppColors.tint(AppColors.danger, 0.28),
              child: Text(_error!),
            )
          else if (_activeRequest != null)
            _activeHero(_activeRequest!)
          else
            AppSurfaceCard(
              backgroundColor: AppColors.tint(AppColors.primary, 0.07),
              borderColor: AppColors.tint(AppColors.primary, 0.26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      AppStatusPill(
                        label: 'Disponible',
                        color: AppColors.success,
                        icon: Icons.circle,
                      ),
                      Spacer(),
                      Icon(
                        Icons.toggle_on_rounded,
                        color: AppColors.success,
                        size: 46,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Puedes recibir actividades',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _requests.isEmpty
                        ? 'No hay actividades disponibles en este momento. Actualiza nuevamente en unos minutos.'
                        : 'Hay ${_requests.length} actividades cercanas disponibles.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () => setState(() => _selectedIndex = 1),
                    icon: const Icon(Icons.search_rounded),
                    label: Text(
                      _requests.isEmpty
                          ? 'Ver servicios'
                          : 'Ver ${_requests.length} actividades',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: 'Actividades cercanas',
            actionLabel: 'Ver todas',
            onAction: () => setState(() => _selectedIndex = 1),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_activeRequest != null)
            const AppSurfaceCard(
              child: Text(
                'Finaliza tu actividad actual para recibir nuevas solicitudes.',
              ),
            )
          else if (_requests.isEmpty)
            const AppEmptyState(
              icon: Icons.location_searching_outlined,
              title: 'Sin solicitudes cercanas',
              message:
                  'Cuando aparezca una solicitud pagada y disponible podrás revisarla aquí.',
            )
          else
            ..._requests.take(2).map(_requestCard),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: 'Resumen de hoy'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppMetricCard(
                  label: 'Finalizadas',
                  value: '${finished.length}',
                  icon: Icons.task_alt_outlined,
                  accent: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppMetricCard(
                  label: 'Ganancias',
                  value: formatCop(net),
                  icon: Icons.account_balance_wallet_outlined,
                  accent: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _servicesTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        children: [
          const AppSectionHeader(
            title: 'Solicitudes cercanas',
            subtitle:
                'Revisa la actividad, el punto y la ganancia antes de aceptar.',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_activeRequest != null)
            _activeHero(_activeRequest!)
          else if (_requests.isEmpty)
            const AppEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No hay solicitudes disponibles',
              message:
                  'Desliza hacia abajo para actualizar. Solo aparecen solicitudes con pago protegido.',
            )
          else
            ..._requests.map(_requestCard),
        ],
      ),
    );
  }

  Widget _activeHero(Map<String, dynamic> request) {
    final status = request['status']?.toString().toLowerCase() ?? '';
    final canFinish = _bool(request['can_finish']);
    final providerFinished = request['provider_finished_at'] != null;
    final hasRating = request['my_rating'] is Map;

    return AppSurfaceCard(
      backgroundColor: AppColors.tint(serviceStatusColor(status), 0.08),
      borderColor: AppColors.tint(serviceStatusColor(status), 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppStatusPill(
                label: serviceStatusLabel(status),
                color: serviceStatusColor(status),
                icon: serviceStatusIcon(status),
              ),
              const Spacer(),
              IconButton(
                onPressed: _openActive,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            request['category_name']?.toString() ?? 'Acompañamiento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppInfoRow(
            icon: Icons.person_outline,
            label: 'Solicitante',
            value: request['client_username']?.toString() ?? '—',
          ),
          AppInfoRow(
            icon: Icons.place_outlined,
            label: 'Punto',
            value: request['location_text']?.toString() ?? '—',
          ),
          AppInfoRow(
            icon: Icons.schedule_outlined,
            label: 'Inicio',
            value: formatDateTime(request['requested_start_time']),
          ),
          if (status == 'started' && providerFinished)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: AppStatusPill(
                label: 'Ya finalizaste esta actividad',
                color: AppColors.warning,
                icon: Icons.hourglass_top_rounded,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (canFinish)
            FilledButton.icon(
              onPressed: _actionLoading ? null : () => _finishAndRate(request),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Finalizar y calificar'),
            )
          else if (providerFinished && !hasRating)
            FilledButton.icon(
              onPressed: _actionLoading ? null : () => _rateOnly(request),
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Calificar al solicitante'),
            )
          else
            FilledButton.icon(
              onPressed: _openActive,
              icon: const Icon(Icons.directions_walk_outlined),
              label: const Text('Abrir actividad activa'),
            ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final payment = request['payment'] is Map
        ? Map<String, dynamic>.from(request['payment'] as Map)
        : <String, dynamic>{};
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => ProviderRequestDetailPage(request: request),
            ),
          );
          if (changed == true) {
            await _loadDashboard();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.tint(AppColors.secondary, 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.work_outline,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    request['category_name']?.toString() ?? 'Acompañamiento',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatCop(payment['provider_amount']),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppInfoRow(
              icon: Icons.place_outlined,
              label: 'Punto',
              value: request['location_text']?.toString() ?? 'Sin ubicación',
            ),
            AppInfoRow(
              icon: Icons.schedule_outlined,
              label: 'Inicio',
              value: formatShortDateTime(request['requested_start_time']),
            ),
            AppInfoRow(
              icon: Icons.timer_outlined,
              label: 'Duración',
              value: '${request['requested_duration_minutes'] ?? '—'} minutos',
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const AppStatusPill(
                  label: 'Pago protegido',
                  color: AppColors.primaryMedium,
                  icon: Icons.lock_outline_rounded,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) =>
                            ProviderRequestDetailPage(request: request),
                      ),
                    );
                    if (changed == true) {
                      await _loadDashboard();
                    }
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Ver actividad'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
