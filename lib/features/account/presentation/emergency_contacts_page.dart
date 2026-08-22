import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/app_components.dart';
import '../data/account_service.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  final AccountService _service = AccountService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _contacts = const [];

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
      final contacts = await _service.listEmergencyContacts();
      if (!mounted) return;
      setState(() => _contacts = contacts);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No pudimos consultar tus personas de confianza.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? contact]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EmergencyContactDialog(contact: contact),
    );
    if (result == null) return;

    try {
      final id = int.tryParse(contact?['id']?.toString() ?? '');
      if (id == null) {
        await _service.createEmergencyContact(result);
      } else {
        await _service.updateEmergencyContact(id, result);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            id == null
                ? 'Persona de confianza registrada.'
                : 'Persona de confianza actualizada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: 'No pudimos guardar esta persona de confianza.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> contact) async {
    final id = int.tryParse(contact['id']?.toString() ?? '');
    if (id == null) return;
    final name = contact['full_name']?.toString() ?? 'esta persona';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar persona de confianza'),
        content: Text('¿Deseas eliminar a $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteEmergencyContact(id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: 'No pudimos eliminar esta persona de confianza.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Personas de confianza'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _contacts.length >= 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Agregar'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  const AppSectionHeader(
                    title: 'Personas de confianza',
                    subtitle:
                        'Puedes registrar hasta tres personas para apoyarte en situaciones de seguridad o emergencia.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null)
                    AppSurfaceCard(
                      backgroundColor: AppColors.coralSoft,
                      borderColor: AppColors.tint(AppColors.danger, 0.28),
                      child: Text(_error!),
                    )
                  else if (_contacts.isEmpty)
                    const AppEmptyState(
                      icon: Icons.contact_emergency_outlined,
                      title: 'Agrega una persona de confianza',
                      message:
                          'Registra a alguien a quien podamos incluir en tus opciones de seguridad.',
                    )
                  else
                    ..._contacts.map((contact) {
                      final active = contact['is_active'] == true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppSurfaceCard(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.tint(
                                      AppColors.primary,
                                      0.12,
                                    ),
                                    foregroundColor: AppColors.primary,
                                    child: Text(
                                      '${contact['priority'] ?? '-'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          contact['full_name']?.toString() ??
                                              'Persona de confianza',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          contact['relationship']?.toString() ??
                                              'Persona de confianza',
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppStatusPill(
                                    label: active ? 'Guardado' : 'Inactivo',
                                    color: active
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppInfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Teléfono',
                                value:
                                    '${contact['country_calling_code'] ?? ''} '
                                    '${contact['phone_number'] ?? ''}',
                              ),
                              if ((contact['email']?.toString() ?? '')
                                  .isNotEmpty)
                                AppInfoRow(
                                  icon: Icons.email_outlined,
                                  label: 'Correo',
                                  value: contact['email'].toString(),
                                ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _openForm(contact),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Editar'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _delete(contact),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.danger,
                                    ),
                                    label: const Text(
                                      'Eliminar',
                                      style: TextStyle(color: AppColors.danger),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

class _EmergencyContactDialog extends StatefulWidget {
  const _EmergencyContactDialog({this.contact});

  final Map<String, dynamic>? contact;

  @override
  State<_EmergencyContactDialog> createState() =>
      _EmergencyContactDialogState();
}

class _EmergencyContactDialogState extends State<_EmergencyContactDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _relationship;
  late final TextEditingController _callingCode;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late int _priority;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _name = TextEditingController(text: contact?['full_name']?.toString());
    _relationship = TextEditingController(
      text: contact?['relationship']?.toString(),
    );
    _callingCode = TextEditingController(
      text: contact?['country_calling_code']?.toString() ?? '+57',
    );
    _phone = TextEditingController(text: contact?['phone_number']?.toString());
    _email = TextEditingController(text: contact?['email']?.toString());
    _priority = int.tryParse(contact?['priority']?.toString() ?? '1') ?? 1;
    _active = contact?['is_active'] != false;
  }

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _callingCode.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'full_name': _name.text.trim(),
      'relationship': _relationship.text.trim(),
      'country_calling_code': _callingCode.text.trim(),
      'phone_number': _phone.text.trim(),
      'email': _email.text.trim(),
      'priority': _priority,
      'is_active': _active,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.contact == null
            ? 'Agregar persona de confianza'
            : 'Editar persona de confianza',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  validator: _required,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _relationship,
                  validator: _required,
                  decoration: const InputDecoration(
                    labelText: 'Relación o parentesco',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: TextFormField(
                        controller: _callingCode,
                        validator: _required,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Indicativo',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phone,
                        validator: _required,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Celular'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo opcional',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Prioridad'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 · Principal')),
                    DropdownMenuItem(value: 2, child: Text('2 · Secundaria')),
                    DropdownMenuItem(value: 3, child: Text('3 · Adicional')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _priority = value);
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  title: const Text('Incluir en mis opciones de seguridad'),
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
