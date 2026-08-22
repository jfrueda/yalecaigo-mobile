import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/app_components.dart';
import '../data/account_service.dart';

class SessionManagementPage extends StatefulWidget {
  const SessionManagementPage({super.key});

  @override
  State<SessionManagementPage> createState() => _SessionManagementPageState();
}

class _SessionManagementPageState extends State<SessionManagementPage> {
  final AccountService _service = AccountService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _service.listSessions();
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible consultar las sesiones.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(Map<String, dynamic> session) async {
    final id = session['id']?.toString();
    if (id == null || id.isEmpty || session['is_current'] == true) return;
    try {
      await _service.revokeSession(id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('La sesión fue cerrada.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: 'No fue posible cerrar la sesión.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _logoutOthers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar otros dispositivos'),
        content: const Text(
          'Se cerrarán todas las sesiones excepto la que estás usando ahora.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesiones'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.logoutOthers();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las otras sesiones fueron cerradas.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: 'No fue posible cerrar las otras sesiones.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Dispositivos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  const AppSectionHeader(
                    title: 'Sesiones activas',
                    subtitle:
                        'Revisa en qué dispositivos está abierta tu cuenta.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null)
                    AppSurfaceCard(
                      backgroundColor: AppColors.coralSoft,
                      borderColor: AppColors.tint(AppColors.danger, 0.28),
                      child: Text(_error!),
                    )
                  else if (_sessions.isEmpty)
                    const AppEmptyState(
                      icon: Icons.devices_other_outlined,
                      title: 'No hay sesiones visibles',
                      message:
                          'La sesión actual aparecerá después del siguiente inicio de sesión.',
                    )
                  else
                    ..._sessions.map((session) {
                      final current = session['is_current'] == true;
                      final active = session['is_active'] == true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppColors.tint(
                                        current
                                            ? AppColors.success
                                            : AppColors.primary,
                                        0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.smartphone_outlined,
                                      color: current
                                          ? AppColors.success
                                          : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session['device_name']?.toString() ??
                                              'Dispositivo',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${session['platform'] ?? '-'} · '
                                          '${session['app_version'] ?? '-'}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppStatusPill(
                                    label: current
                                        ? 'Actual'
                                        : active
                                        ? 'Activa'
                                        : 'Cerrada',
                                    color: current
                                        ? AppColors.success
                                        : active
                                        ? AppColors.information
                                        : AppColors.textSecondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppInfoRow(
                                icon: Icons.schedule_outlined,
                                label: 'Última actividad',
                                value: formatDateTime(session['last_seen_at']),
                              ),
                              AppInfoRow(
                                icon: Icons.public_outlined,
                                label: 'Dirección IP',
                                value: session['last_ip']?.toString() ?? '-',
                              ),
                              if (!current && active) ...[
                                const Divider(),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _revoke(session),
                                    icon: const Icon(Icons.logout),
                                    label: const Text('Cerrar sesión'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed:
                        _sessions.any(
                          (item) =>
                              item['is_active'] == true &&
                              item['is_current'] != true,
                        )
                        ? _logoutOthers
                        : null,
                    icon: const Icon(Icons.phonelink_erase_outlined),
                    label: const Text('Cerrar otros dispositivos'),
                  ),
                ],
              ),
            ),
    );
  }
}
