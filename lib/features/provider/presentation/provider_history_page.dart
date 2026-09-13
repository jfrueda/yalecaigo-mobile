import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/app_components.dart';
import '../../service_request/data/service_request_query_service.dart';
import 'provider_active_service_page.dart';
import 'provider_payout_destinations_page.dart';

class ProviderHistoryPage extends StatefulWidget {
  const ProviderHistoryPage({
    super.key,
    this.embedded = false,
    this.initialItems,
    this.onChanged,
  });

  final bool embedded;
  final List<Map<String, dynamic>>? initialItems;
  final Future<void> Function()? onChanged;

  @override
  State<ProviderHistoryPage> createState() => _ProviderHistoryPageState();
}

class _ProviderHistoryPageState extends State<ProviderHistoryPage> {
  final _queryService = ServiceRequestQueryService();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = widget.initialItems == null
        ? _queryService.listProviderHistory()
        : Future.value(widget.initialItems);
  }

  @override
  void didUpdateWidget(covariant ProviderHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItems != oldWidget.initialItems &&
        widget.initialItems != null) {
      _future = Future.value(widget.initialItems);
    }
  }

  Future<void> _refresh() async {
    final nextFuture = _queryService.listProviderHistory();
    if (!mounted) return;

    setState(() {
      _future = nextFuture;
    });

    await nextFuture;
    if (!mounted) return;
    await widget.onChanged?.call();
  }

  double _money(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> items) {
    if (_filter == 'pending') {
      return items.where((item) {
        final payment = item['payment'] is Map
            ? Map<String, dynamic>.from(item['payment'] as Map)
            : <String, dynamic>{};
        return payment['status']?.toString().toLowerCase() == 'release_pending';
      }).toList();
    }
    if (_filter == 'paid') {
      return items.where((item) {
        final payment = item['payment'] is Map
            ? Map<String, dynamic>.from(item['payment'] as Map)
            : <String, dynamic>{};
        return payment['status']?.toString().toLowerCase() ==
            'paid_to_provider';
      }).toList();
    }
    return items;
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
                  title: 'No pudimos cargar tus ganancias',
                  message: 'Desliza hacia abajo para intentar nuevamente.',
                ),
              ],
            );
          }

          final allItems = snapshot.data ?? const [];
          final items = _filtered(allItems);
          final transferred = allItems.where((item) {
            final payment = item['payment'] is Map
                ? Map<String, dynamic>.from(item['payment'] as Map)
                : <String, dynamic>{};
            return payment['status']?.toString().toLowerCase() ==
                'paid_to_provider';
          }).toList();
          final pending = allItems.where((item) {
            final payment = item['payment'] is Map
                ? Map<String, dynamic>.from(item['payment'] as Map)
                : <String, dynamic>{};
            return payment['status']?.toString().toLowerCase() ==
                'release_pending';
          }).toList();
          final transferredValue = transferred.fold<double>(0, (sum, item) {
            final payment = item['payment'] is Map
                ? Map<String, dynamic>.from(item['payment'] as Map)
                : <String, dynamic>{};
            return sum + _money(payment['provider_amount']);
          });
          final pendingValue = pending.fold<double>(0, (sum, item) {
            final payment = item['payment'] is Map
                ? Map<String, dynamic>.from(item['payment'] as Map)
                : <String, dynamic>{};
            return sum + _money(payment['provider_amount']);
          });

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
                title: 'Estado de cuenta',
                subtitle: 'Consulta tus valores pendientes y transferidos.',
              ),
              const SizedBox(height: AppSpacing.lg),
              const ProviderPayoutDestinationSummaryCard(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppMetricCard(
                      label: 'Disponible',
                      value: formatCop(transferredValue),
                      caption: '${transferred.length} transferencias',
                      icon: Icons.account_balance_wallet_outlined,
                      accent: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppMetricCard(
                      label: 'Pendiente',
                      value: formatCop(pendingValue),
                      caption: '${pending.length} actividades',
                      icon: Icons.schedule_send_outlined,
                      accent: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppSurfaceCard(
                backgroundColor: AppColors.tint(AppColors.primary, 0.06),
                borderColor: AppColors.tint(AppColors.primary, 0.22),
                child: AppInfoRow(
                  icon: Icons.paid_outlined,
                  label: 'Transferido en el período',
                  value: formatCop(transferredValue),
                  valueColor: AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'Todos'),
                    _filterChip('pending', 'Pendientes'),
                    _filterChip('paid', 'Transferidos'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (items.isEmpty)
                const AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Sin movimientos en este filtro',
                  message:
                      'Los valores aparecerán cuando finalices actividades.',
                )
              else
                ...items.map(_movementCard),
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
        title: const Text('Ganancias'),
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

  Widget _filterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: AppChoiceChip(
        label: label,
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _movementCard(Map<String, dynamic> request) {
    final payment = request['payment'] is Map
        ? Map<String, dynamic>.from(request['payment'] as Map)
        : <String, dynamic>{};
    final paid =
        payment['status']?.toString().toLowerCase() == 'paid_to_provider';
    final statusColor = paymentStatusColor(payment['status']);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ProviderActiveServicePage(serviceRequest: request),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.tint(statusColor, 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    paid
                        ? Icons.check_circle_outline
                        : Icons.schedule_send_outlined,
                    color: statusColor,
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
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        formatShortDateTime(request['requested_start_time']),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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
            Row(
              children: [
                AppStatusPill(
                  label: paymentStatusLabel(payment['status']),
                  color: statusColor,
                  icon: paid
                      ? Icons.verified_outlined
                      : Icons.schedule_outlined,
                ),
                const Spacer(),
                Text(
                  'Ref. ${payment['external_reference'] ?? 'GWT-DEMO'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
