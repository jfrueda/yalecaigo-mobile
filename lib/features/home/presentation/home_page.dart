import 'package:flutter/material.dart';
import '../../../core/network/token_storage.dart';
import '../../auth/data/me_service.dart';
import '../../auth/presentation/login_page.dart';
import '../../service_request/data/service_request_query_service.dart';
import '../../service_request/presentation/create_request_page.dart';
import '../../service_request/presentation/request_detail_page.dart';
import '../../service_request/presentation/my_requests_page.dart';

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

  bool get isClient => _me?['role'] == 'client';
  bool get isProvider => _me?['role'] == 'provider';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _meService.getMe();
      final active =
      me['role'] == 'client' ? await _queryService.getActiveRequest() : null;

      if (!mounted) return;

      setState(() {
        _me = me;
        _activeRequest = active;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasActive = _activeRequest != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // CLIENTE con solicitud activa
            if (isClient && hasActive) ...[
              const Text(
                'Tienes una solicitud activa',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                    builder: (_) =>
                        RequestDetailPage(request: _activeRequest!),
                  ))
                      .then((_) => _load());
                },
                child: const Text('Ver solicitud activa'),
              ),
            ]

            // CLIENTE sin solicitud
            else if (isClient) ...[
              const Text(
                'No tienes solicitudes activas',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Crear solicitud'),
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                    builder: (_) => const CreateRequestPage(),
                  ))
                      .then((_) => _load());
                },
              ),
            ],

            const SizedBox(height: 24),

            if (isClient)
              OutlinedButton.icon(
                icon: const Icon(Icons.list),
                label: const Text('Mis solicitudes'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const MyRequestsPage()),
                  );
                },
              ),

            if (isProvider)
              const Text(
                'Eres proveedor.\nRevisa las ofertas disponibles.',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

