import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/app_components.dart';
import '../data/account_service.dart';

class SecurityPhonePage extends StatefulWidget {
  const SecurityPhonePage({super.key});

  @override
  State<SecurityPhonePage> createState() => _SecurityPhonePageState();
}

class _SecurityPhonePageState extends State<SecurityPhonePage> {
  final AccountService _service = AccountService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _callingCode = '+57';
  String _maskedPhone = '';
  int _emergencyContactsCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getSecurityPhone();
      final normalized = data['normalized_phone']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _maskedPhone = data['masked_phone']?.toString() ?? '';
        _emergencyContactsCount =
            (data['emergency_contacts_count'] as num?)?.toInt() ?? 0;
        if (normalized.startsWith('+57')) {
          _callingCode = '+57';
          _phone.text = normalized.substring(3);
        } else if (normalized.startsWith('+1')) {
          _callingCode = '+1';
          _phone.text = normalized.substring(2);
        } else {
          _phone.text = normalized.replaceFirst(RegExp(r'^\+'), '');
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible consultar el teléfono de seguridad.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Ingresa el número de teléfono';
    if (_callingCode == '+57') {
      if (digits.length != 10 || !digits.startsWith('3')) {
        return 'Ingresa un celular colombiano de 10 dígitos';
      }
    } else if (digits.length != 10) {
      return 'Ingresa un número de 10 dígitos';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = await _service.updateSecurityPhone('$_callingCode$digits');
      if (!mounted) return;
      setState(() {
        _maskedPhone = data['masked_phone']?.toString() ?? '';
        _emergencyContactsCount =
            (data['emergency_contacts_count'] as num?)?.toInt() ?? 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teléfono de seguridad actualizado correctamente.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible actualizar el teléfono de seguridad.',
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Teléfono de seguridad'),
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
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  const AppSectionHeader(
                    title: 'Tu teléfono personal',
                    subtitle:
                        'Se utiliza únicamente para seguridad y emergencias. No se comparte con otros usuarios ni se usa como canal de conversación.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppSurfaceCard(
                    backgroundColor: AppColors.tint(AppColors.primary, 0.07),
                    borderColor: AppColors.tint(AppColors.primary, 0.22),
                    child: Column(
                      children: [
                        AppInfoRow(
                          icon: Icons.phone_android_outlined,
                          label: 'Teléfono registrado',
                          value: _maskedPhone.isEmpty
                              ? 'No registrado'
                              : _maskedPhone,
                        ),
                        const Divider(),
                        AppInfoRow(
                          icon: Icons.contact_emergency_outlined,
                          label: 'Contactos de emergencia',
                          value: '$_emergencyContactsCount registrados',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final countryField = DropdownButtonFormField<String>(
                        initialValue: _callingCode,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'País'),
                        items: const [
                          DropdownMenuItem(
                            value: '+57',
                            child: Text(
                              'Colombia +57',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: '+1',
                            child: Text(
                              'EE. UU. / Canadá +1',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _callingCode = value);
                          }
                        },
                      );
                      final phoneField = TextFormField(
                        controller: _phone,
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          labelText: 'Número celular',
                          hintText: '3001234567',
                        ),
                      );

                      if (constraints.maxWidth < 430) {
                        return Column(
                          children: [
                            countryField,
                            const SizedBox(height: AppSpacing.md),
                            phoneField,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 180, child: countryField),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: phoneField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const AppSurfaceCard(
                    backgroundColor: AppColors.surfaceSoft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Este número debe ser diferente al de tus contactos de emergencia. Actualmente no se envían mensajes por SMS ni WhatsApp.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppSurfaceCard(
                      backgroundColor: AppColors.coralSoft,
                      borderColor: AppColors.tint(AppColors.danger, 0.28),
                      child: Text(_error!),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar teléfono de seguridad'),
                  ),
                ],
              ),
            ),
    );
  }
}
