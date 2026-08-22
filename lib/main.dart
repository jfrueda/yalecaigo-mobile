import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'core/branding/app_branding.dart';
import 'core/navigation/role_gate_page.dart';
import 'core/preferences/app_preferences_controller.dart';
import 'core/network/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/password_reset_confirm_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appPreferences.load();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _listenLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _listenLinks() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleLink(initial);
      });
    }
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) {
    final acceptedScheme =
        uri.scheme == AppBranding.passwordResetScheme ||
        uri.scheme == AppBranding.legacyPasswordResetScheme;
    if (!acceptedScheme || uri.host != 'password-reset') {
      return;
    }

    final uid = uri.queryParameters['uid'];
    final token = uri.queryParameters['token'];
    if (uid == null || token == null || uid.isEmpty || token.isEmpty) {
      return;
    }

    appNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => PasswordResetConfirmPage(uid: uid, token: token),
      ),
    );
  }

  Future<bool> _hasSession() async {
    final token = await TokenStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appPreferences,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: AppBranding.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(highContrast: appPreferences.highContrast),
          themeAnimationDuration: appPreferences.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(appPreferences.textScale),
                disableAnimations:
                    appPreferences.reduceMotion || media.disableAnimations,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: FutureBuilder<bool>(
            future: _hasSession(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return snapshot.data == true
                  ? const RoleGatePage()
                  : const LoginPage();
            },
          ),
        );
      },
    );
  }
}
