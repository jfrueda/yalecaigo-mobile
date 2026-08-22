import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/navigation/role_gate_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_brand.dart';
import '../data/auth_service.dart';
import '../data/social_auth_service.dart';
import 'auth_error.dart';
import 'password_reset_request_page.dart';
import 'role_selection_page.dart';
import 'social_complete_registration_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final AuthService _auth = AuthService();
  final SocialAuthService _social = SocialAuthService();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _pendingProvider;
  String? _pendingProviderToken;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await _run(() async {
      await _auth.login(_identifier.text, _password.text);
      final provider = _pendingProvider;
      final token = _pendingProviderToken;
      if (provider != null && token != null) {
        await _auth.linkSocialIdentity(provider: provider, token: token);
        _pendingProvider = null;
        _pendingProviderToken = null;
      }
    });
  }

  Future<void> _socialLogin(String provider) async {
    if (provider == 'google' && !AppConfig.googleAuthEnabled) {
      _notConfigured('Google');
      return;
    }
    if (provider == 'facebook' && !AppConfig.facebookAuthEnabled) {
      _notConfigured('Facebook');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = provider == 'google'
          ? await _social.signInWithGoogle()
          : await _social.signInWithFacebook();
      final result = await _auth.socialLogin(provider: provider, token: token);
      if (!mounted) return;

      if (result.result == 'authenticated') {
        _openHome();
        return;
      }

      if (result.result == 'registration_required' &&
          result.registrationToken != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SocialCompleteRegistrationPage(
              registrationToken: result.registrationToken!,
              provider: provider == 'google' ? 'Google' : 'Facebook',
              profile: result.profile,
            ),
          ),
        );
        return;
      }

      if (result.result == 'link_required') {
        _pendingProvider = provider;
        _pendingProviderToken = token;
        _identifier.text = result.data['email_hint']?.toString() ?? '';
        setState(() {
          _error =
              'Esta cuenta ya existe. Escribe su contraseña para vincular '
              '${provider == 'google' ? 'Google' : 'Facebook'} de forma segura.';
        });
        return;
      }

      setState(() {
        _error =
            result.data['detail']?.toString() ??
            'No fue posible completar el ingreso social.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = readableAuthError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        _openHome();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = readableAuthError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RoleGatePage()),
      (_) => false,
    );
  }

  void _notConfigured(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$name estará disponible cuando se configuren las credenciales del proyecto.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppBrandHeader(),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Bienvenido',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.tealDark,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Ingresa para continuar con tus actividades.',
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: _identifier,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Correo, celular o usuario',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              autofillHints: const [AutofillHints.password],
                              obscureText: _obscure,
                              onSubmitted: (_) {
                                if (!_loading) {
                                  _login();
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() => _obscure = !_obscure);
                                  },
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const PasswordResetRequestPage(),
                                          ),
                                        );
                                      },
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),
                            ),
                            FilledButton(
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Ingresar'),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text('o continúa con'),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _socialLogin('google'),
                              icon: const Text(
                                'G',
                                style: TextStyle(
                                  color: AppColors.coral,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              label: const Text('Continuar con Google'),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _socialLogin('facebook'),
                              icon: const Icon(Icons.facebook),
                              label: const Text('Continuar con Facebook'),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const RoleSelectionPage(),
                                        ),
                                      );
                                    },
                              child: const Text(
                                '¿No tienes cuenta? Crear cuenta',
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.coral.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.coral,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const OpenticFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
