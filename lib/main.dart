import 'package:flutter/material.dart';

import 'core/navigation/role_gate_page.dart';
import 'core/network/token_storage.dart';
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
      title: 'Acompañante',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
  }
}
