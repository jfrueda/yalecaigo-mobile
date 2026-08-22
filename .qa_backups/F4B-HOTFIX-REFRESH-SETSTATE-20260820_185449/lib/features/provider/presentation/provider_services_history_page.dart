import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/app_components.dart';
import '../../service_request/data/service_request_query_service.dart';
import 'provider_active_service_page.dart';

class ProviderServicesHistoryPage extends StatefulWidget {
  const ProviderServicesHistoryPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ProviderServicesHistoryPage> createState() =>
      _ProviderServicesHistoryPageState();
}

class _ProviderServicesHistoryPageState
    extends State<ProviderServicesHistoryPage> {
  final ServiceRequestQueryService _service = ServiceRequestQueryService();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _service.listProviderHistory();
  }

  Future<void> _refresh() async {
    setState(() => _future = _service.listProviderHistory());
    await _future;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> items) {
    if (_filter == 'completed') {
      return items.where((item) {
        final status = item['status']?.toString().toLowerCase();
        return status == 'ended' || status == 'completed';
      }).toList();
    }
    if (_filter == 'cancelled') {
      return items.where((item) {
        final status = item['status']?.toString().toLowerCase();
        return status == 'cancelled' || status == 'incident';
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
                  title: 'No pudimos cargar el histórico',
                  message: 'Desliza hacia abajo para intentar nuevamente.',
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
                title: 'Histórico de actividades',
                subtitle:
                    'Consulta los servicios atendidos y su resultado operativo.',
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'Todas', allItems.length),
                    _filterChip(
                      'completed',
                      'Finalizadas',
                      allItems.where((item) {
                        final status = item['status']?.toString().toLowerCase();
                        return status == 'ended' || status == 'completed';
                      }).length,
                    ),
                    _filterChip(
                      'cancelled',
                      'Canceladas o incidentes',
                      allItems.where((item) {
                        final status = item['status']?.toString().toLowerCase();
                        return status == 'cancelled' || status == 'incident';
                      }).length,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (items.isEmpty)
                const AppEmptyState(
                  icon: Icons.history_rounded,
                  title: 'Sin actividades en este filtro',
                  message:
                      'El histórico aparecerá cuando atiendas solicitudes.',
                )
              else
                ...items.map(_historyCard),
            ],
          );
        },
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
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

  Widget _historyCard(Map<String, dynamic> request) {
    final status = request['status']?.toString().toLowerCase() ?? '';
    final payment = request['payment'] is Map
        ? Map<String, dynamic>.from(request['payment'] as Map)
        : <String, dynamic>{};
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppSurfaceCard(
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
                        serviceActivityLabel(request),
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
              label: 'Ubicación',
              value: request['location_text']?.toString() ?? 'Sin ubicación',
            ),
            AppInfoRow(
              icon: Icons.schedule_outlined,
              label: 'Fecha',
              value: formatDateTime(request['requested_start_time']),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatCop(payment['provider_amount']),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppColors.success),
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
