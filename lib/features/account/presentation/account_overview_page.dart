import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_components.dart';

class AccountOverviewPage extends StatelessWidget {
  const AccountOverviewPage({
    super.key,
    required this.profile,
    required this.onLogout,
    this.providerMode = false,
  });

  final Map<String, dynamic>? profile;
  final VoidCallback onLogout;
  final bool providerMode;

  String _value(String key, [String fallback = 'No registrado']) {
    final raw = profile?[key];
    if (raw == null || raw.toString().trim().isEmpty) {
      return fallback;
    }
    return raw.toString();
  }

  @override
  Widget build(BuildContext context) {
    final username = _value('username', 'Usuario');
    final email = _value('email');
    final verified = profile?['is_verified'] == true;

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
          subtitle: 'Información de perfil, seguridad y sesión.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSurfaceCard(
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(email, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    AppStatusPill(
                      label: verified
                          ? 'Cuenta verificada'
                          : 'Verificación pendiente',
                      color: verified ? AppColors.success : AppColors.warning,
                      icon: verified
                          ? Icons.verified_outlined
                          : Icons.schedule_outlined,
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
                label: 'Rol',
                value: providerMode ? 'Acompañante' : 'Solicitante',
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
                label: 'Teléfono',
                value: _value('phone'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppSurfaceCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_outline, color: AppColors.primary),
                title: Text('Privacidad y seguridad'),
                subtitle: Text(
                  'Gestiona tu acceso y la protección de la cuenta.',
                ),
                trailing: Icon(Icons.chevron_right),
              ),
              Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.help_outline, color: AppColors.primary),
                title: Text('Ayuda'),
                subtitle: Text(
                  'Consulta información sobre el uso de la aplicación.',
                ),
                trailing: Icon(Icons.chevron_right),
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
      ],
    );
  }
}
