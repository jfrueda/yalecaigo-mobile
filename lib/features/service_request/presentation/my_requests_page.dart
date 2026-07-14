import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/app_components.dart';
import '../data/service_request_query_service.dart';
import 'request_detail_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({
    super.key,
    this.embedded = false,
    this.initialItems,
    this.onChanged,
  });

  final bool embedded;
  final List<Map<String, dynamic>>? initialItems;
  final Future<void> Function()? onChanged;

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final _service = ServiceRequestQueryService();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';

  static const _activeStatuses = {
    'pending_payment',
    'pending',
    'searching',
    'matched',
    'started',
  };

  @override
  void initState() {
    super.initState();
    _future = widget.initialItems == null
        ? _service.listMyRequests()
        : Future.value(widget.initialItems);
  }

  @override
  void didUpdateWidget(covariant MyRequestsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItems != oldWidget.initialItems &&
        widget.initialItems != null) {
      _future = Future.value(widget.initialItems);
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _service.listMyRequests());
    await _future;
    await widget.onChanged?.call();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> items) {
    switch (_filter) {
      case 'active':
        return items
            .where(
              (item) => _activeStatuses.contains(
                item['status']?.toString().toLowerCase(),
              ),
            )
            .toList();
      case 'ended':
        return items
            .where(
              (item) => item['status']?.toString().toLowerCase() == 'ended',
            )
            .toList();
      case 'cancelled':
        return items
            .where(
              (item) => item['status']?.toString().toLowerCase() == 'cancelled',
            )
            .toList();
      default:
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'No pudimos cargar tus actividades',
                  message:
                      'Revisa la conexión y desliza hacia abajo para intentar nuevamente.',
                ),
              ],
            );
          }

          final allItems = snapshot.data ?? const [];
          final items = _filtered(allItems);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            children: [
              const AppSectionHeader(
                title: 'Tus actividades',
                subtitle:
                    'Consulta el estado, el valor y el detalle de cada solicitud.',
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'Todas', allItems.length),
                    _filterChip(
                      'active',
                      'Activas',
                      allItems
                          .where(
                            (item) => _activeStatuses.contains(
                              item['status']?.toString().toLowerCase(),
                            ),
                          )
                          .length,
                    ),
                    _filterChip(
                      'ended',
                      'Finalizadas',
                      allItems
                          .where(
                            (item) =>
                                item['status']?.toString().toLowerCase() ==
                                'ended',
                          )
                          .length,
                    ),
                    _filterChip(
                      'cancelled',
                      'Canceladas',
                      allItems
                          .where(
                            (item) =>
                                item['status']?.toString().toLowerCase() ==
                                'cancelled',
                          )
                          .length,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (items.isEmpty)
                const AppEmptyState(
                  icon: Icons.event_note_outlined,
                  title: 'No hay actividades en este filtro',
                  message:
                      'Cambia el filtro o crea una nueva solicitud desde Inicio.',
                )
              else
                ...items.map(_requestCard),
            ],
          );
        },
      ),
    );

    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividades'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _filterChip(String value, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: AppChoiceChip(
        label: '$label · $count',
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final status = request['status']?.toString().toLowerCase() ?? '';
    final payment = request['payment'] is Map
        ? Map<String, dynamic>.from(request['payment'] as Map)
        : <String, dynamic>{};

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => RequestDetailPage(request: request),
            ),
          );
          await _refresh();
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
                        request['category_name']?.toString() ??
                            'Acompañamiento',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppStatusPill(
                        label: serviceStatusLabel(status),
                        color: serviceStatusColor(status),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
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
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valor',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        formatCop(request['calculated_price']),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                AppStatusPill(
                  label: paymentStatusLabel(payment['status']),
                  color: paymentStatusColor(payment['status']),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
