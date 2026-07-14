import 'package:flutter/material.dart';

import 'core/navigation/role_gate_page.dart';
import 'core/network/token_storage.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _hasSession() async {
    final token = await TokenStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YaLeCaigo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: FutureBuilder<bool>(
        future: _hasSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LaunchPage();
          }
          return snapshot.data == true
              ? const RoleGatePage()
              : const LoginPage();
        },
      ),
    );
  }
}

class _LaunchPage extends StatelessWidget {
  const _LaunchPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.route_outlined, color: Colors.white, size: 34),
            ),
            SizedBox(height: 18),
            Text(
              'YaLeCaigo',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
