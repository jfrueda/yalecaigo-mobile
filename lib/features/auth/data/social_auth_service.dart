import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';

class SocialAuthService {
  bool _googleInitialized = false;

  Future<void> initializeGoogle() async {
    if (_googleInitialized || !AppConfig.googleAuthEnabled) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId,
    );
    _googleInitialized = true;
  }

  Future<String> signInWithGoogle() async {
    if (!AppConfig.googleAuthEnabled) {
      throw const FormatException(
        'Google todavía no está configurado en esta compilación.',
      );
    }
    await initializeGoogle();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const FormatException(
        'No pudimos completar el ingreso con Google.',
      );
    }
    return idToken;
  }

  Future<String> signInWithFacebook() async {
    if (!AppConfig.facebookAuthEnabled) {
      throw const FormatException(
        'Facebook todavía no está configurado en esta compilación.',
      );
    }
    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );
    if (result.status == LoginStatus.cancelled) {
      throw const FormatException('El ingreso con Facebook fue cancelado.');
    }
    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw FormatException(
        result.message ?? 'No fue posible ingresar con Facebook.',
      );
    }
    return result.accessToken!.tokenString;
  }

  Future<void> signOutProviders() async {
    if (AppConfig.googleAuthEnabled) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    if (AppConfig.facebookAuthEnabled) {
      try {
        await FacebookAuth.instance.logOut();
      } catch (_) {}
    }
  }
}
