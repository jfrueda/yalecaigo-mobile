import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_components.dart';

class SafetyCenterPage extends StatelessWidget {
  const SafetyCenterPage({
    super.key,
    this.hasActiveService = false,
    this.onOpenActiveService,
  });

  final bool hasActiveService;
  final VoidCallback? onOpenActiveService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        const AppSectionHeader(
          title: 'Seguridad y ayuda',
          subtitle:
              'Herramientas para coordinar actividades con más confianza.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSurfaceCard(
          backgroundColor: AppColors.tint(AppColors.primary, 0.07),
          borderColor: AppColors.tint(AppColors.primary, 0.22),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: AppColors.primary,
                size: 34,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'Antes de encontrarte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Elige un lugar público, revisa la actividad y confirma que la información coincida antes de iniciar.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppSurfaceCard(
          child: Column(
            children: [
              AppInfoRow(
                icon: Icons.store_mall_directory_outlined,
                label: 'Puntos recomendados',
                value:
                    'Parques, cafés, restaurantes, bibliotecas y centros comerciales.',
              ),
              Divider(),
              AppInfoRow(
                icon: Icons.block_outlined,
                label: 'Evita en la primera reunión',
                value: 'Viviendas, habitaciones, hoteles y sitios aislados.',
              ),
              Divider(),
              AppInfoRow(
                icon: Icons.password_outlined,
                label: 'Código de inicio',
                value:
                    'La actividad solo comienza cuando ambos llegan y el acompañante valida el código.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (hasActiveService)
          AppSurfaceCard(
            backgroundColor: AppColors.tint(AppColors.warning, 0.08),
            borderColor: AppColors.tint(AppColors.warning, 0.28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.support_agent_outlined,
                      color: AppColors.warning,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Tienes una actividad activa',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Abre la actividad para avisar que llegarás tarde, cancelar cuando esté permitido o reportar una situación.',
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: onOpenActiveService,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir actividad activa'),
                ),
              ],
            ),
          )
        else
          const AppSurfaceCard(
            child: AppEmptyState(
              icon: Icons.shield_outlined,
              title: 'Sin actividad activa',
              message:
                  'Las herramientas de reporte aparecen cuando existe una actividad aceptada o en curso.',
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        const AppSurfaceCard(
          backgroundColor: Color(0xFFFFF7F7),
          borderColor: Color(0xFFF0CECE),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emergency_outlined, color: AppColors.danger),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'Emergencias reales',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'YaLeCaigo registra y remite reportes dentro de la plataforma. Si existe peligro inmediato, comunícate con la línea local de emergencias.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
