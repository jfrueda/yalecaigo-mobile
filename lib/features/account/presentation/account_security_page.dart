import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/app_components.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/social_auth_service.dart';
import 'change_password_page.dart';
import '../data/account_service.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key, required this.onOpenSessions});

  final VoidCallback onOpenSessions;

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final _accountService = AccountService();
  final _authService = AuthService();
  final _socialAuth = SocialAuthService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _identities = const [];
  Map<String, dynamic> _security = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _accountService.getSocialAccounts();
      final results = response['results'];
      final security = response['security'];
      if (!mounted) return;
      setState(() {
        _identities = results is List
            ? results
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : const [];
        _security = security is Map
            ? Map<String, dynamic>.from(security)
            : const {};
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible consultar la seguridad de la cuenta.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _identity(String provider) {
    for (final item in _identities) {
      if (item['provider']?.toString().toLowerCase() == provider) return item;
    }
    return null;
  }

  Future<void> _link(String provider) async {
    try {
      final token = provider == 'google'
          ? await _socialAuth.signInWithGoogle()
          : await _socialAuth.signInWithFacebook();
      await _authService.linkSocialIdentity(provider: provider, token: token);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_providerLabel(provider)} fue vinculado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: 'No fue posible vincular ${_providerLabel(provider)}.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _unlink(String provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Desvincular ${_providerLabel(provider)}'),
        content: const Text(
          'Podrás seguir ingresando con tu contraseña u otro método vinculado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _accountService.unlinkSocialAccount(provider);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_providerLabel(provider)} fue desvinculado.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback:
                  'No fue posible desvincular ${_providerLabel(provider)}.',
            ),
          ),
        ),
      );
    }
  }

  String _providerLabel(String provider) =>
      provider == 'google' ? 'Google' : 'Facebook';

  bool _providerEnabled(String provider) => provider == 'google'
      ? AppConfig.googleAuthEnabled
      : AppConfig.facebookAuthEnabled;

  Widget _providerCard(String provider, IconData icon) {
    final identity = _identity(provider);
    final linked = identity != null;
    final enabled = _providerEnabled(provider);

    return AppSurfaceCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _providerLabel(provider),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  linked
                      ? (identity['provider_email']?.toString().isNotEmpty ==
                                true
                            ? identity['provider_email'].toString()
                            : 'Cuenta vinculada')
                      : enabled
                      ? 'No vinculada'
                      : 'No configurado en esta compilación',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (linked)
            TextButton(
              onPressed: () => _unlink(provider),
              child: const Text('Desvincular'),
            )
          else
            TextButton(
              onPressed: enabled ? () => _link(provider) : null,
              child: const Text('Vincular'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPassword = _security['has_usable_password'] == true;
    final activeSessions =
        int.tryParse(_security['active_sessions']?.toString() ?? '') ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Seguridad de acceso'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  const AppSectionHeader(
                    title: 'Acceso y sesiones',
                    subtitle:
                        'Administra tu contraseña, accesos sociales y dispositivos activos.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null)
                    AppSurfaceCard(
                      backgroundColor: AppColors.coralSoft,
                      borderColor: AppColors.tint(AppColors.danger, 0.28),
                      child: Text(_error!),
                    ),
                  AppSurfaceCard(
                    child: Column(
                      children: [
                        AppInfoRow(
                          icon: Icons.password_outlined,
                          label: 'Contraseña local',
                          value: hasPassword ? 'Configurada' : 'No configurada',
                          valueColor: hasPassword
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        const Divider(),
                        AppInfoRow(
                          icon: Icons.devices_outlined,
                          label: 'Sesiones activas',
                          value: '$activeSessions',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: hasPassword
                                ? () => Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ChangePasswordPage(),
                                    ),
                                  )
                                : null,
                            icon: const Icon(Icons.password_outlined),
                            label: const Text('Cambiar contraseña'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget.onOpenSessions,
                            icon: const Icon(Icons.devices_other_outlined),
                            label: const Text('Administrar dispositivos'),
                          ),
                        ),
                        if (!hasPassword) ...[
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'Esta cuenta utiliza acceso social. Para crear una contraseña local usa la recuperación por correo desde la pantalla de ingreso.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AppSectionHeader(
                    title: 'Métodos sociales',
                    subtitle:
                        'Vincular una cuenta adicional ayuda a recuperar el acceso.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _providerCard('google', Icons.g_mobiledata_rounded),
                  const SizedBox(height: AppSpacing.md),
                  _providerCard('facebook', Icons.facebook_rounded),
                  const SizedBox(height: AppSpacing.lg),
                  const AppSurfaceCard(
                    backgroundColor: AppColors.surfaceSoft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'GoWith nunca almacena tu contraseña de Google o Facebook. El acceso se valida de forma segura con cada proveedor.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
