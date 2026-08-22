import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/app_components.dart';
import '../data/account_service.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.providerMode});

  final bool providerMode;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final AccountService _service = AccountService();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _country = TextEditingController(
    text: 'Colombia',
  );
  final TextEditingController _biography = TextEditingController();
  final TextEditingController _experience = TextEditingController();
  final TextEditingController _yearsExperience = TextEditingController();
  final Set<String> _selectedLanguages = <String>{'es'};

  List<String> _countries = const ['Colombia', 'Estados Unidos', 'Canadá'];
  List<String> _cityOptions = const [];
  bool _hasExperience = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _gender = '';
  DateTime? _birthDate;
  XFile? _photo;
  String? _remotePhoto;
  String _providerReviewStatus = '';
  String _providerReviewReason = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _city.dispose();
    _country.dispose();
    _biography.dispose();
    _experience.dispose();
    _yearsExperience.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _service.getProfile();
      final profile = _map(response['profile']);
      if (!mounted) return;
      setState(() {
        _firstName.text = profile['first_name']?.toString() ?? '';
        _lastName.text = profile['last_name']?.toString() ?? '';
        _city.text = profile['city']?.toString() ?? '';
        final loadedCountry = profile['country']?.toString() ?? 'Colombia';
        _country.text = _countries.contains(loadedCountry)
            ? loadedCountry
            : 'Colombia';
        _gender = profile['gender']?.toString() ?? '';
        _remotePhoto = profile['profile_photo']?.toString();
        _biography.text = profile['biography']?.toString() ?? '';
        _hasExperience = profile['has_experience'] == true;
        _experience.text = profile['experience_summary']?.toString() ?? '';
        _yearsExperience.text = profile['years_experience']?.toString() ?? '';
        final languages = profile['spoken_languages'];
        _selectedLanguages
          ..clear()
          ..addAll(_normalizeLanguageValues(languages));
        if (_selectedLanguages.isEmpty) {
          _selectedLanguages.add('es');
        }
        _providerReviewStatus =
            profile['provider_review_status']?.toString() ?? '';
        _providerReviewReason =
            profile['provider_review_reason']?.toString() ?? '';
        final birth = profile['birth_date']?.toString();
        _birthDate = birth == null ? null : DateTime.tryParse(birth);
      });
      await _loadLocationOptions();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible cargar el perfil.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLocationOptions({String query = ''}) async {
    try {
      final response = await _service.getLocationOptions(
        country: _country.text,
        query: query,
      );
      final rawCountries = response['countries'];
      final rawCities = response['cities'];
      if (!mounted) return;
      setState(() {
        if (rawCountries is List) {
          final names = rawCountries
              .whereType<Map>()
              .map((item) => item['name']?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList();
          if (names.isNotEmpty) _countries = names;
        }
        _cityOptions = rawCities is List
            ? rawCities
                  .map((item) => item.toString().trim())
                  .where((item) => item.isNotEmpty)
                  .toList()
            : const [];
      });
    } catch (_) {
      // The form remains usable with free city text and the three local countries.
    }
  }

  Future<void> _changeCountry(String value) async {
    setState(() {
      _country.text = value;
      _city.clear();
      _cityOptions = const [];
    });
    await _loadLocationOptions();
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _selectBirthDate() async {
    final today = DateTime.now();
    final lastDate = DateTime(today.year - 18, today.month, today.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900, 1, 1),
      lastDate: lastDate,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecciona tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (selected != null && mounted) {
      setState(() => _birthDate = selected);
    }
  }

  Future<void> _selectPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar fotografía'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (file != null && mounted) setState(() => _photo = file);
  }

  Set<String> _normalizeLanguageValues(Object? values) {
    Object? current = values;
    for (var attempt = 0; attempt < 3 && current is String; attempt++) {
      final text = current.trim();
      if (text.isEmpty) {
        current = const <Object>[];
        break;
      }
      try {
        final decoded = jsonDecode(text);
        if (decoded == current) break;
        current = decoded;
      } on FormatException {
        current = text
            .replaceAll(';', ',')
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
        break;
      }
    }

    final source = current is List
        ? current
        : current == null
        ? const <Object>[]
        : <Object>[current];
    final normalized = <String>{};
    for (final item in source) {
      final value = item.toString().trim().toLowerCase();
      if (value == 'es' ||
          value == 'español' ||
          value == 'espanol' ||
          value == 'spanish' ||
          value == 'castellano') {
        normalized.add('es');
      } else if (value == 'en' ||
          value == 'inglés' ||
          value == 'ingles' ||
          value == 'english') {
        normalized.add('en');
      }
    }
    return normalized;
  }

  void _toggleLanguage(String code, bool selected) {
    setState(() {
      if (selected) {
        _selectedLanguages.add(code);
      } else {
        _selectedLanguages.remove(code);
      }
    });
  }

  String? _validateYearsExperience(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final years = int.tryParse(text);
    if (years == null) return 'Ingresa un número válido';
    if (years < 0 || years > 80) {
      return 'Ingresa un valor entre 0 y 80';
    }
    return null;
  }

  Map<String, dynamic> _profileValues() {
    final values = <String, dynamic>{
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'birth_date': _formatDate(_birthDate!),
      'gender': _gender,
      'city': _city.text.trim(),
      'country': _country.text.trim(),
      'preferred_language': 'es',
    };
    if (widget.providerMode) {
      final languages = _selectedLanguages.toList()..sort();
      values.addAll({
        'biography': _biography.text.trim(),
        'has_experience': _hasExperience,
        'experience_summary': _hasExperience ? _experience.text.trim() : '',
        'years_experience':
            !_hasExperience || _yearsExperience.text.trim().isEmpty
            ? null
            : int.parse(_yearsExperience.text.trim()),
        'spoken_languages': languages,
      });
    }
    return values;
  }

  String _reviewStatusLabel(String value) {
    switch (value.toUpperCase()) {
      case 'VERIFIED':
        return 'Aprobado';
      case 'IN_REVIEW':
        return 'En revisión';
      case 'REJECTED':
        return 'Rechazado';
      case 'REQUIRES_UPDATE':
        return 'Requiere actualización';
      case 'SUSPENDED':
        return 'Suspendido';
      case 'PENDING':
        return 'Pendiente';
      default:
        return value.isEmpty ? 'Sin enviar' : value;
    }
  }

  String _submitReviewError(Object error) {
    if (error is DioException && error.response?.data is Map) {
      final data = Map<String, dynamic>.from(error.response!.data as Map);
      final rawLabels = data['missing_field_labels'];
      if (rawLabels is List && rawLabels.isNotEmpty) {
        final labels = rawLabels
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        if (labels.isNotEmpty) {
          return 'Completa antes de enviar: ${labels.join(', ')}.';
        }
      }
    }
    return apiErrorMessage(
      error,
      fallback: 'No pudimos enviar tu información.',
    );
  }

  Future<bool> _persistProfile({bool showSuccess = true}) async {
    if (!_formKey.currentState!.validate()) return false;
    if (_birthDate == null) {
      setState(() => _error = 'Selecciona tu fecha de nacimiento.');
      return false;
    }
    if (widget.providerMode && _selectedLanguages.isEmpty) {
      setState(() => _error = 'Selecciona al menos un idioma.');
      return false;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final values = _profileValues();
      dynamic payload = values;
      if (_photo != null) {
        final multipartValues = Map<String, dynamic>.from(values);
        if (multipartValues['spoken_languages'] is List) {
          multipartValues['spoken_languages'] = jsonEncode(
            multipartValues['spoken_languages'],
          );
        }
        multipartValues['profile_photo'] = await MultipartFile.fromFile(
          _photo!.path,
          filename: _photo!.name,
        );
        payload = FormData.fromMap(multipartValues);
      }

      final response = await _service.updateProfile(payload);
      final profile = _map(response['profile']);
      final newReviewStatus =
          profile['provider_review_status']?.toString() ?? '';
      await _load();
      if (!mounted) return false;
      if (showSuccess) {
        final changedReview =
            widget.providerMode &&
            newReviewStatus.toUpperCase() == 'REQUIRES_UPDATE';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              changedReview
                  ? 'Perfil guardado.'
                  : 'Perfil actualizado correctamente.',
            ),
          ),
        );
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible guardar el perfil.',
        );
      });
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    await _persistProfile();
  }

  Future<void> _submitForReview() async {
    final saved = await _persistProfile(showSuccess: false);
    if (!saved || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.submitProviderProfile();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Información enviada. Te avisaremos cuando esté lista.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = _submitReviewError(error);
      setState(() => _error = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _photoPreview() {
    final child = _photo != null
        ? Image.file(File(_photo!.path), fit: BoxFit.cover)
        : (_remotePhoto ?? '').isNotEmpty
        ? Image.network(
            _remotePhoto!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.person_outline,
              size: 48,
              color: AppColors.primary,
            ),
          )
        : const Icon(Icons.person_outline, size: 48, color: AppColors.primary);
    return Container(
      width: 108,
      height: 108,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Editar perfil'),
        actions: [
          IconButton(
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
                    title: 'Información personal',
                    subtitle:
                        'Los datos completos permiten validar tu perfil y aplicar correctamente los filtros de edad y género.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(child: _photoPreview()),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: TextButton.icon(
                      onPressed: _selectPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Cambiar fotografía'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _firstName,
                    validator: _required,
                    decoration: const InputDecoration(labelText: 'Nombres'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastName,
                    validator: _required,
                    decoration: const InputDecoration(labelText: 'Apellidos'),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _selectBirthDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de nacimiento',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                        helperText: 'Selecciona primero el año.',
                      ),
                      child: Text(
                        _birthDate == null
                            ? 'Seleccionar fecha'
                            : _formatDate(_birthDate!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _gender.isEmpty ? null : _gender,
                    decoration: const InputDecoration(labelText: 'Sexo'),
                    items: const [
                      DropdownMenuItem(value: 'M', child: Text('Masculino')),
                      DropdownMenuItem(value: 'F', child: Text('Femenino')),
                      DropdownMenuItem(value: 'NB', child: Text('No binario')),
                      DropdownMenuItem(value: 'O', child: Text('Otro')),
                    ],
                    validator: (value) => value == null || value.isEmpty
                        ? 'Selecciona tu sexo'
                        : null,
                    onChanged: (value) => setState(() => _gender = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<String>(
                    key: ValueKey('country-${_country.text}'),
                    initialValue: TextEditingValue(text: _country.text),
                    optionsBuilder: (textValue) {
                      final query = textValue.text.trim().toLowerCase();
                      if (query.isEmpty) return _countries;
                      return _countries.where(
                        (country) => country.toLowerCase().contains(query),
                      );
                    },
                    onSelected: _changeCountry,
                    fieldViewBuilder:
                        (
                          context,
                          fieldController,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          return TextFormField(
                            controller: fieldController,
                            focusNode: focusNode,
                            validator: (value) {
                              final required = _required(value);
                              if (required != null) return required;
                              if (!_countries.contains(value?.trim())) {
                                return 'Selecciona Colombia, Estados Unidos o Canadá';
                              }
                              return null;
                            },
                            onChanged: (value) => _country.text = value,
                            onFieldSubmitted: (_) => onFieldSubmitted(),
                            decoration: const InputDecoration(
                              labelText: 'País',
                              hintText: 'Escribe para ver opciones',
                              prefixIcon: Icon(Icons.public_rounded),
                            ),
                          );
                        },
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<String>(
                    key: ValueKey('${_country.text}-${_city.text}'),
                    initialValue: TextEditingValue(text: _city.text),
                    optionsBuilder: (textValue) {
                      final query = textValue.text.trim().toLowerCase();
                      if (query.isEmpty) return _cityOptions;
                      return _cityOptions.where(
                        (city) => city.toLowerCase().contains(query),
                      );
                    },
                    onSelected: (value) => _city.text = value,
                    fieldViewBuilder:
                        (
                          context,
                          fieldController,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          return TextFormField(
                            controller: fieldController,
                            focusNode: focusNode,
                            validator: _required,
                            onChanged: (value) => _city.text = value,
                            onFieldSubmitted: (_) => onFieldSubmitted(),
                            decoration: const InputDecoration(
                              labelText: 'Ciudad',
                              hintText: 'Escribe para ver sugerencias',
                              prefixIcon: Icon(Icons.location_city_rounded),
                            ),
                          );
                        },
                  ),
                  if (widget.providerMode) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const AppSectionHeader(
                      title: 'Perfil de acompañante',
                      subtitle:
                          'Completa esta información para empezar a acompañar.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _biography,
                      validator: (value) => (value ?? '').trim().length < 20
                          ? 'Escribe al menos 20 caracteres'
                          : null,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Descripción pública',
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSurfaceCard(
                      padding: EdgeInsets.zero,
                      child: SwitchListTile.adaptive(
                        value: _hasExperience,
                        title: const Text(
                          'Tengo experiencia previa',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          'Es opcional. GoWith permite iniciar sin experiencia previa.',
                        ),
                        onChanged: (value) => setState(() {
                          _hasExperience = value;
                          if (!value) {
                            _experience.clear();
                            _yearsExperience.clear();
                          }
                        }),
                      ),
                    ),
                    if (_hasExperience) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _experience,
                        validator: (value) => (value ?? '').trim().length < 20
                            ? 'Escribe al menos 20 caracteres'
                            : null,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Describe tu experiencia',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _yearsExperience,
                        keyboardType: TextInputType.number,
                        validator: _validateYearsExperience,
                        decoration: const InputDecoration(
                          labelText: 'Años de experiencia (opcional)',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppSurfaceCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Idiomas',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Selecciona uno o varios. No necesitas escribir códigos ni JSON.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              FilterChip(
                                avatar: const Text('🇨🇴'),
                                label: const Text('Español'),
                                selected: _selectedLanguages.contains('es'),
                                onSelected: (value) =>
                                    _toggleLanguage('es', value),
                              ),
                              FilterChip(
                                avatar: const Text('🇺🇸'),
                                label: const Text('English'),
                                selected: _selectedLanguages.contains('en'),
                                onSelected: (value) =>
                                    _toggleLanguage('en', value),
                              ),
                            ],
                          ),
                          if (_selectedLanguages.isEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Selecciona al menos un idioma.',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppSurfaceCard(
                      backgroundColor: AppColors.tint(
                        AppColors.information,
                        0.08,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado: '
                            '${_reviewStatusLabel(_providerReviewStatus)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (_providerReviewReason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(_providerReviewReason),
                          ],
                        ],
                      ),
                    ),
                  ],
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
                    label: const Text('Guardar perfil'),
                  ),
                  if (widget.providerMode) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _submitForReview,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Enviar información'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}
