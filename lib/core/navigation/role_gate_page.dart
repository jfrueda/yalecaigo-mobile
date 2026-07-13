import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/service_request/presentation/create_request_page.dart';
import '../../features/provider/presentation/provider_home_page.dart';
import '../network/api_client.dart';
import '../network/token_storage.dart';

class RoleGatePage extends StatefulWidget {
  const RoleGatePage({super.key});

  @override
  State<RoleGatePage> createState() => _RoleGatePageState();
}

class _RoleGatePageState extends State<RoleGatePage> {
  bool _loading = true;
  String? _error;

  String? _username;
  String? _role;
  bool _verified = false;

  String _endpointUsed = '';
  int? _httpStatus;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
      _endpointUsed = '';
      _httpStatus = null;
    });

    try {
      // 1) Preferimos /security/me/
      Response res;
      try {
        _endpointUsed = '/security/me/';
        res = await ApiClient.dio.get(_endpointUsed);
      } on DioException catch (e) {
        // 2) Fallback /auth/me/ (por si existe en tu backend)
        if (e.response?.statusCode == 404) {
          _endpointUsed = '/auth/me/';
          res = await ApiClient.dio.get(_endpointUsed);
        } else {
          rethrow;
        }
      }

      _httpStatus = res.statusCode;
      final data = Map<String, dynamic>.from(res.data);

      setState(() {
        _username = data['username']?.toString();
        _role = data['role']?.toString();
        _verified = data['is_verified'] == true;
        _loading = false;
      });
    } catch (e) {
      // NO limpiamos tokens a ciegas si quieres diagnosticar.
      // Pero si prefieres forzar logout, descomenta el clear().
      // await TokenStorage.clear();

      String msg = 'No se pudo obtener el perfil';
      if (e is DioException) {
        msg = 'No se pudo obtener el perfil ($_endpointUsed) '
            'HTTP=${e.response?.statusCode} data=${e.response?.data}';
      }

      setState(() {
        _error = msg;
        _loading = false;
      });
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

    final debugInfo = '''
Endpoint: $_endpointUsed
HTTP: ${_httpStatus ?? '-'}
Usuario: ${_username ?? '—'}
Rol: ${_role ?? '—'}
Verificado: $_verified
Pantalla destino: ${_targetPageName()}
''';

    if (_error != null) {
      return _debugScaffold(
        title: 'ERROR',
        actions: [
          IconButton(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            Text(debugInfo),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _logout,
              child: const Text('Volver a login'),
            ),
          ],
        ),
      );
    }

    if (!_verified) {
      return _debugScaffold(
        title: 'CUENTA NO VERIFICADA',
        actions: [
          IconButton(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
        child: Text(debugInfo),
      );
    }

    switch ((_role ?? '').toLowerCase()) {
      case 'client':
        return _debugScaffold(
          title: 'CLIENTE',
          actions: [
            IconButton(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(debugInfo),
              const Divider(),
              // OJO: esto anida un Scaffold si CreateRequestPage ya es Scaffold.
              // Para MVP lo dejamos, pero si ves glitches visuales,
              // el siguiente paso es convertir CreateRequestPage a "form widget".
              const SizedBox(
                height: 800, // evita Expanded dentro de scroll
                child: CreateRequestPage(),
              ),
            ],
          ),
        );

      case 'provider':
        return _debugScaffold(
          title: 'PROVEEDOR',
          actions: [
            IconButton(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(debugInfo),
              const Divider(),
              const SizedBox(
                height: 800,
                child: ProviderHomePage(),
              ),
            ],
          ),
        );

      case 'admin':
        return _debugScaffold(
          title: 'ADMIN',
          actions: [
            IconButton(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
          child: Text(debugInfo),
        );

      default:
        return _debugScaffold(
          title: 'ROL DESCONOCIDO',
          actions: [
            IconButton(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
          child: Text(debugInfo),
        );
    }
  }

  String _targetPageName() {
    if (!_verified) return 'NotVerified';
    switch ((_role ?? '').toLowerCase()) {
      case 'client':
        return 'CreateRequestPage';
      case 'provider':
        return 'ProviderHomePage';
      case 'admin':
        return 'AdminPlaceholder';
      default:
        return 'UnknownRole';
    }
  }

  Widget _debugScaffold({
    required String title,
    required Widget child,
    List<Widget>? actions,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DEBUG ROL – $title'),
        backgroundColor: Colors.deepPurple,
        actions: actions,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}
