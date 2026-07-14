import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/service_display.dart';
import '../../location/data/location_search_service.dart';
import '../../location/presentation/pick_location_page.dart';
import '../data/category_service.dart';
import '../data/service_request_query_service.dart';
import '../data/service_request_service.dart';
import 'request_detail_page.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = ServiceRequestService();
  final _queryService = ServiceRequestQueryService();
  final _categoryService = CategoryService();
  final _locationTextCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _mapController = MapController();
  final _locationSearchService = LocationSearchService(
    rules: LocationRules.defaultBogota(),
  );

  List<CategoryItem> _categories = const [];
  int? _selectedCategoryId;
  bool _loadingCategories = false;

  LatLng _location = const LatLng(4.6767, -74.0482);
  LocationPlace? _selectedPlace;
  List<LocationPlace> _locationResults = const [];
  bool _searchingLocation = false;
  String? _locationError;
  Timer? _debounce;
  bool _suppressLocationListener = false;

  bool _needNow = true;
  late DateTime _startTime;
  int _durationMinutes = 60;
  final _durationOptions = const [30, 60, 90, 120, 150, 180];

  String? _preferredGender;
  _AgeRange? _selectedAgeRange;
  final _ageRanges = const [
    _AgeRange(18, 25),
    _AgeRange(25, 30),
    _AgeRange(30, 35),
    _AgeRange(35, 40),
    _AgeRange(40, 45),
    _AgeRange(45, 50),
    _AgeRange(50, 55),
    _AgeRange(55, 60),
    _AgeRange(60, 65),
  ];

  bool _loading = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now().add(const Duration(minutes: 5));
    _locationTextCtrl.addListener(_onLocationTextChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locationTextCtrl.removeListener(_onLocationTextChanged);
    _locationTextCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final items = await _categoryService.listCategories();
      if (!mounted) return;
      setState(() {
        _categories = items;
        _selectedCategoryId ??= items.isEmpty ? null : items.first.id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _result = 'No fue posible cargar las categorías.');
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  CategoryItem? get _selectedCategory {
    for (final category in _categories) {
      if (category.id == _selectedCategoryId) return category;
    }
    return null;
  }

  double get _estimatedPrice {
    final category = _selectedCategory;
    if (category == null) return 0;
    return category.basePricePerHour * _durationMinutes / 60;
  }

  void _onLocationTextChanged() {
    if (_suppressLocationListener) return;
    _selectedPlace = null;
    final query = _locationTextCtrl.text.trim();
    _debounce?.cancel();
    if (query.length < 3) {
      setState(() {
        _locationResults = const [];
        _locationError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchLocation(query);
    });
  }

  Future<void> _searchLocation(String query) async {
    setState(() {
      _searchingLocation = true;
      _locationError = null;
    });
    try {
      final results = await _locationSearchService.search(query, limit: 10);
      if (!mounted) return;
      final allowed = results.where((item) => item.isAllowed).toList();
      setState(() {
        _locationResults = allowed;
        _locationError = allowed.isEmpty
            ? 'No encontramos un punto público permitido. Busca un parque, '
                  'café, centro comercial, biblioteca o restaurante.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationResults = const [];
        _locationError = 'No fue posible buscar el lugar. Intenta nuevamente.';
      });
    } finally {
      if (mounted) setState(() => _searchingLocation = false);
    }
  }

  void _applyPlace(LocationPlace place) {
    _debounce?.cancel();
    _suppressLocationListener = true;
    setState(() {
      _selectedPlace = place;
      _location = LatLng(place.lat, place.lng);
      _locationTextCtrl.text = place.displayName;
      _locationResults = const [];
      _locationError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(_location, 16);
      } catch (_) {
        // El mapa puede no estar listo durante el primer frame.
      }
    });
    Future<void>.delayed(Duration.zero, () {
      _suppressLocationListener = false;
    });
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute<PickedLocation>(
        builder: (_) => PickLocationPage(initialPosition: _location),
      ),
    );
    if (result == null || !mounted) return;

    final name = result.name?.trim();
    _suppressLocationListener = true;
    setState(() {
      _location = result.point;
      _selectedPlace = null;
      if (name != null && name.isNotEmpty) {
        _locationTextCtrl.text = name;
      }
      _locationResults = const [];
      _locationError = null;
    });
    Future<void>.delayed(Duration.zero, () {
      _suppressLocationListener = false;
    });
  }

  Future<void> _pickStartDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
      initialDate: _startTime.isBefore(now) ? now : _startTime,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null) return;
    setState(() {
      _needNow = false;
      _startTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      setState(() => _result = 'Selecciona una categoría.');
      return;
    }
    if (_locationTextCtrl.text.trim().isEmpty) {
      setState(() => _result = 'Selecciona un punto de encuentro.');
      return;
    }

    final effectiveStart = _needNow
        ? DateTime.now().add(const Duration(minutes: 5))
        : _startTime;

    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final response = await _service.createRequest(
        categoryId: _selectedCategoryId!,
        locationText: _locationTextCtrl.text.trim(),
        locationLat: double.parse(_location.latitude.toStringAsFixed(6)),
        locationLng: double.parse(_location.longitude.toStringAsFixed(6)),
        requestedStartTime: effectiveStart,
        requestedDurationMinutes: _durationMinutes,
        notes: _notesCtrl.text.trim(),
        preferredGender: _preferredGender,
        preferredAgeMin: _selectedAgeRange?.min,
        preferredAgeMax: _selectedAgeRange?.max,
      );
      var created = Map<String, dynamic>.from(response.data as Map);
      if (created['id'] == null) {
        created = await _queryService.getActiveRequest() ?? created;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RequestDetailPage(request: created),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _result = error.response?.data is Map
            ? (error.response?.data['detail']?.toString() ??
                  'No fue posible crear la solicitud.')
            : 'No fue posible crear la solicitud.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _categoryIcon(CategoryItem category) {
    final value = category.name.toLowerCase();
    if (value.contains('méd') || value.contains('salud'))
      return Icons.local_hospital_outlined;
    if (value.contains('compra') || value.contains('merc'))
      return Icons.shopping_bag_outlined;
    if (value.contains('trámite') || value.contains('dilig'))
      return Icons.assignment_outlined;
    if (value.contains('estudio') || value.contains('clase'))
      return Icons.menu_book_outlined;
    if (value.contains('deporte') || value.contains('caminar'))
      return Icons.directions_walk_outlined;
    if (value.contains('comida') ||
        value.contains('café') ||
        value.contains('rest'))
      return Icons.restaurant_outlined;
    return Icons.people_alt_outlined;
  }

  String _categoryHint(CategoryItem category) {
    final value = category.name.toLowerCase();
    if (value.contains('méd') || value.contains('salud')) {
      return 'Ideal para citas, controles o acompañamiento a centros de salud.';
    }
    if (value.contains('compra') || value.contains('merc')) {
      return 'Para compras, vueltas rápidas o apoyo en recorridos cortos.';
    }
    if (value.contains('trámite') || value.contains('dilig')) {
      return 'Para bancos, notarías, oficinas y gestiones personales.';
    }
    if (value.contains('estudio') || value.contains('clase')) {
      return 'Para estudiar, practicar o asistir a actividades académicas.';
    }
    return category.description.isNotEmpty
        ? category.description
        : 'Selecciona esta opción si es la que mejor se parece a tu necesidad.';
  }

  Widget _categoryField() {
    if (_loadingCategories) return const LinearProgressIndicator();
    final selected = _selectedCategory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '1. ¿Qué acompañamiento necesitas?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Toca una tarjeta para indicar la actividad principal.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _categories.map((category) {
            final selectedCard = category.id == _selectedCategoryId;
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 52) / 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _selectedCategoryId = category.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selectedCard
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.9)
                        : Theme.of(context).colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selectedCard
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: selectedCard ? 1.8 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: selectedCard
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surface,
                        child: Icon(
                          _categoryIcon(category),
                          color: selectedCard
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _categoryHint(category),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (selected != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _categoryIcon(selected),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harás una solicitud de ${selected.name.toLowerCase()}.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(_categoryHint(selected)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _locationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '2. Elige un punto de encuentro público',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border.all(color: Colors.amber.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Por seguridad, la primera reunión debe ser en un lugar abierto al público.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(Icons.park_outlined, size: 18),
                    label: Text('Parques'),
                  ),
                  Chip(
                    avatar: Icon(Icons.local_cafe_outlined, size: 18),
                    label: Text('Cafés'),
                  ),
                  Chip(
                    avatar: Icon(Icons.restaurant_outlined, size: 18),
                    label: Text('Restaurantes'),
                  ),
                  Chip(
                    avatar: Icon(Icons.local_library_outlined, size: 18),
                    label: Text('Bibliotecas'),
                  ),
                  Chip(
                    avatar: Icon(Icons.store_mall_directory_outlined, size: 18),
                    label: Text('Centros comerciales'),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text('No permitidos en la primera reunión:'),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(Icons.house_outlined, size: 18),
                    label: Text('Viviendas'),
                  ),
                  Chip(
                    avatar: Icon(Icons.apartment_outlined, size: 18),
                    label: Text('Apartamentos'),
                  ),
                  Chip(
                    avatar: Icon(Icons.hotel_outlined, size: 18),
                    label: Text('Hoteles'),
                  ),
                  Chip(
                    avatar: Icon(Icons.king_bed_outlined, size: 18),
                    label: Text('Habitaciones'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _locationTextCtrl,
          decoration: InputDecoration(
            labelText: 'Punto de encuentro',
            hintText: 'Ej. Parque de la 93',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchingLocation
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          validator: (value) => (value ?? '').trim().isEmpty
              ? 'El punto de encuentro es obligatorio'
              : null,
        ),
        if (_locationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _locationError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_locationResults.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: Column(
              children: _locationResults
                  .map(
                    (place) => ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.place_outlined),
                      ),
                      title: Text(place.title),
                      subtitle: Text(
                        place.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Chip(
                        avatar: Icon(Icons.verified, size: 16),
                        label: Text('Permitido'),
                      ),
                      onTap: () => _applyPlace(place),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (_locationTextCtrl.text.trim().isNotEmpty &&
            _locationResults.isEmpty &&
            _locationError == null)
          Card(
            margin: const EdgeInsets.only(top: 8),
            color: Colors.green.shade50,
            child: ListTile(
              leading: Icon(Icons.verified, color: Colors.green.shade700),
              title: const Text('Punto de encuentro seleccionado'),
              subtitle: Text(_locationTextCtrl.text.trim()),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _location, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'opentic.co.yalecaigo',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _location,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_pin,
                        size: 44,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickOnMap,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Elegir en el mapa'),
        ),
      ],
    );
  }

  Widget _scheduleField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _needNow,
              title: const Text('Lo necesito ahora'),
              subtitle: const Text('Se programará desde la hora actual.'),
              onChanged: (value) {
                setState(() {
                  _needNow = value;
                  if (value) {
                    _startTime = DateTime.now().add(const Duration(minutes: 5));
                  }
                });
              },
            ),
            if (!_needNow)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: const Text('Fecha y hora programada'),
                subtitle: Text(formatDateTime(_startTime.toIso8601String())),
                trailing: const Icon(Icons.edit),
                onTap: _pickStartDateTime,
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('Inicio estimado'),
                subtitle: Text(formatDateTime(_startTime.toIso8601String())),
              ),
          ],
        ),
      ),
    );
  }

  Widget _preferencesField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preferencias opcionales',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Toca una opción. Puedes dejar “Cualquiera”.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text('Género', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Cualquiera'),
                  selected: _preferredGender == null,
                  onSelected: (_) => setState(() => _preferredGender = null),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.woman_2_outlined, size: 18),
                  label: const Text('Mujer'),
                  selected: _preferredGender == 'F',
                  onSelected: (_) => setState(() => _preferredGender = 'F'),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.man_2_outlined, size: 18),
                  label: const Text('Hombre'),
                  selected: _preferredGender == 'M',
                  onSelected: (_) => setState(() => _preferredGender = 'M'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Edad', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.all_inclusive, size: 18),
                  label: const Text('Cualquiera'),
                  selected: _selectedAgeRange == null,
                  onSelected: (_) => setState(() => _selectedAgeRange = null),
                ),
                ..._ageRanges.map(
                  (range) => ChoiceChip(
                    label: Text('${range.min}-${range.max}'),
                    selected: _selectedAgeRange == range,
                    onSelected: (_) =>
                        setState(() => _selectedAgeRange = range),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear solicitud')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Cuéntanos qué necesitas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _categoryField(),
            const SizedBox(height: 16),
            _locationField(),
            const SizedBox(height: 16),
            const Text(
              '3. ¿Cuándo y por cuánto tiempo?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _scheduleField(),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey(_durationMinutes),
              initialValue: _durationMinutes,
              decoration: const InputDecoration(
                labelText: 'Duración estimada',
                border: OutlineInputBorder(),
              ),
              items: _durationOptions
                  .map(
                    (minutes) => DropdownMenuItem<int>(
                      value: minutes,
                      child: Text('$minutes minutos'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _durationMinutes = value);
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Valor estimado'),
                subtitle: const Text(
                  'El pago demo se confirma en el siguiente paso.',
                ),
                trailing: Text(
                  formatCop(_estimatedPrice),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _preferencesField(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Indicaciones adicionales (opcional)',
                hintText: 'Ej. Nos encontramos en la entrada principal.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: const Icon(Icons.arrow_forward),
              label: Text(_loading ? 'Creando…' : 'Continuar al pago demo'),
            ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _result!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AgeRange {
  const _AgeRange(this.min, this.max);

  final int min;
  final int max;

  @override
  bool operator ==(Object other) {
    return other is _AgeRange && other.min == min && other.max == max;
  }

  @override
  int get hashCode => Object.hash(min, max);
}
