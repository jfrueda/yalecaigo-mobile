import 'package:flutter/material.dart';

import '../../../core/navigation/role_gate_page.dart';
import '../../account/data/account_service.dart';
import '../../provider/presentation/provider_enablement_page.dart';

class RegistrationWelcomePage extends StatefulWidget {
  const RegistrationWelcomePage({super.key});

  @override
  State<RegistrationWelcomePage> createState() =>
      _RegistrationWelcomePageState();
}

class _RegistrationWelcomePageState extends State<RegistrationWelcomePage> {
  final AccountService _account = AccountService();
  bool _loading = false;
  String? _error;

  Future<void> _goClient() async {
    await _selectMode('client');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RoleGatePage()),
      (_) => false,
    );
  }

  Future<void> _goProvider() async {
    await _selectMode('provider');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ProviderEnablementPage()),
      (_) => false,
    );
  }

  Future<void> _selectMode(String mode) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _account.setActiveMode(mode);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'No pudimos continuar. Intenta nuevamente.');
      rethrow;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cuenta lista')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 84,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  'Tu cuenta está lista',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Puedes empezar solicitando acompañamientos. Si también quieres acompañar personas, completa una sola vez tu información de seguridad y perfil.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _loading ? null : _goClient,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Solicitar acompañamiento'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _goProvider,
                  icon: const Icon(Icons.volunteer_activism_rounded),
                  label: const Text('También quiero acompañar'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
