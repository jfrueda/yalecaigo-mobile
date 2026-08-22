import 'package:flutter/material.dart';

import '../../../core/navigation/role_gate_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../account/data/account_service.dart';
import '../../account/presentation/emergency_contacts_page.dart';
import '../../account/presentation/identity_verification_page.dart';
import '../../provider/presentation/provider_enablement_page.dart';
import '../data/auth_service.dart';
import 'email_verification_page.dart';
import 'login_page.dart';

class OnboardingStatusPage extends StatefulWidget {
  const OnboardingStatusPage({super.key});

  @override
  State<OnboardingStatusPage> createState() => _OnboardingStatusPageState();
}

class _OnboardingStatusPageState extends State<OnboardingStatusPage> {
  final AuthService _auth = AuthService();
  final AccountService _account = AccountService();

  Map<String, dynamic>? _status;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(Object? value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final value = await _auth.getOnboardingStatus();
      if (!mounted) return;
      setState(() => _status = value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos actualizar tu información.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
    await _load();
  }

  Future<void> _useClientMode() async {
    try {
      await _account.setActiveMode('client');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const RoleGatePage()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir el modo Solicitar.')),
      );
    }
  }

  Future<void> _useProviderMode() async {
    try {
      final modes = await _account.setActiveMode('provider');
      if (!mounted) return;
      final canProvide = modes['can_provide'] == true;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => canProvide
              ? const RoleGatePage()
              : const ProviderEnablementPage(),
        ),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir el modo Acompañar.')),
      );
    }
  }

  String _providerMessage(Map<String, dynamic> provider) {
    final status = provider['status']?.toString().toUpperCase();
    final reason = provider['review_reason']?.toString().trim() ?? '';
    final rawMissing = provider['missing_field_labels'];
    final missing = rawMissing is List
        ? rawMissing
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];

    if (status == 'REQUIRES_UPDATE' && reason.isNotEmpty) {
      return 'Debes actualizar: $reason';
    }
    if (missing.isNotEmpty && !{'IN_REVIEW', 'ACTIVE'}.contains(status)) {
      return 'Falta completar: ${missing.join(', ')}.';
    }
    return switch (status) {
      'ACTIVE' => 'Ya puedes acompañar personas.',
      'IN_REVIEW' => 'Recibimos tu información y la estamos revisando.',
      'REQUIRES_UPDATE' =>
        'Necesitamos que actualices la información indicada.',
      'SUSPENDED' =>
        'Tu opción para acompañar no está disponible en este momento.',
      _ => 'Puedes completar tu perfil cuando quieras empezar a acompañar.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _status ?? const <String, dynamic>{};
    final account = _map(status['account']);
    final safety = _map(status['safety']);
    final provider = _map(status['provider']);
    final modes = _map(status['modes']);
    final displayName = account['display_name']?.toString().trim() ?? '';
    final emailVerified = status['email_verified'] == true;
    final accountReady = status['account_ready'] == true;
    final providerEnabled = provider['enabled'] == true;
    final canProvide = modes['can_provide'] == true;
    final rawActivationMissing = status['activation_missing_labels'];
    final activationMissing = rawActivationMissing is List
        ? rawActivationMissing
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Mi cuenta'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading && _status == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    displayName.isEmpty
                        ? 'Tu cuenta GoWith'
                        : 'Hola, $displayName',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    accountReady
                        ? 'Tu cuenta está lista. Elige cómo quieres usar GoWith.'
                        : 'Completa lo necesario para empezar a usar GoWith.',
                  ),
                  const SizedBox(height: 20),
                  if (!accountReady && activationMissing.isNotEmpty) ...[
                    _SimpleCard(
                      icon: Icons.fact_check_outlined,
                      title: 'Falta por completar',
                      subtitle: activationMissing.join(' · '),
                      color: AppColors.amber,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) ...[
                    _SimpleCard(
                      icon: Icons.error_outline_rounded,
                      title: _error!,
                      color: AppColors.coral,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SimpleCard(
                    icon: emailVerified
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                    title: emailVerified
                        ? 'Correo confirmado'
                        : 'Confirma tu correo',
                    subtitle: emailVerified
                        ? account['email']?.toString()
                        : 'Usa el código que enviamos a tu correo.',
                    color: emailVerified ? AppColors.teal : AppColors.amber,
                    onTap: emailVerified
                        ? null
                        : () => _open(const EmailVerificationPage()),
                  ),
                  const SizedBox(height: 12),
                  _SimpleCard(
                    icon: Icons.phone_android_outlined,
                    title: 'Celular',
                    subtitle:
                        account['security_phone_masked']
                                ?.toString()
                                .isNotEmpty ==
                            true
                        ? account['security_phone_masked'].toString()
                        : 'Agrega tu número personal.',
                    color: AppColors.teal,
                  ),
                  const SizedBox(height: 12),
                  _SimpleCard(
                    icon: Icons.contact_emergency_outlined,
                    title: 'Persona de confianza',
                    subtitle: safety['trusted_contact_registered'] == true
                        ? 'Registrada'
                        : 'Puedes agregarla para tus opciones de seguridad.',
                    color: AppColors.teal,
                    onTap: () => _open(const EmergencyContactsPage()),
                  ),
                  if (providerEnabled || canProvide) ...[
                    const SizedBox(height: 12),
                    _SimpleCard(
                      icon: Icons.volunteer_activism_outlined,
                      title: 'Acompañar',
                      subtitle: _providerMessage(provider),
                      color: canProvide ? AppColors.teal : AppColors.amber,
                      onTap: canProvide
                          ? _useProviderMode
                          : () => _open(const ProviderEnablementPage()),
                    ),
                  ],
                  if (safety['identity_submitted'] == true) ...[
                    const SizedBox(height: 12),
                    _SimpleCard(
                      icon: Icons.verified_user_outlined,
                      title: safety['identity_verified'] == true
                          ? 'Identidad confirmada'
                          : 'Identidad enviada',
                      subtitle: safety['identity_verified'] == true
                          ? 'Listo'
                          : 'Te avisaremos cuando termine la revisión.',
                      color: safety['identity_verified'] == true
                          ? AppColors.teal
                          : AppColors.amber,
                      onTap: () => _open(const IdentityVerificationPage()),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (accountReady) ...[
                    FilledButton.icon(
                      onPressed: _useClientMode,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Solicitar acompañamiento'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _useProviderMode,
                      icon: const Icon(Icons.volunteer_activism_outlined),
                      label: Text(
                        canProvide ? 'Acompañar' : 'También quiero acompañar',
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({
    required this.icon,
    required this.title,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
