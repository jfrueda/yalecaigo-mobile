import 'package:flutter/material.dart';
import 'core/network/token_storage.dart';
import 'core/navigation/role_gate_page.dart';
import 'features/auth/presentation/login_page.dart';

void main() {
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
      theme: ThemeData(useMaterial3: true),
      home: FutureBuilder<bool>(
        future: _hasSession(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return snapshot.data!
              ? const RoleGatePage()
              : const LoginPage();
        },
      ),
    );
  }
}
