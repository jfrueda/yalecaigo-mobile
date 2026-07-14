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
import '../../safety/presentation/safety_center_page.dart';
import '../../service_request/data/service_lifecycle_service.dart';
import '../../service_request/data/service_request_query_service.dart';
import '../../service_request/presentation/create_request_page.dart';
import '../../service_request/presentation/my_requests_page.dart';
import '../../service_request/presentation/request_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _queryService = ServiceRequestQueryService();
  final _meService = MeService();
  final _lifecycleService = ServiceLifecycleService();

  Map<String, dynamic>? _activeRequest;
  Map<String, dynamic>? _pendingRatingRequest;
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _allRequests = const [];
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _bool(dynamic value) => value == true;

  int? _requestId(Map<String, dynamic> request) {
    final value = request['id'];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double _money(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

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

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final me = await _meService.getMe();
      final requests = await _queryService.listMyRequests();
      Map<String, dynamic>? active;
      Map<String, dynamic>? pendingRating;

      for (final request in requests) {
        final status = request['status']?.toString().toLowerCase();
        if (active == null &&
            const {
              'pending_payment',
              'pending',
              'searching',
              'matched',
              'started',
            }.contains(status)) {
          active = request;
        }
        if (pendingRating == null &&
            status == 'ended' &&
            request['my_rating'] == null) {
          pendingRating = request;
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _me = me;
        _allRequests = requests;
        _activeRequest = active;
        _pendingRatingRequest = pendingRating;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'No se pudo cargar tu información.');
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

  Future<void> _openCreate({int? categoryId}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreateRequestPage(initialCategoryId: categoryId),
      ),
    );
    await _load();
  }

  Future<void> _openActive() async {
    final request = _activeRequest;
    if (request == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RequestDetailPage(request: request),
      ),
    );
    await _load();
  }

  Future<void> _finishAndRate(Map<String, dynamic> request) async {
    final requestId = _requestId(request);
    if (requestId == null) {
      return;
    }

    final rating = await showRequiredServiceRatingDialog(
      context,
      targetLabel: 'el acompañante',
    );
    if (rating == null || !mounted) {
      return;
    }

    setState(() => _actionLoading = true);
    try {
      final updated = await _lifecycleService.finish(requestId);
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

      if (!mounted) {
        return;
      }
      final status = updated['status']?.toString().toLowerCase();
      _showMessage(
        status == 'ended'
            ? 'Actividad finalizada y calificación registrada.'
            : 'Finalización registrada. Falta la confirmación del acompañante.',
      );
      await _load();
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
      targetLabel: 'el acompañante',
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
      await _load();
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
        return 'Actividades';
      case 2:
        return 'Seguridad';
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
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildHomeTab(),
                MyRequestsPage(
                  embedded: true,
                  initialItems: _allRequests,
                  onChanged: _load,
                ),
                SafetyCenterPage(
                  hasActiveService: _activeRequest != null,
                  onOpenActiveService: _activeRequest == null
                      ? null
                      : _openActive,
                ),
                AccountOverviewPage(profile: _me, onLogout: _logout),
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
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Actividades',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Seguridad',
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

  Widget _buildHomeTab() {
    final username = _me?['first_name']?.toString().trim().isNotEmpty == true
        ? _me!['first_name'].toString().trim()
        : _me?['username']?.toString() ?? 'usuario';
    final finished = _allRequests
        .where((item) => item['status']?.toString().toLowerCase() == 'ended')
        .length;
    final total = _allRequests.fold<double>(
      0,
      (sum, item) => sum + _money(item['calculated_price']),
    );
    final recent = _allRequests.take(2).toList();

    return RefreshIndicator(
      onRefresh: _load,
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
            '¿Qué necesitas hacer hoy?',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null)
            AppSurfaceCard(
              backgroundColor: AppColors.tint(AppColors.danger, 0.07),
              borderColor: AppColors.tint(AppColors.danger, 0.26),
              child: Text(_error!),
            )
          else if (_activeRequest != null)
            _activeHero(_activeRequest!)
          else if (_pendingRatingRequest != null)
            _pendingRatingHero(_pendingRatingRequest!)
          else
            AppHeroActionCard(
              title: 'Solicitar acompañamiento',
              subtitle:
                  'Coordina una actividad en pocos pasos y con un punto de encuentro público.',
              buttonLabel: 'Empezar ahora',
              onPressed: _openCreate,
              icon: Icons.arrow_forward_rounded,
            ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: 'Actividades frecuentes',
            subtitle:
                'Toca una opción para empezar con la categoría preseleccionada.',
            actionLabel: 'Ver todas',
            onAction: _openCreate,
          ),
          const SizedBox(height: AppSpacing.md),
          _frequentActivities(),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: 'Tu resumen'),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.84,
            children: [
              AppMetricCard(
                label: 'Realizadas',
                value: '${_allRequests.length}',
                icon: Icons.receipt_long_outlined,
              ),
              AppMetricCard(
                label: 'Finalizadas',
                value: '$finished',
                icon: Icons.task_alt_outlined,
                accent: AppColors.success,
              ),
              AppMetricCard(
                label: 'Valor total',
                value: formatCop(total),
                icon: Icons.payments_outlined,
                accent: AppColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: 'Actividad reciente',
            actionLabel: 'Ver todo',
            onAction: () => setState(() => _selectedIndex = 1),
          ),
          const SizedBox(height: AppSpacing.md),
          if (recent.isEmpty)
            const AppEmptyState(
              icon: Icons.event_note_outlined,
              title: 'Aún no tienes actividades',
              message:
                  'Tu historial aparecerá aquí después de crear la primera solicitud.',
            )
          else
            ...recent.map(_recentCard),
        ],
      ),
    );
  }

  Widget _frequentActivities() {
    const items = [
      (Icons.assignment_outlined, 'Trámites'),
      (Icons.shopping_bag_outlined, 'Compras'),
      (Icons.event_available_outlined, 'Citas'),
      (Icons.directions_walk_outlined, 'Caminar'),
    ];
    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openCreate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.tint(AppColors.secondary, 0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(item.$1, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _activeHero(Map<String, dynamic> request) {
    final status = request['status']?.toString().toLowerCase() ?? '';
    final payment = request['payment'] is Map
        ? Map<String, dynamic>.from(request['payment'] as Map)
        : <String, dynamic>{};
    final canFinish = _bool(request['can_finish']);
    final clientFinished = request['client_finished_at'] != null;
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
                tooltip: 'Abrir actividad',
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
            icon: Icons.place_outlined,
            label: 'Punto de encuentro',
            value: request['location_text']?.toString() ?? 'Sin ubicación',
          ),
          AppInfoRow(
            icon: Icons.schedule_outlined,
            label: 'Inicio',
            value: formatDateTime(request['requested_start_time']),
          ),
          if (request['assigned_provider_username'] != null)
            AppInfoRow(
              icon: Icons.verified_user_outlined,
              label: 'Acompañante',
              value: request['assigned_provider_username'].toString(),
            ),
          AppInfoRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Pago',
            value: paymentStatusLabel(payment['status']),
            valueColor: paymentStatusColor(payment['status']),
          ),
          if (status == 'started' && clientFinished)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: AppStatusPill(
                label: 'Ya finalizaste · esperando al acompañante',
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
          else if (clientFinished && !hasRating)
            FilledButton.icon(
              onPressed: _actionLoading ? null : () => _rateOnly(request),
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Calificar al acompañante'),
            )
          else
            FilledButton.icon(
              onPressed: _openActive,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Ver actividad'),
            ),
        ],
      ),
    );
  }

  Widget _pendingRatingHero(Map<String, dynamic> request) {
    return AppSurfaceCard(
      backgroundColor: AppColors.tint(AppColors.warning, 0.07),
      borderColor: AppColors.tint(AppColors.warning, 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppStatusPill(
            label: 'Falta tu calificación',
            color: AppColors.warning,
            icon: Icons.star_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            request['category_name']?.toString() ?? 'Acompañamiento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(request['location_text']?.toString() ?? 'Sin ubicación'),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _actionLoading ? null : () => _rateOnly(request),
            icon: const Icon(Icons.star_rounded),
            label: const Text('Calificar ahora'),
          ),
        ],
      ),
    );
  }

  Widget _recentCard(Map<String, dynamic> request) {
    final status = request['status']?.toString().toLowerCase() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => RequestDetailPage(request: request),
            ),
          );
          await _load();
        },
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.tint(serviceStatusColor(status), 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                serviceStatusIcon(status),
                color: serviceStatusColor(status),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request['category_name']?.toString() ?? 'Acompañamiento',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${formatShortDateTime(request['requested_start_time'])} · ${serviceStatusLabel(status)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
