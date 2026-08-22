import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'auth_error.dart';
import '../../onboarding/presentation/registration_welcome_page.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, this.initialChallengeId});
  final String? initialChallengeId;
  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _code = TextEditingController();
  final _auth = AuthService();
  String? _challengeId;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _challengeId = widget.initialChallengeId;
    if (_challengeId == null) _request();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await _auth.requestEmailOtp();
      if (mounted) setState(() => _challengeId = id);
    } catch (error) {
      if (mounted) setState(() => _error = readableAuthError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_challengeId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.verifyEmailOtp(challengeId: _challengeId!, code: _code.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const RegistrationWelcomePage(),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = readableAuthError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verificar correo')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Escribe el código de seis dígitos enviado a tu correo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    border: OutlineInputBorder(),
                  ),
                ),
                FilledButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Verificar correo'),
                ),
                TextButton(
                  onPressed: _loading ? null : _request,
                  child: const Text('Reenviar código'),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
