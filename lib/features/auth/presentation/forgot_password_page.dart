import 'package:flutter/material.dart';

import 'password_reset_request_page.dart';

/// Compatibility alias for older navigation code.
///
/// New code should open [PasswordResetRequestPage] directly.
@Deprecated('Use PasswordResetRequestPage instead.')
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PasswordResetRequestPage();
  }
}
