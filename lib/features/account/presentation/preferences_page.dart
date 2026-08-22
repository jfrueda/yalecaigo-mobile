import 'package:flutter/material.dart';

import '../../../core/preferences/app_preferences_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/app_components.dart';
import '../data/account_service.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  final AccountService _service = AccountService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _preferredLanguage = 'es';
  bool _inAppNotifications = true;
  bool _emailNotifications = true;
  bool _securityAlerts = true;
  double _textScale = appPreferences.textScale;
  bool _highContrast = appPreferences.highContrast;
  bool _reduceMotion = appPreferences.reduceMotion;

  Map<String, dynamic> _map(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

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
      final response = await _service.getProfile();
      final profile = _map(response['profile']);
      if (!mounted) return;
      setState(() {
        _preferredLanguage =
            profile['preferred_language']?.toString().toLowerCase() == 'en'
            ? 'en'
            : 'es';
        _inAppNotifications = profile['in_app_notifications_enabled'] != false;
        _emailNotifications = profile['email_notifications_enabled'] != false;
        _securityAlerts = profile['security_alerts_enabled'] != false;
        _textScale = appPreferences.textScale;
        _highContrast = appPreferences.highContrast;
        _reduceMotion = appPreferences.reduceMotion;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible cargar las preferencias.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.updateProfile({
        'preferred_language': _preferredLanguage,
        'in_app_notifications_enabled': _inAppNotifications,
        'email_notifications_enabled': _emailNotifications,
        'security_alerts_enabled': _securityAlerts,
      });
      await appPreferences.update(
        textScale: _textScale,
        highContrast: _highContrast,
        reduceMotion: _reduceMotion,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferencias actualizadas.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible guardar las preferencias.',
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetAccessibility() async {
    await appPreferences.resetAccessibility();
    if (!mounted) return;
    setState(() {
      _textScale = 1.0;
      _highContrast = false;
      _reduceMotion = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accesibilidad restablecida.')),
    );
  }

  String _scaleLabel(double value) {
    if (value <= 0.95) return 'Compacto';
    if (value <= 1.05) return 'Normal';
    if (value <= 1.18) return 'Grande';
    return 'Muy grande';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBrandAppBarTitle(label: 'Preferencias')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  const AppSectionHeader(
                    title: 'Personaliza GoWith',
                    subtitle:
                        'Controla comunicaciones, idioma y opciones de accesibilidad.',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Idioma principal',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'es',
                              icon: Text('🇨🇴'),
                              label: Text('Español'),
                            ),
                            ButtonSegment<String>(
                              value: 'en',
                              icon: Text('🇺🇸'),
                              label: Text('English'),
                            ),
                          ],
                          selected: {_preferredLanguage},
                          onSelectionChanged: (values) {
                            setState(() => _preferredLanguage = values.first);
                          },
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'La interfaz completa continuará en español durante esta versión. Esta preferencia se usará para comunicaciones y contenido futuro.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppSurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          value: _inAppNotifications,
                          onChanged: (value) {
                            setState(() => _inAppNotifications = value);
                          },
                          secondary: const Icon(
                            Icons.notifications_active_outlined,
                            color: AppColors.primary,
                          ),
                          title: const Text('Notificaciones en GoWith'),
                          subtitle: const Text(
                            'Actualizaciones de cuenta, actividades y seguridad.',
                          ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile.adaptive(
                          value: _emailNotifications,
                          onChanged: (value) {
                            setState(() => _emailNotifications = value);
                          },
                          secondary: const Icon(
                            Icons.email_outlined,
                            color: AppColors.primary,
                          ),
                          title: const Text('Comunicaciones por correo'),
                          subtitle: const Text(
                            'Avisos administrativos y cambios importantes.',
                          ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile.adaptive(
                          value: _securityAlerts,
                          onChanged: (value) {
                            setState(() => _securityAlerts = value);
                          },
                          secondary: const Icon(
                            Icons.shield_outlined,
                            color: AppColors.coral,
                          ),
                          title: const Text('Alertas de seguridad'),
                          subtitle: const Text(
                            'Se recomienda mantenerlas activas para cambios de acceso e incidentes.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accesibilidad',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Tamaño del texto: ${_scaleLabel(_textScale)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Slider(
                          value: _textScale,
                          min: 0.9,
                          max: 1.3,
                          divisions: 4,
                          label: _scaleLabel(_textScale),
                          onChanged: (value) {
                            setState(() => _textScale = value);
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _highContrast,
                          onChanged: (value) {
                            setState(() => _highContrast = value);
                          },
                          title: const Text('Contraste reforzado'),
                          subtitle: const Text(
                            'Aumenta la separación visual entre controles y contenido.',
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _reduceMotion,
                          onChanged: (value) {
                            setState(() => _reduceMotion = value);
                          },
                          title: const Text('Reducir animaciones'),
                          subtitle: const Text(
                            'Disminuye las transiciones visuales de la aplicación.',
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _resetAccessibility,
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Restablecer accesibilidad'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Guardando...' : 'Guardar preferencias',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
