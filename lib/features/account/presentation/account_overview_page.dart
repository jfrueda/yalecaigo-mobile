import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/brand_logo.dart';

class AccountOverviewPage extends StatelessWidget {
  const AccountOverviewPage({
    super.key,
    required this.profile,
    required this.onLogout,
    required this.onOpenProfile,
    required this.onOpenSecurityPhone,
    required this.onOpenIdentity,
    required this.onOpenOnboarding,
    required this.onOpenEmergencyContacts,
    required this.onOpenSessions,
    required this.onOpenAccountSecurity,
    required this.onOpenPreferences,
    required this.onOpenBlockedUsers,
    required this.onOpenAccountDeletion,
    this.onOpenProviderCapabilities,
    this.providerMode = false,
  });

  final Map<String, dynamic>? profile;
  final VoidCallback onLogout;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSecurityPhone;
  final VoidCallback onOpenIdentity;
  final VoidCallback onOpenOnboarding;
  final VoidCallback onOpenEmergencyContacts;
  final VoidCallback onOpenSessions;
  final VoidCallback onOpenAccountSecurity;
  final VoidCallback onOpenPreferences;
  final VoidCallback onOpenBlockedUsers;
  final VoidCallback onOpenAccountDeletion;
  final VoidCallback? onOpenProviderCapabilities;
  final bool providerMode;

  Map<String, dynamic> _mapValue(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Map<String, dynamic> get _root => profile ?? const {};

  Map<String, dynamic> get _userData {
    final nested = _mapValue(_root['user']);
    return nested.isNotEmpty ? nested : _root;
  }

  Map<String, dynamic> get _profileData {
    final nestedUserProfile = _mapValue(_userData['profile']);
    if (nestedUserProfile.isNotEmpty) return nestedUserProfile;
    return _mapValue(_root['profile']);
  }

  Map<String, dynamic> get _onboarding => _mapValue(_root['onboarding']);

  Map<String, dynamic> get _onboardingAccount {
    return _mapValue(_onboarding['account']);
  }

  Map<String, dynamic> get _activation {
    return _mapValue(_onboarding['activation']);
  }

  String _firstNonEmpty(Iterable<Object?> values, [String fallback = '']) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  String _value(String key, [String fallback = 'No registrado']) {
    return _firstNonEmpty([
      _profileData[key],
      _userData[key],
      _onboardingAccount[key],
      _root[key],
    ], fallback);
  }

  String get _displayName {
    final profileName = _firstNonEmpty([
      '${_profileData['first_name'] ?? ''} ${_profileData['last_name'] ?? ''}'
          .trim(),
    ]);
    final userName = _firstNonEmpty([
      '${_userData['first_name'] ?? ''} ${_userData['last_name'] ?? ''}'.trim(),
    ]);
    return _firstNonEmpty([
      _onboardingAccount['display_name'],
      _userData['display_name'],
      profileName,
      userName,
      _userData['username'],
      _userData['email'],
    ], 'Usuario');
  }

  bool get _activationEligible {
    return _activation['eligible'] == true ||
        _userData['activation_eligible'] == true ||
        _root['activation_eligible'] == true;
  }

  String get _accountStatus {
    return _firstNonEmpty([
      _onboarding['account_status'],
      _userData['status'],
      _root['status'],
    ], 'PENDING').toUpperCase();
  }

  bool get _identityVerified {
    return _userData['identity_verified'] == true ||
        _root['identity_verified'] == true ||
        _onboardingAccount['identity_verified'] == true;
  }

  String get _genderLabel {
    switch (_value('gender', '').toUpperCase()) {
      case 'M':
        return 'Masculino';
      case 'F':
        return 'Femenino';
      case 'NB':
        return 'No binario';
      case 'O':
        return 'Otro';
      default:
        return 'No registrado';
    }
  }

  ({String label, Color color, IconData icon}) get _statusDisplay {
    if (_activationEligible) {
      return (
        label: 'Cuenta habilitada',
        color: AppColors.success,
        icon: Icons.verified_outlined,
      );
    }

    switch (_accountStatus) {
      case 'SUSPENDED':
        return (
          label: 'Cuenta suspendida',
          color: AppColors.danger,
          icon: Icons.block_outlined,
        );
      case 'DELETION_REQUESTED':
        return (
          label: 'Eliminación solicitada',
          color: AppColors.warning,
          icon: Icons.delete_outline,
        );
      case 'DEACTIVATED':
        return (
          label: 'Cuenta desactivada',
          color: AppColors.danger,
          icon: Icons.person_off_outlined,
        );
      case 'VERIFIED':
        return (
          label: 'Pendiente de requisitos',
          color: AppColors.warning,
          icon: Icons.fact_check_outlined,
        );
      default:
        return (
          label: 'En proceso de habilitación',
          color: AppColors.warning,
          icon: Icons.schedule_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusDisplay = _statusDisplay;
    final photo = _value('profile_photo', '');
    final email = _value('email');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        const AppSectionHeader(
          title: 'Tu cuenta',
          subtitle: 'Perfil, seguridad, dispositivos y control de la cuenta.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSurfaceCard(
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: photo.isEmpty
                    ? const Icon(
                        Icons.person_outline,
                        size: 34,
                        color: AppColors.primary,
                      )
                    : Image.network(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person_outline,
                              size: 34,
                              color: AppColors.primary,
                            ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (_identityVerified) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Identidad verificada',
                            child: Icon(
                              Icons.verified_rounded,
                              size: 22,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(email, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AppStatusPill(
                          label: statusDisplay.label,
                          color: statusDisplay.color,
                          icon: statusDisplay.icon,
                        ),
                        if (_identityVerified)
                          AppStatusPill(
                            label: 'Identidad verificada',
                            color: Theme.of(context).colorScheme.primary,
                            icon: Icons.verified_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSurfaceCard(
          child: Column(
            children: [
              AppInfoRow(
                icon: Icons.badge_outlined,
                label: 'Modo',
                value: providerMode ? 'Acompañante' : 'Solicitante',
              ),
              const Divider(),
              AppInfoRow(
                icon: Icons.person_outline,
                label: 'Sexo',
                value: _genderLabel,
              ),
              const Divider(),
              AppInfoRow(
                icon: Icons.location_city_outlined,
                label: 'Ciudad',
                value: _value('city'),
              ),
              const Divider(),
              AppInfoRow(
                icon: Icons.phone_outlined,
                label: 'Celular',
                value: _firstNonEmpty([
                  _userData['security_phone_masked'],
                  _root['security_phone_masked'],
                  _userData['phone_number'],
                  _onboardingAccount['security_phone_masked'],
                ], 'No registrado'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _AccountMenuTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Información personal',
                subtitle: 'Fotografía, fecha de nacimiento, ciudad y perfil.',
                onTap: onOpenProfile,
              ),
              const Divider(height: 1),
              _AccountMenuTile(
                icon: Icons.phone_android_outlined,
                title: 'Celular',
                subtitle: 'Consulta o actualiza tu número personal.',
                onTap: onOpenSecurityPhone,
              ),
              const Divider(height: 1),
              _AccountMenuTile(
                icon: Icons.verified_user_outlined,
                title: 'Verificación de identidad',
                subtitle: 'Documento y selfie para proteger tu cuenta.',
                onTap: onOpenIdentity,
              ),
              const Divider(height: 1),
              _AccountMenuTile(
                icon: Icons.fact_check_outlined,
                title: 'Mi cuenta',
                subtitle: 'Consulta tus opciones y el estado de tu cuenta.',
                onTap: onOpenOnboarding,
              ),
              const Divider(height: 1),
              _AccountMenuTile(
                icon: Icons.contact_emergency_outlined,
                title: 'Personas de confianza',
                subtitle:
                    'Personas que quieres incluir en tus opciones de seguridad.',
                onTap: onOpenEmergencyContacts,
              ),
              if (providerMode && onOpenProviderCapabilities != null) ...[
                const Divider(height: 1),
                _AccountMenuTile(
                  icon: Icons.category_outlined,
                  title: 'Actividades y disponibilidad',
                  subtitle: 'Selecciona las actividades que quieres ofrecer.',
                  onTap: onOpenProviderCapabilities!,
                ),
              ],
              const Divider(height: 1),
              _AccountMenuTile(
                icon: Icons.security_outlined,
                title: 'Seguridad de acceso',
                subtitle: 'Contraseña, Google, Facebook y sesiones activas.',
                onTap: onOpenAccountSecurity,
              ),
              const Divider(height: 1),
              _AccountMenuTile(
                icon: Icons.tune_rounded,
                title: 'Preferencias y accesibilidad',
                subtitle:
                    'Idioma, comunicaciones, texto, contraste y movimiento.',
                onTap: onOpenPreferences,
              ),
              const Divider(height: 1),
              _AccountMenuTile(
                icon: Icons.devices_outlined,
                title: 'Dispositivos y sesiones',
                subtitle: 'Cierra accesos que no reconozcas.',
                onTap: onOpenSessions,
              ),
              const Divider(height: 1),
              _AccountMenuTile(
                icon: Icons.block_outlined,
                title: 'Usuarios bloqueados',
                subtitle: 'Consulta y administra bloqueos entre usuarios.',
                onTap: onOpenBlockedUsers,
              ),
              const Divider(height: 1),
              _AccountMenuTile(
                icon: Icons.delete_outline,
                iconColor: AppColors.danger,
                title: 'Eliminar cuenta',
                subtitle: 'Solicitud, confirmación y periodo de espera.',
                onTap: onOpenAccountDeletion,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
        const SizedBox(height: AppSpacing.xl),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        const Center(child: OpenticAttribution(imageWidth: 108, compact: true)),
      ],
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  const _AccountMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
