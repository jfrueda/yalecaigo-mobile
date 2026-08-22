import 'package:flutter/material.dart';

import '../../features/account/data/account_service.dart';
import '../../features/account/presentation/account_deletion_page.dart';
import '../../features/account/presentation/account_security_page.dart';
import '../../features/account/presentation/account_overview_page.dart';
import '../../features/account/presentation/emergency_contacts_page.dart';
import '../../features/account/presentation/identity_verification_page.dart';
import '../../features/account/presentation/profile_edit_page.dart';
import '../../features/account/presentation/preferences_page.dart';
import '../../features/account/presentation/provider_capabilities_page.dart';
import '../../features/account/presentation/session_management_page.dart';
import '../../features/account/presentation/security_phone_page.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/auth/data/me_service.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/onboarding_status_page.dart';
import '../../features/provider/presentation/available_requests_page.dart';
import '../../features/provider/presentation/provider_active_service_page.dart';
import '../../features/provider/presentation/provider_history_page.dart';
import '../../features/provider/presentation/provider_services_history_page.dart';
import '../../features/safety/presentation/safety_center_page.dart';
import '../../features/trust/presentation/blocked_users_page.dart';
import '../../features/service_request/data/service_request_query_service.dart';
import '../../shared/widgets/app_brand.dart';
import '../../shared/widgets/notification_bell.dart';
import '../../shared/widgets/mode_switch_button.dart';
import 'client_shell.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  final AuthService _authService = AuthService();
  final AccountService _accountService = AccountService();
  final MeService _meService = MeService();
  final ServiceRequestQueryService _requestService =
      ServiceRequestQueryService();

  int _index = 0;
  bool _loadingProfile = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _activeRequest;

  static const List<String> _titles = [
    'Actividades',
    'Histórico',
    'Ganancias',
    'Seguridad',
    'Cuenta',
  ];

  @override
  void initState() {
    super.initState();
    _loadShellData();
  }

  Future<void> _loadShellData() async {
    if (mounted) {
      setState(() => _loadingProfile = true);
    }

    Map<String, dynamic>? loadedProfile;
    Map<String, dynamic>? loadedActiveRequest;
    var activeRequestLoaded = false;

    try {
      final response = await _meService.getMe();
      loadedProfile = Map<String, dynamic>.from(response);
    } catch (_) {
      // Conserva el último perfil válido. Un error de otro módulo no debe
      // convertir la tarjeta de Cuenta en "Usuario / No registrado".
    }

    try {
      final active = await _requestService.getActiveRequest();
      loadedActiveRequest = active == null
          ? null
          : Map<String, dynamic>.from(active);
      activeRequestLoaded = true;
    } catch (_) {
      // El perfil se actualiza aunque la consulta de actividad activa falle.
    }

    if (!mounted) return;
    setState(() {
      if (loadedProfile != null) {
        _profile = loadedProfile;
      }
      if (activeRequestLoaded) {
        _activeRequest = loadedActiveRequest;
      }
      _loadingProfile = false;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas salir de tu cuenta en este dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
    await _loadShellData();
  }

  Future<void> _openActiveService() async {
    if (_activeRequest == null) return;
    await _push(ProviderActiveServicePage(serviceRequest: _activeRequest!));
  }

  Future<void> _switchToClientMode() async {
    try {
      await _accountService.setActiveMode('client');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ClientShell()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos cambiar al modo Solicitar. Intenta nuevamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      AvailableRequestsPage(
        embedded: true,
        onOpenOnboarding: () => _push(const OnboardingStatusPage()),
      ),
      const ProviderServicesHistoryPage(embedded: true),
      const ProviderHistoryPage(embedded: true),
      SafetyCenterPage(
        hasActiveService: _activeRequest != null,
        onOpenActiveService: _activeRequest == null ? null : _openActiveService,
      ),
      _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : AccountOverviewPage(
              profile: _profile,
              providerMode: true,
              onLogout: _logout,
              onOpenSecurityPhone: () => _push(const SecurityPhonePage()),
              onOpenProfile: () =>
                  _push(const ProfileEditPage(providerMode: true)),
              onOpenIdentity: () => _push(const IdentityVerificationPage()),
              onOpenOnboarding: () => _push(const OnboardingStatusPage()),
              onOpenEmergencyContacts: () =>
                  _push(const EmergencyContactsPage()),
              onOpenProviderCapabilities: () =>
                  _push(const ProviderCapabilitiesPage()),
              onOpenSessions: () => _push(const SessionManagementPage()),
              onOpenAccountSecurity: () => _push(
                AccountSecurityPage(
                  onOpenSessions: () => _push(const SessionManagementPage()),
                ),
              ),
              onOpenPreferences: () => _push(const PreferencesPage()),
              onOpenBlockedUsers: () => _push(const BlockedUsersPage()),
              onOpenAccountDeletion: () => _push(const AccountDeletionPage()),
            ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: AppBrandAppBarTitle(label: _titles[_index]),
        actions: [
          ModeSwitchButton(
            currentMode: 'Acompañar',
            targetMode: 'Solicitar',
            onSwitch: _switchToClientMode,
          ),
          if (_activeRequest != null)
            IconButton(
              tooltip: 'Actividad activa',
              onPressed: _openActiveService,
              icon: const Icon(Icons.play_circle_outline_rounded),
            ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadShellData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const NotificationBell(),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
          if (value == 4) {
            _loadShellData();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Actividades',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Ganancias',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Seguridad',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}
