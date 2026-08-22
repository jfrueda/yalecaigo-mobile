import 'package:flutter/material.dart';

import '../../onboarding/presentation/registration_welcome_page.dart';
import '../data/auth_service.dart';
import 'auth_error.dart';
import 'email_verification_page.dart';
import 'geo_selection.dart';

class SocialCompleteRegistrationPage extends StatefulWidget {
  const SocialCompleteRegistrationPage({
    super.key,
    required this.registrationToken,
    required this.provider,
    required this.profile,
  });

  final String registrationToken;
  final String provider;
  final Map<String, dynamic> profile;

  @override
  State<SocialCompleteRegistrationPage> createState() =>
      _SocialCompleteRegistrationPageState();
}

class _SocialCompleteRegistrationPageState
    extends State<SocialCompleteRegistrationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();
  final TextEditingController _phone = TextEditingController();
  late final TextEditingController _email;
  late final TextEditingController _first;
  late final TextEditingController _last;

  DateTime? _birthDate;
  String? _gender;
  bool _loading = true;
  bool _submitting = false;
  bool _acceptedLegal = false;
  String? _error;

  List<Map<String, dynamic>> _countries = const [];
  List<Map<String, dynamic>> _regions = const [];
  List<Map<String, dynamic>> _municipalities = const [];
  List<Map<String, dynamic>> _legalDocuments = const [];
  String? _countryCode;
  int? _regionId;
  int? _municipalityId;
  int _countryLoadGeneration = 0;
  int _regionLoadGeneration = 0;

  Map<String, dynamic>? get _country =>
      GeoSelection.countryByCode(_countries, _countryCode);
  Map<String, dynamic>? get _region =>
      GeoSelection.placeById(_regions, _regionId);
  Map<String, dynamic>? get _municipality =>
      GeoSelection.placeById(_municipalities, _municipalityId);

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: widget.profile['email']?.toString() ?? '',
    );
    _first = TextEditingController(
      text: widget.profile['first_name']?.toString() ?? '',
    );
    _last = TextEditingController(
      text: widget.profile['last_name']?.toString() ?? '',
    );
    _loadCatalogs();
  }

  @override
  void dispose() {
    _email.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _loadCatalogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final countries = await _auth.getRegistrationCountries();
      if (countries.isEmpty) {
        throw const FormatException('No hay países disponibles para registro.');
      }
      final preferred = countries.firstWhere(
        (item) => item['code']?.toString() == 'CO',
        orElse: () => countries.first,
      );
      if (!mounted) return;
      final uniqueCountries = GeoSelection.uniqueCountries(countries);
      final preferredCode = preferred['code']?.toString();
      setState(() {
        _countries = uniqueCountries;
        _countryCode = GeoSelection.validCountryCode(
          uniqueCountries,
          preferredCode,
        );
      });
      final selectedCountry = _country;
      if (selectedCountry == null) {
        throw const FormatException(
          'No fue posible seleccionar el país de registro.',
        );
      }
      await _loadCountryData(selectedCountry);
    } catch (error) {
      if (mounted) setState(() => _error = readableAuthError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCountryData(Map<String, dynamic> country) async {
    final code = country['code']?.toString() ?? 'CO';
    final generation = ++_countryLoadGeneration;
    ++_regionLoadGeneration;
    final values = await Future.wait([
      _auth.getRegistrationPlaces(countryCode: code, level: 'ADMIN1'),
      _auth.getLegalDocuments(countryCode: code),
    ]);
    if (!mounted ||
        generation != _countryLoadGeneration ||
        _countryCode != code) {
      return;
    }
    setState(() {
      _regions = GeoSelection.uniquePlaces(values[0]);
      _legalDocuments = values[1];
      _regionId = null;
      _municipalityId = null;
      _municipalities = const [];
      _acceptedLegal = false;
    });
  }

  Future<void> _selectRegion(int? regionId) async {
    final generation = ++_regionLoadGeneration;
    setState(() {
      _regionId = GeoSelection.validPlaceId(_regions, regionId);
      _municipalityId = null;
      _municipalities = const [];
    });
    final region = _region;
    final country = _country;
    if (region == null || country == null) return;
    try {
      final values = await _auth.getRegistrationPlaces(
        countryCode: country['code'].toString(),
        level: 'MUNICIPALITY',
        parentId: _regionId,
      );
      if (!mounted ||
          generation != _regionLoadGeneration ||
          _regionId != regionId) {
        return;
      }
      final uniqueMunicipalities = GeoSelection.uniquePlaces(values);
      setState(() {
        _municipalities = uniqueMunicipalities;
        _municipalityId = GeoSelection.validPlaceId(
          uniqueMunicipalities,
          _municipalityId,
        );
      });
    } catch (error) {
      if (mounted && generation == _regionLoadGeneration) {
        setState(() => _error = readableAuthError(error));
      }
    }
  }

  Future<void> _selectBirthDate(FormFieldState<DateTime> fieldState) async {
    final today = DateTime.now();
    final lastDate = DateTime(today.year - 18, today.month, today.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900, 1, 1),
      lastDate: lastDate,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (selected != null && mounted) {
      setState(() => _birthDate = selected);
      fieldState.didChange(selected);
    }
  }

  void _showLegalDocuments() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documentos vigentes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ..._legalDocuments.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(item['name']?.toString() ?? 'Documento'),
                  subtitle: Text('Versión ${item['version'] ?? '-'}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final pending = <String>[
      if (_birthDate == null) 'fecha de nacimiento',
      if (_gender == null) 'sexo',
      if (_country == null) 'país',
      if (_municipality == null) 'ciudad o municipio',
    ];
    if (pending.isNotEmpty) {
      setState(
        () => _error = 'Para continuar completa: ${pending.join(', ')}.',
      );
      return;
    }
    if (!_acceptedLegal || _legalDocuments.isEmpty) {
      setState(() => _error = 'Revisa y acepta los documentos para continuar.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final callingCode = _country!['calling_code']?.toString() ?? '';
      final rawPhone = _phone.text.trim();
      final phone = rawPhone.startsWith('+')
          ? rawPhone
          : '$callingCode$rawPhone';
      await _auth.completeSocialRegistration(
        registrationToken: widget.registrationToken,
        email: _email.text,
        phoneNumber: phone,
        firstName: _first.text,
        lastName: _last.text,
        birthDate: _formatDate(_birthDate!),
        gender: _gender!,
        countryCode: _country!['code'].toString(),
        residencePlaceId: int.parse(_municipality!['id'].toString()),
        legalDocumentIds: _legalDocuments
            .map((item) => int.tryParse(item['id']?.toString() ?? ''))
            .whereType<int>()
            .toList(),
      );
      if (!mounted) return;
      final verified = widget.profile['email_verified'] == true;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => verified
              ? const RegistrationWelcomePage()
              : const EmailVerificationPage(),
        ),
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = readableAuthError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Completar cuenta con ${widget.provider}')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Completa tus datos',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Esta misma cuenta te servirá para solicitar y, si quieres, acompañar.',
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _first,
                            validator: _required,
                            decoration: const InputDecoration(
                              labelText: 'Nombres',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _last,
                            validator: _required,
                            decoration: const InputDecoration(
                              labelText: 'Apellidos',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FormField<DateTime>(
                            validator: (_) => _birthDate == null
                                ? 'Selecciona tu fecha de nacimiento'
                                : null,
                            builder: (fieldState) => InkWell(
                              onTap: _submitting
                                  ? null
                                  : () => _selectBirthDate(fieldState),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Fecha de nacimiento',
                                  border: const OutlineInputBorder(),
                                  errorText: fieldState.errorText,
                                  suffixIcon: const Icon(Icons.calendar_month),
                                ),
                                child: Text(
                                  _birthDate == null
                                      ? 'Seleccionar fecha'
                                      : _formatDate(_birthDate!),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Sexo',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'M',
                                child: Text('Masculino'),
                              ),
                              DropdownMenuItem(
                                value: 'F',
                                child: Text('Femenino'),
                              ),
                              DropdownMenuItem(
                                value: 'NB',
                                child: Text('No binario'),
                              ),
                              DropdownMenuItem(value: 'O', child: Text('Otro')),
                            ],
                            onChanged: _submitting
                                ? null
                                : (value) => setState(() => _gender = value),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Selecciona tu sexo'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            validator: _required,
                            enabled: widget.profile['email_verified'] != true,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone,
                            validator: _required,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Celular',
                              prefixText: '${_country?['calling_code'] ?? ''} ',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            key: ValueKey('country-${_countryCode ?? 'none'}'),
                            initialValue: GeoSelection.validCountryCode(
                              _countries,
                              _countryCode,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'País',
                              border: OutlineInputBorder(),
                            ),
                            items: _countries
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item['code'].toString(),
                                    child: Text(item['name']?.toString() ?? ''),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (code) async {
                                    if (code == null) return;
                                    final country = GeoSelection.countryByCode(
                                      _countries,
                                      code,
                                    );
                                    if (country == null) return;
                                    setState(() {
                                      _countryCode = code;
                                      _regionId = null;
                                      _municipalityId = null;
                                      _municipalities = const [];
                                    });
                                    await _loadCountryData(country);
                                  },
                            validator: (value) => value == null || value.isEmpty
                                ? 'Selecciona un país'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: ValueKey(
                              'region-${_countryCode ?? 'none'}-${_regionId ?? 'none'}',
                            ),
                            initialValue: GeoSelection.validPlaceId(
                              _regions,
                              _regionId,
                            ),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Departamento / región',
                              border: OutlineInputBorder(),
                            ),
                            items: _regions
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: int.parse(item['id'].toString()),
                                    child: Text(item['name']?.toString() ?? ''),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting ? null : _selectRegion,
                            validator: (value) =>
                                value == null ? 'Selecciona una región' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: ValueKey(
                              'municipality-${_regionId ?? 'none'}-${_municipalityId ?? 'none'}',
                            ),
                            initialValue: GeoSelection.validPlaceId(
                              _municipalities,
                              _municipalityId,
                            ),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ciudad / municipio',
                              border: OutlineInputBorder(),
                            ),
                            items: _municipalities
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: int.parse(item['id'].toString()),
                                    child: Text(item['name']?.toString() ?? ''),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (value) => setState(
                                    () => _municipalityId =
                                        GeoSelection.validPlaceId(
                                          _municipalities,
                                          value,
                                        ),
                                  ),
                            validator: (value) => value == null
                                ? 'Selecciona tu ciudad o municipio'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _acceptedLegal,
                            onChanged: _submitting
                                ? null
                                : (value) => setState(
                                    () => _acceptedLegal = value ?? false,
                                  ),
                            title: const Text(
                              'Acepto los Términos, la Política de privacidad y el tratamiento de mis datos.',
                            ),
                            subtitle: TextButton(
                              onPressed: _legalDocuments.isEmpty
                                  ? null
                                  : _showLegalDocuments,
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Ver documentos'),
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Continuar'),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
