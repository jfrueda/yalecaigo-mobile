import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../account/data/account_service.dart';
import '../../../core/navigation/role_gate_page.dart';

class ProviderEnablementPage extends StatefulWidget {
  const ProviderEnablementPage({super.key});

  @override
  State<ProviderEnablementPage> createState() => _ProviderEnablementPageState();
}

class _ProviderEnablementPageState extends State<ProviderEnablementPage> {
  final AccountService _service = AccountService();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _biography = TextEditingController();
  final TextEditingController _contactName = TextEditingController();
  final TextEditingController _contactRelationship = TextEditingController();
  final TextEditingController _contactCallingCode = TextEditingController(
    text: '+57',
  );
  final TextEditingController _contactPhone = TextEditingController();
  final TextEditingController _contactEmail = TextEditingController();
  final TextEditingController _documentNumber = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _success;
  Map<String, dynamic> _me = const {};
  Map<String, dynamic>? _contact;
  Map<String, dynamic>? _identity;
  List<Map<String, dynamic>> _categories = const [];
  final Set<int> _selectedCategories = <int>{};
  final Set<int> _selectedSubcategories = <int>{};
  final Set<String> _languages = <String>{'es'};

  String _documentType = 'CC';
  String _documentCountry = 'CO';
  XFile? _front;
  XFile? _back;
  XFile? _selfie;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _biography,
      _contactName,
      _contactRelationship,
      _contactCallingCode,
      _contactPhone,
      _contactEmail,
      _documentNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getProfile(),
        _service.listEmergencyContacts(),
        _service.getProviderCapabilities(),
        _service.getIdentityVerification(),
        _service.getModes(),
      ]);
      final me = Map<String, dynamic>.from(results[0] as Map);
      final contacts = results[1] as List<Map<String, dynamic>>;
      final capabilities = Map<String, dynamic>.from(results[2] as Map);
      final identity = Map<String, dynamic>.from(results[3] as Map);
      final modes = Map<String, dynamic>.from(results[4] as Map);
      final profile = _asMap(me['profile']);
      final providerStatus = modes['provider_status']?.toString().toUpperCase();

      if (!mounted) return;
      _biography.text = profile['biography']?.toString() ?? '';
      final languageValues = profile['spoken_languages'];
      if (languageValues is List && languageValues.isNotEmpty) {
        _languages
          ..clear()
          ..addAll(languageValues.map((item) => item.toString().toLowerCase()));
      }
      _documentCountry =
          (profile['residence_country_code']?.toString().isNotEmpty ?? false)
          ? profile['residence_country_code'].toString()
          : 'CO';

      final firstContact = contacts.isEmpty ? null : contacts.first;
      if (firstContact != null) {
        _contactName.text = firstContact['full_name']?.toString() ?? '';
        _contactRelationship.text =
            firstContact['relationship']?.toString() ?? '';
        _contactCallingCode.text =
            firstContact['country_calling_code']?.toString() ?? '+57';
        _contactPhone.text = firstContact['phone_number']?.toString() ?? '';
        _contactEmail.text = firstContact['email']?.toString() ?? '';
      }

      final available = capabilities['available_categories'];
      final caps = capabilities['capabilities'];
      _selectedCategories.clear();
      _selectedSubcategories.clear();
      if (caps is List) {
        for (final raw in caps.whereType<Map>()) {
          if (raw['is_selected'] == true) {
            final id = int.tryParse(raw['category_id']?.toString() ?? '');
            if (id != null) _selectedCategories.add(id);
            final selected = raw['selected_subcategory_ids'];
            if (selected is List) {
              _selectedSubcategories.addAll(
                selected
                    .map((item) => int.tryParse(item.toString()))
                    .whereType<int>(),
              );
            }
          }
        }
      }

      setState(() {
        _me = me;
        _contact = firstContact;
        _categories = available is List
            ? available
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : const [];
        _identity = identity['current'] is Map
            ? Map<String, dynamic>.from(identity['current'] as Map)
            : null;
        if (providerStatus == 'IN_REVIEW') {
          _success =
              'Recibimos tu información. Te avisaremos cuando puedas comenzar a acompañar.';
        } else if (providerStatus == 'ACTIVE') {
          _success = 'Tu perfil está listo para acompañar.';
        }
      });
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _error = 'No pudimos cargar tu información. Intenta nuevamente.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;

  String _providerErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final missing = data['missing_field_labels'];
      if (missing is List && missing.isNotEmpty) {
        final labels = missing
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        if (labels.isNotEmpty) {
          return 'Para enviar tu perfil completa: ${labels.join(', ')}.';
        }
      }

      const labels = <String, String>{
        'biography': 'Descripción',
        'spoken_languages': 'Idiomas',
        'profile_photo': 'Foto de perfil',
        'emergency_contact': 'Persona de confianza',
        'activities': 'Actividades',
        'document_number': 'Número de documento',
        'document_front_image': 'Documento frontal',
        'document_back_image': 'Documento posterior',
        'selfie_image': 'Selfie',
      };
      final fieldErrors = <String>[];
      for (final entry in data.entries) {
        final key = entry.key.toString();
        if ({
          'detail',
          'missing_fields',
          'missing_field_labels',
          'missing_details',
          'next_action',
        }.contains(key)) {
          continue;
        }
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          fieldErrors.add('${labels[key] ?? key}: ${value.first}');
        } else if (value != null && value.toString().trim().isNotEmpty) {
          fieldErrors.add('${labels[key] ?? key}: $value');
        }
      }
      if (fieldErrors.isNotEmpty) {
        return 'Revisa:\n• ${fieldErrors.join('\n• ')}';
      }

      final detail = data['detail'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
    }
    return 'No pudimos guardar tu información. Revisa los campos e intenta nuevamente.';
  }

  bool get _identityNeedsUpload {
    if (_identity == null) return true;
    final status = _identity!['status']?.toString().toUpperCase();
    return {'REJECTED', 'REQUIRES_UPDATE', 'EXPIRED'}.contains(status);
  }

  Future<XFile?> _pickImage(String title) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return _picker.pickImage(source: source, imageQuality: 88, maxWidth: 1800);
  }

  void _toggleCategory(Map<String, dynamic> category, bool selected) {
    final categoryId = int.tryParse(category['id']?.toString() ?? '');
    if (categoryId == null) return;
    final subcategories = category['subcategories'];
    final ids = subcategories is List
        ? subcategories
              .whereType<Map>()
              .map((item) => int.tryParse(item['id']?.toString() ?? ''))
              .whereType<int>()
              .toSet()
        : <int>{};
    setState(() {
      if (selected) {
        _selectedCategories.add(categoryId);
        _selectedSubcategories.addAll(ids);
      } else {
        _selectedCategories.remove(categoryId);
        _selectedSubcategories.removeAll(ids);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_languages.isEmpty) {
      setState(() => _error = 'Selecciona al menos un idioma.');
      return;
    }
    if (_selectedCategories.isEmpty || _selectedSubcategories.isEmpty) {
      setState(() => _error = 'Selecciona al menos una actividad.');
      return;
    }
    if (_identityNeedsUpload &&
        (_front == null ||
            _selfie == null ||
            (_documentType != 'PASSPORT' && _back == null))) {
      setState(
        () => _error =
            'Agrega las imágenes necesarias para comprobar tu identidad.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.updateProfile({
        'biography': _biography.text.trim(),
        'spoken_languages': _languages.toList(),
        'has_experience': false,
      });

      final contactData = {
        'full_name': _contactName.text.trim(),
        'relationship': _contactRelationship.text.trim(),
        'country_calling_code': _contactCallingCode.text.trim(),
        'phone_number': _contactPhone.text.trim(),
        'email': _contactEmail.text.trim(),
        'priority': 1,
        'is_active': true,
      };
      final contactId = int.tryParse(_contact?['id']?.toString() ?? '');
      if (contactId == null) {
        await _service.createEmergencyContact(contactData);
      } else {
        await _service.updateEmergencyContact(contactId, contactData);
      }

      await _service.updateProviderCapabilities(
        categoryIds: _selectedCategories.toList(),
        subcategoryIds: _selectedSubcategories.toList(),
      );

      if (_identityNeedsUpload) {
        final form = FormData.fromMap({
          'document_type': _documentType,
          'document_country': _documentCountry,
          'document_number': _documentNumber.text.trim(),
          'document_front_image': await MultipartFile.fromFile(
            _front!.path,
            filename: _front!.name,
          ),
          if (_back != null)
            'document_back_image': await MultipartFile.fromFile(
              _back!.path,
              filename: _back!.name,
            ),
          'selfie_image': await MultipartFile.fromFile(
            _selfie!.path,
            filename: _selfie!.name,
          ),
          'use_selfie_as_profile_photo': true,
        });
        await _service.submitIdentity(form, resubmission: _identity != null);
      }

      await _service.submitProviderProfile();
      if (!mounted) return;
      setState(() {
        _success =
            'Recibimos tu información. Te avisaremos cuando puedas comenzar a acompañar.';
      });
      await _load();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _providerErrorMessage(error));
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _error = 'No pudimos guardar tu información. Intenta nuevamente.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _useClientMode() async {
    await _service.setActiveMode('client');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RoleGatePage()),
      (_) => false,
    );
  }

  Widget _imagePickerCard({
    required String title,
    required String hint,
    required XFile? file,
    required ValueChanged<XFile?> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(hint),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () async => onChanged(await _pickImage(title)),
              icon: Icon(
                file == null
                    ? Icons.add_a_photo_outlined
                    : Icons.check_circle_outline,
              ),
              label: Text(file == null ? 'Seleccionar' : file.name),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_success != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiero acompañar')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _success!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _useClientMode,
                    child: const Text('Seguir usando GoWith para solicitar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final displayName = _me['display_name']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Quiero acompañar')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Completa tu perfil',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                displayName.isEmpty
                    ? 'Necesitamos esta información para cuidar a quienes usan GoWith.'
                    : '$displayName, necesitamos esta información para cuidar a quienes usan GoWith.',
              ),
              const SizedBox(height: 22),
              Text('Sobre ti', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextFormField(
                controller: _biography,
                minLines: 3,
                maxLines: 5,
                validator: (value) => (value ?? '').trim().length < 20
                    ? 'Cuéntanos un poco más sobre ti.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Cuéntales a las personas cómo es acompañarte.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    selected: _languages.contains('es'),
                    label: const Text('Español'),
                    onSelected: (value) => setState(
                      () => value
                          ? _languages.add('es')
                          : _languages.remove('es'),
                    ),
                  ),
                  FilterChip(
                    selected: _languages.contains('en'),
                    label: const Text('English'),
                    onSelected: (value) => setState(
                      () => value
                          ? _languages.add('en')
                          : _languages.remove('en'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                'Persona de confianza',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'La tendremos disponible para situaciones de seguridad o emergencia.',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactName,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactRelationship,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'Relación',
                  hintText: 'Ej. hermano, amiga, pareja',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 95,
                    child: TextFormField(
                      controller: _contactCallingCode,
                      validator: _required,
                      decoration: const InputDecoration(
                        labelText: 'Indicativo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _contactPhone,
                      validator: _required,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Celular',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Actividades',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Seleccionamos algunas opciones comunes. Puedes cambiarlas ahora o después.',
              ),
              const SizedBox(height: 10),
              ..._categories.map((category) {
                final categoryId = int.tryParse(
                  category['id']?.toString() ?? '',
                );
                final selected =
                    categoryId != null &&
                    _selectedCategories.contains(categoryId);
                final subs = category['subcategories'] is List
                    ? (category['subcategories'] as List)
                          .whereType<Map>()
                          .toList()
                    : <Map>[];
                return Card(
                  child: ExpansionTile(
                    leading: Checkbox(
                      value: selected,
                      onChanged: (value) =>
                          _toggleCategory(category, value ?? false),
                    ),
                    title: Text(category['name']?.toString() ?? 'Actividad'),
                    children: subs.map((sub) {
                      final subId = int.tryParse(sub['id']?.toString() ?? '');
                      final checked =
                          subId != null &&
                          _selectedSubcategories.contains(subId);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(sub['name']?.toString() ?? ''),
                        onChanged: selected && subId != null
                            ? (value) => setState(() {
                                if (value == true) {
                                  _selectedSubcategories.add(subId);
                                } else {
                                  _selectedSubcategories.remove(subId);
                                }
                              })
                            : null,
                      );
                    }).toList(),
                  ),
                );
              }),
              const SizedBox(height: 26),
              Text(
                'Comprueba tu identidad',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              if (!_identityNeedsUpload)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Documentos recibidos'),
                    subtitle: Text('No necesitas volver a cargarlos.'),
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _documentType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de documento',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'CC',
                      child: Text('Cédula de ciudadanía'),
                    ),
                    DropdownMenuItem(
                      value: 'CE',
                      child: Text('Cédula de extranjería'),
                    ),
                    DropdownMenuItem(
                      value: 'PASSPORT',
                      child: Text('Pasaporte'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _documentType = value ?? 'CC'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _documentNumber,
                  validator: _identityNeedsUpload ? _required : null,
                  decoration: const InputDecoration(
                    labelText: 'Número de documento',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                _imagePickerCard(
                  title: 'Frente del documento',
                  hint: 'Toma una imagen completa y legible.',
                  file: _front,
                  onChanged: (value) => setState(() => _front = value),
                ),
                if (_documentType != 'PASSPORT')
                  _imagePickerCard(
                    title: 'Reverso del documento',
                    hint: 'Toma una imagen completa y legible.',
                    file: _back,
                    onChanged: (value) => setState(() => _back = value),
                  ),
                _imagePickerCard(
                  title: 'Selfie',
                  hint: 'Esta foto también se usará como tu foto de perfil.',
                  file: _selfie,
                  onChanged: (value) => setState(() => _selfie = value),
                ),
              ],
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.send_rounded),
                label: Text(_saving ? 'Guardando...' : 'Enviar mi información'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _saving ? null : _useClientMode,
                child: const Text('Lo haré después'),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
