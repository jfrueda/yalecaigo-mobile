import 'package:flutter/material.dart';

import '../../../core/branding/app_branding.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/app_components.dart';
import '../../auth/data/me_service.dart';
import '../../service_request/data/service_request_query_service.dart';
import '../../service_request/presentation/create_request_page.dart';
import '../../service_request/presentation/my_requests_page.dart';
import '../../service_request/presentation/request_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.embedded = false, this.onOpenRequests});

  final bool embedded;
  final VoidCallback? onOpenRequests;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ServiceRequestQueryService _queryService = ServiceRequestQueryService();
  final MeService _meService = MeService();

  Map<String, dynamic>? _activeRequest;
  Map<String, dynamic>? _me;
  bool _loading = true;
  String? _error;

  String get _role => _me?['role']?.toString().toLowerCase() ?? '';
  bool get isClient => _role == 'client';

  Map<String, dynamic> get _profile {
    final value = _me?['profile'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  @override
  void initState() {
    super.initState();
    _load();
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
      final role = me['role']?.toString().toLowerCase();
      final active = role == 'client'
          ? await _queryService.getActiveRequest()
          : null;
      if (!mounted) return;
      setState(() {
        _me = me;
        _activeRequest = active;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la información del usuario.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openActive() async {
    if (_activeRequest == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RequestDetailPage(request: _activeRequest!),
      ),
    );
    await _load();
  }

  Future<void> _createRequest() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CreateRequestPage()),
    );
    await _load();
  }

  void _openRequests() {
    final callback = widget.onOpenRequests;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MyRequestsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
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
                if (_error != null) ...[
                  AppSurfaceCard(
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 42),
                        const SizedBox(height: AppSpacing.md),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ] else if (!isClient) ...[
                  const AppEmptyState(
                    icon: Icons.person_outline,
                    title: 'Perfil no disponible',
                    message: 'Este inicio está reservado para solicitantes.',
                  ),
                ] else ...[
                  AppBrandInlineBanner(
                    title:
                        'Hola, ${_profile['first_name'] ?? _me?['username'] ?? 'bienvenido'}',
                    subtitle:
                        'Organiza tus acompañamientos desde ${AppBranding.appName}.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_activeRequest != null)
                    AppHeroActionCard(
                      title: 'Tienes una actividad activa',
                      subtitle:
                          'Consulta el estado, el acompañante asignado y las opciones de seguridad.',
                      buttonLabel: 'Abrir actividad',
                      icon: Icons.open_in_new_rounded,
                      onPressed: _openActive,
                    )
                  else
                    AppHeroActionCard(
                      title: '¿Qué quieres hacer hoy?',
                      subtitle:
                          'Crea una solicitud y encuentra un acompañante compatible con la actividad.',
                      buttonLabel: 'Crear solicitud',
                      icon: Icons.add_circle_outline,
                      onPressed: _createRequest,
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppSurfaceCard(
                          onTap: _openRequests,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.event_note_outlined,
                                color: AppColors.primary,
                                size: 30,
                              ),
                              SizedBox(height: AppSpacing.md),
                              Text(
                                'Mis actividades',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 4),
                              Text('Historial y solicitudes en curso.'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppSurfaceCard(
                          onTap: _load,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                color: AppColors.coral,
                                size: 30,
                              ),
                              SizedBox(height: AppSpacing.md),
                              Text(
                                'Actualizar',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 4),
                              Text('Consulta cambios recientes.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Inicio'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }
}
