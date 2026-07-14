import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/brand_logo.dart';

import '../data/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _auth = AuthService();
  final _identifierCtrl = TextEditingController();
  final _uidCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _codeRequested = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _uidCtrl.dispose();
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_identifierCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa tu usuario o correo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      final result = await _auth.requestPasswordReset(_identifierCtrl.text);
      if (!mounted) return;
      _uidCtrl.text = result['demo_uid']?.toString() ?? '';
      _tokenCtrl.text = result['demo_token']?.toString() ?? '';
      setState(() {
        _codeRequested = true;
        _message =
            result['demo_message']?.toString() ??
            result['detail']?.toString() ??
            'Revisa tu correo para continuar.';
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.response?.data?.toString() ?? error.message,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_uidCtrl.text.trim().isEmpty || _tokenCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el UID y el token de recuperación.');
      return;
    }
    if (_passwordCtrl.text.length < 8) {
      setState(
        () => _error = 'La contraseña debe tener al menos 8 caracteres.',
      );
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.confirmPasswordReset(
        uid: _uidCtrl.text,
        token: _tokenCtrl.text,
        newPassword: _passwordCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
        ),
      );
      Navigator.of(context).pop();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.response?.data?.toString() ?? error.message,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(title: 'Recuperar contraseña'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Recupera el acceso a tu cuenta',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _identifierCtrl,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Usuario o correo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _requestCode,
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Text('Solicitar recuperación'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_message!),
              ),
            ),
          ],
          if (_codeRequested) ...[
            const SizedBox(height: 18),
            TextField(
              controller: _uidCtrl,
              decoration: const InputDecoration(
                labelText: 'UID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar nueva contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _confirmReset,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Cambiar contraseña'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 28),
          const OpenticAttribution(imageWidth: 102, compact: true),
        ],
      ),
    );
  }
}
