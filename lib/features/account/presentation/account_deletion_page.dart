import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/network/token_storage.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/app_components.dart';
import '../../auth/presentation/login_page.dart';
import '../data/account_service.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final AccountService _service = AccountService();
  bool _loading = true;
  Map<String, dynamic> _status = const {};
  String? _error;

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
      final status = await _service.getAccountDeletionStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible consultar el estado de la cuenta.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _request {
    final value = _status['request'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Map<String, dynamic> get _eligibility {
    final value = _status['eligibility'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Future<void> _requestDeletion() async {
    final form = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _DeletionRequestDialog(),
    );
    if (form == null) return;
    try {
      final response = await _service.requestAccountDeletion(
        password: form['password'] ?? '',
        reason: form['reason'] ?? '',
      );
      final request = response['request'];
      final challenge = response['challenge'];
      if (!mounted) return;
      final requestId = request is Map
          ? request['public_id']?.toString()
          : null;
      final challengeId = challenge is Map ? challenge['id']?.toString() : null;
      if (requestId == null || requestId.isEmpty) {
        throw const FormatException(
          'No pudimos iniciar la solicitud de eliminación.',
        );
      }
      final code = await showDialog<String>(
        context: context,
        builder: (_) => _DeletionOtpDialog(challengeId: challengeId),
      );
      if (code == null || code.isEmpty) {
        await _load();
        return;
      }
      await _service.confirmAccountDeletion(requestId: requestId, code: code);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Eliminación programada'),
          content: const Text(
            'La cuenta quedó en proceso de eliminación y las sesiones fueron cerradas. Revisa el correo para conservar el enlace de cancelación.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      await TokenStorage.clearSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: 'No fue posible solicitar la eliminación.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _cancelDeletion() async {
    final requestId = _request['public_id']?.toString();
    if (requestId == null || requestId.isEmpty) return;
    try {
      await _service.cancelAccountDeletion(requestId: requestId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La solicitud de eliminación fue cancelada.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: 'No fue posible cancelar la eliminación.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _eligibility['eligible'] == true;
    final blockedRaw = _eligibility['blockers'];
    final blocked = blockedRaw is List
        ? blockedRaw.map((item) {
            if (item is Map && item['message'] != null) {
              return item['message'].toString();
            }
            return item.toString();
          }).toList()
        : <String>[];
    final requestStatus = _request['status']?.toString() ?? '';
    final hasRequest = _request.isNotEmpty;
    final canCancel = _request['can_cancel'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Eliminar cuenta'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                const AppSectionHeader(
                  title: 'Cierre de la cuenta',
                  subtitle:
                      'La eliminación requiere contraseña, código por correo y un periodo de espera.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSurfaceCard(
                  backgroundColor: AppColors.coralSoft,
                  borderColor: AppColors.tint(AppColors.danger, 0.28),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        size: 34,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Antes de continuar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'No se procesa una cuenta con actividades, pagos, incidentes o saldos pendientes. Los registros exigidos por obligaciones legales y de seguridad pueden conservarse de forma seudonimizada.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_error != null)
                  AppSurfaceCard(child: Text(_error!))
                else if (hasRequest)
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.hourglass_top_rounded,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Solicitud: $requestStatus',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppInfoRow(
                          icon: Icons.event_outlined,
                          label: 'Programada para',
                          value: _request['scheduled_for']?.toString() ?? '-',
                        ),
                        if (canCancel) ...[
                          const Divider(),
                          OutlinedButton.icon(
                            onPressed: _cancelDeletion,
                            icon: const Icon(Icons.undo_rounded),
                            label: const Text('Cancelar eliminación'),
                          ),
                        ],
                      ],
                    ),
                  )
                else ...[
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppStatusPill(
                          label: canDelete
                              ? 'Cuenta elegible'
                              : 'Cuenta con pendientes',
                          color: canDelete
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        if (blocked.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Debes resolver:',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ...blocked.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 18,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(item)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    onPressed: canDelete ? _requestDeletion : null,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Solicitar eliminación'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _DeletionRequestDialog extends StatefulWidget {
  const _DeletionRequestDialog();

  @override
  State<_DeletionRequestDialog> createState() => _DeletionRequestDialogState();
}

class _DeletionRequestDialogState extends State<_DeletionRequestDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar identidad'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                validator: (value) => value == null || value.isEmpty
                    ? 'Ingresa tu contraseña'
                    : null,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Motivo opcional'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'password': _password.text,
              'reason': _reason.text,
            });
          },
          child: const Text('Enviar código'),
        ),
      ],
    );
  }
}

class _DeletionOtpDialog extends StatefulWidget {
  const _DeletionOtpDialog({this.challengeId});

  final String? challengeId;

  @override
  State<_DeletionOtpDialog> createState() => _DeletionOtpDialogState();
}

class _DeletionOtpDialogState extends State<_DeletionOtpDialog> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Código de confirmación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ingresa el código enviado a tu correo. No lo compartas con otras personas.',
          ),
          if (widget.challengeId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Referencia: ${widget.challengeId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'Código'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _code.text.trim()),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
