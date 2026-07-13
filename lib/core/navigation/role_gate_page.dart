import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/auth/data/me_service.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/provider/presentation/available_requests_page.dart';
import '../config/app_config.dart';
import '../network/token_storage.dart';

class RoleGatePage extends StatefulWidget {
  const RoleGatePage({super.key});

  @override
  State<RoleGatePage> createState() => _RoleGatePageState();
}

class _RoleGatePageState extends State<RoleGatePage> {
  final _meService = MeService();

  bool _loading = true;
  String? _error;
  String? _role;
  String? _status;
  String? _username;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final profile = await _meService.getMe();
      if (!mounted) return;

      final status = profile['status']?.toString().toUpperCase();
      setState(() {
        _username = profile['username']?.toString();
        _role = profile['role']?.toString().toLowerCase();
        _status = status;
        _verified = profile['is_verified'] == true || status == 'VERIFIED';
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final statusCode = error.response?.statusCode;
      setState(() {
        _error = statusCode == 401
            ? 'La sesión venció o el token no es válido.'
            : 'No se pudo consultar el perfil en el backend.';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'La respuesta del perfil no tiene el formato esperado.';
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

  String get _debugDetail =>
      'API: ${AppConfig.normalizedBaseUrl}\n'
      'Usuario: ${_username ?? '-'}\n'
      'Rol: ${_role ?? '-'}\n'
      'Estado: ${_status ?? '-'}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _MessagePage(
        title: 'No fue posible iniciar',
        message: _error!,
        detail: kDebugMode ? _debugDetail : null,
        primaryLabel: 'Reintentar',
        onPrimary: _loadProfile,
        onLogout: _logout,
      );
    }

    if (_status == 'SUSPENDED') {
      return _MessagePage(
        title: 'Cuenta suspendida',
        message:
            'La cuenta está suspendida. Debe ser reactivada desde el backend.',
        detail: kDebugMode ? _debugDetail : null,
        primaryLabel: 'Volver a consultar',
        onPrimary: _loadProfile,
        onLogout: _logout,
      );
    }

    // Los clientes pueden crear solicitudes mientras su verificación documental
    // se completa. Los prestadores sí deben estar verificados antes de aceptar.
    if (_role == 'provider' && !_verified) {
      return _MessagePage(
        title: 'Prestador pendiente de verificación',
        message:
            'El backend reconoció la cuenta de prestador, pero todavía no está '
            'habilitada para aceptar servicios.',
        detail: kDebugMode ? _debugDetail : null,
        primaryLabel: 'Volver a consultar',
        onPrimary: _loadProfile,
        onLogout: _logout,
      );
    }

    switch (_role) {
      case 'client':
        return const HomePage();
      case 'provider':
        return const AvailableRequestsPage();
      case 'admin':
        return _MessagePage(
          title: 'Administrador',
          message: 'El panel administrativo móvil aún no está implementado.',
          detail: kDebugMode ? _debugDetail : null,
          primaryLabel: 'Actualizar perfil',
          onPrimary: _loadProfile,
          onLogout: _logout,
        );
      default:
        return _MessagePage(
          title: 'Rol no reconocido',
          message: 'El backend devolvió el rol "${_role ?? 'vacío'}".',
          detail: kDebugMode ? _debugDetail : null,
          primaryLabel: 'Reintentar',
          onPrimary: _loadProfile,
          onLogout: _logout,
        );
    }
  }
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onLogout,
    this.detail,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final String? detail;
  final VoidCallback onPrimary;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                if (detail != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    detail!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
