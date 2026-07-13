import 'package:flutter/material.dart';

import '../../../core/network/token_storage.dart';
import '../../auth/data/me_service.dart';
import '../../auth/presentation/login_page.dart';
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

  Map<String, dynamic>? _activeRequest;
  Map<String, dynamic>? _me;
  bool _loading = true;
  String? _error;

  String get _role => _me?['role']?.toString().toLowerCase() ?? '';
  bool get isClient => _role == 'client';

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
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la información del usuario.';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!isClient) {
      return const Center(
        child: Text('Este inicio está configurado para el rol client.'),
      );
    }

    final hasActive = _activeRequest != null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasActive) ...[
                const Text(
                  'Tienes una solicitud activa',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                RequestDetailPage(request: _activeRequest!),
                          ),
                        )
                        .then((_) => _load());
                  },
                  child: const Text('Ver solicitud activa'),
                ),
              ] else ...[
                const Text(
                  'No tienes solicitudes activas',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Crear solicitud'),
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CreateRequestPage(),
                          ),
                        )
                        .then((_) => _load());
                  },
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.list),
                label: const Text('Mis solicitudes'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyRequestsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
