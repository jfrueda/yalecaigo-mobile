import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/app_components.dart';
import '../../location/data/location_search_service.dart';
import '../../location/presentation/pick_location_page.dart';
import '../data/category_service.dart';
import '../data/service_request_query_service.dart';
import '../data/service_request_service.dart';
import 'request_detail_page.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key, this.initialCategoryId});

  final int? initialCategoryId;

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _service = ServiceRequestService();
  final _queryService = ServiceRequestQueryService();
  final _categoryService = CategoryService();
  final _locationTextCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _mapController = MapController();
  final _pageController = PageController();
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
  final _durationOptions = const [30, 60, 90, 120];

  String? _preferredGender;
  _AgeRange? _selectedAgeRange;
  final _ageRanges = const [
    _AgeRange(18, 30, '18–30'),
    _AgeRange(31, 45, '31–45'),
    _AgeRange(46, 60, '46–60'),
    _AgeRange(61, 80, '60+'),
  ];

  int _step = 0;
  bool _loading = false;
  String? _result;

  static const _stepTitles = [
    'Actividad',
    'Punto de encuentro',
    'Fecha y duración',
    'Preferencias',
    'Resumen',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _startTime = DateTime.now().add(const Duration(minutes: 5));
    _locationTextCtrl.addListener(_onLocationTextChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pageController.dispose();
    _locationTextCtrl.removeListener(_onLocationTextChanged);
    _locationTextCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final items = await _categoryService.listCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = items;
        if (_selectedCategoryId == null ||
            !items.any((item) => item.id == _selectedCategoryId)) {
          _selectedCategoryId = items.isEmpty ? null : items.first.id;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _result = 'No fue posible cargar las actividades.');
    } finally {
      if (mounted) {
        setState(() => _loadingCategories = false);
      }
    }
  }

  CategoryItem? get _selectedCategory {
    for (final category in _categories) {
      if (category.id == _selectedCategoryId) {
        return category;
      }
    }
    return null;
  }

  double get _estimatedPrice {
    final category = _selectedCategory;
    if (category == null) {
      return 0;
    }
    return category.basePricePerHour * _durationMinutes / 60;
  }

  void _onLocationTextChanged() {
    if (_suppressLocationListener) {
      return;
    }
    final query = _locationTextCtrl.text.trim();
    _selectedPlace = null;
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
      if (!mounted) {
        return;
      }
      setState(() {
        _locationResults = results;
        _locationError = results.isEmpty
            ? 'No encontramos lugares con ese nombre. Prueba con un parque, café o centro comercial.'
            : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationResults = const [];
        _locationError = 'No fue posible buscar el lugar. Intenta nuevamente.';
      });
    } finally {
      if (mounted) {
        setState(() => _searchingLocation = false);
      }
    }
  }

  void _applyPlace(LocationPlace place) {
    if (!place.isAllowed) {
      setState(() {
        _locationError =
            place.rejectReason ??
            'Este lugar no está permitido para la primera reunión.';
      });
      return;
    }
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
      if (!mounted) {
        return;
      }
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
    if (result == null || !mounted) {
      return;
    }

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
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null) {
      return;
    }
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

  void _selectQuickTime(Duration offset) {
    setState(() {
      _needNow = offset.inMinutes <= 10;
      _startTime = DateTime.now().add(offset);
    });
  }

  bool _validateCurrentStep() {
    setState(() => _result = null);
    switch (_step) {
      case 0:
        if (_selectedCategoryId == null) {
          setState(
            () => _result = 'Selecciona la actividad que vas a realizar.',
          );
          return false;
        }
        return true;
      case 1:
        if (_locationTextCtrl.text.trim().isEmpty) {
          setState(() => _result = 'Selecciona un punto de encuentro público.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateCurrentStep()) {
      return;
    }
    if (_step >= _stepTitles.length - 1) {
      _submit();
      return;
    }
    setState(() => _step += 1);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step -= 1);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    final categoryId = _selectedCategoryId;
    if (categoryId == null || _locationTextCtrl.text.trim().isEmpty) {
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
        categoryId: categoryId,
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
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RequestDetailPage(request: created),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final data = error.response?.data;
      setState(() {
        _result = data is Map
            ? data['detail']?.toString() ?? 'No fue posible crear la solicitud.'
            : 'No fue posible crear la solicitud.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  IconData _categoryIcon(CategoryItem category) {
    final value = category.name.toLowerCase();
    if (value.contains('méd') ||
        value.contains('salud') ||
        value.contains('cita')) {
      return Icons.event_available_outlined;
    }
    if (value.contains('compra') || value.contains('merc')) {
      return Icons.shopping_bag_outlined;
    }
    if (value.contains('trámite') || value.contains('dilig')) {
      return Icons.assignment_outlined;
    }
    if (value.contains('estudio') || value.contains('clase')) {
      return Icons.menu_book_outlined;
    }
    if (value.contains('deporte') ||
        value.contains('caminar') ||
        value.contains('paseo')) {
      return Icons.directions_walk_outlined;
    }
    if (value.contains('comida') ||
        value.contains('café') ||
        value.contains('rest')) {
      return Icons.restaurant_outlined;
    }
    return Icons.people_alt_outlined;
  }

  String _categoryHint(CategoryItem category) {
    final description = category.description.trim();
    if (description.isNotEmpty) {
      return description;
    }
    return 'Acompañamiento presencial para la actividad seleccionada.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(_stepTitles[_step]),
      ),
      body: Column(
        children: [
          _progressHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _activityStep(),
                _locationStep(),
                _scheduleStep(),
                _preferencesStep(),
                _summaryStep(),
              ],
            ),
          ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Text(
                _result!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _progressHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(_stepTitles.length, (index) {
              final active = index <= _step;
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(
                    right: index == _stepTitles.length - 1 ? 0 : AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Paso ${_step + 1} de ${_stepTitles.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        const AppSectionHeader(
          title: '¿Qué vas a hacer?',
          subtitle:
              'Selecciona la actividad que mejor representa lo que necesitas.',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_loadingCategories)
          const Center(child: CircularProgressIndicator())
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - AppSpacing.md) / 2;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: _categories.map((category) {
                  final selected = category.id == _selectedCategoryId;
                  return SizedBox(
                    width: width,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      onTap: () =>
                          setState(() => _selectedCategoryId = category.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        constraints: const BoxConstraints(minHeight: 168),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.tint(AppColors.secondary, 0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.cardRadius,
                          ),
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryMedium
                                : AppColors.border,
                            width: selected ? 1.7 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    _categoryIcon(category),
                                    color: selected
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                ),
                                const Spacer(),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              category.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _categoryHint(category),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _locationStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        const AppSectionHeader(
          title: '¿Dónde se encuentran?',
          subtitle: 'Elige un lugar público, fácil de identificar y seguro.',
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _locationTextCtrl,
          decoration: InputDecoration(
            labelText: 'Buscar lugar',
            hintText: 'Ej. Parque de la 93',
            prefixIcon: const Icon(Icons.search_rounded),
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
          ),
        ),
        if (_locationError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _locationError!,
            style: const TextStyle(color: AppColors.danger),
          ),
        ],
        if (_locationResults.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: _locationResults.map((place) {
                return ListTile(
                  onTap: () => _applyPlace(place),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.tint(
                        place.isAllowed ? AppColors.success : AppColors.danger,
                        0.12,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      place.isAllowed
                          ? Icons.place_outlined
                          : Icons.block_outlined,
                      color: place.isAllowed
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
                  title: Text(place.title),
                  subtitle: Text(
                    place.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: AppStatusPill(
                    label: place.isAllowed ? 'Permitido' : 'No permitido',
                    color: place.isAllowed
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _locationRules(),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 230,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
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
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x33173F4D),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.place_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_locationTextCtrl.text.trim().isNotEmpty)
          AppSurfaceCard(
            backgroundColor: AppColors.tint(AppColors.success, 0.06),
            borderColor: AppColors.tint(AppColors.success, 0.28),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Punto seleccionado',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _selectedPlace?.title ?? _locationTextCtrl.text.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _pickOnMap,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Elegir en el mapa'),
        ),
      ],
    );
  }

  Widget _locationRules() {
    Widget iconChip(IconData icon, String label, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.tint(color, 0.09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Primera reunión en un lugar público',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              iconChip(Icons.park_outlined, 'Parques', AppColors.success),
              iconChip(Icons.local_cafe_outlined, 'Cafés', AppColors.success),
              iconChip(
                Icons.restaurant_outlined,
                'Restaurantes',
                AppColors.success,
              ),
              iconChip(
                Icons.local_library_outlined,
                'Bibliotecas',
                AppColors.success,
              ),
              iconChip(
                Icons.store_mall_directory_outlined,
                'Centros comerciales',
                AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No permitidos', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              iconChip(Icons.house_outlined, 'Viviendas', AppColors.danger),
              iconChip(
                Icons.apartment_outlined,
                'Apartamentos',
                AppColors.danger,
              ),
              iconChip(Icons.hotel_outlined, 'Hoteles', AppColors.danger),
              iconChip(
                Icons.king_bed_outlined,
                'Habitaciones',
                AppColors.danger,
              ),
              iconChip(
                Icons.dark_mode_outlined,
                'Sitios aislados',
                AppColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleStep() {
    final quickOptions = [
      ('Ahora', 'Lo necesito ya', const Duration(minutes: 5)),
      ('En 1 hora', 'Aproximadamente', const Duration(hours: 1)),
      ('Hoy más tarde', 'Dentro de 3 horas', const Duration(hours: 3)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        const AppSectionHeader(
          title: '¿Cuándo lo necesitas?',
          subtitle:
              'Elige una opción rápida o selecciona una fecha específica.',
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - AppSpacing.md) / 2;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                ...quickOptions.map((option) {
                  final selected = option.$1 == 'Ahora'
                      ? _needNow
                      : !_needNow &&
                            (_startTime.difference(DateTime.now()).inMinutes -
                                        option.$3.inMinutes)
                                    .abs() <
                                10;
                  return SizedBox(
                    width: width,
                    child: _quickTimeCard(
                      title: option.$1,
                      subtitle: option.$2,
                      selected: selected,
                      onTap: () => _selectQuickTime(option.$3),
                    ),
                  );
                }),
                SizedBox(
                  width: width,
                  child: _quickTimeCard(
                    title: 'Elegir fecha',
                    subtitle: 'Seleccionar día y hora',
                    selected:
                        !_needNow &&
                        _startTime.difference(DateTime.now()).inHours > 4,
                    onTap: _pickStartDateTime,
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppSectionHeader(
          title: 'Duración aproximada',
          subtitle: 'Puedes ajustar el tiempo antes de confirmar.',
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _durationOptions.map((minutes) {
            final label = minutes == 60
                ? '1 hora'
                : minutes == 120
                ? '2 horas'
                : '$minutes min';
            return AppChoiceChip(
              label: label,
              selected: _durationMinutes == minutes,
              onSelected: (_) => setState(() => _durationMinutes = minutes),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSurfaceCard(
          backgroundColor: AppColors.tint(AppColors.primary, 0.06),
          borderColor: AppColors.tint(AppColors.primary, 0.22),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateTime(_startTime.toIso8601String()),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Duración: $_durationMinutes minutos',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickTimeCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    IconData icon = Icons.schedule_outlined,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: selected
          ? AppColors.tint(AppColors.secondary, 0.13)
          : null,
      borderColor: selected ? AppColors.primaryMedium : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const Spacer(),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _preferencesStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        const AppSectionHeader(
          title: '¿Tienes alguna preferencia?',
          subtitle: 'Este paso es opcional y no garantiza disponibilidad.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Género',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppChoiceChip(
                    icon: Icons.people_outline,
                    label: 'Cualquiera',
                    selected: _preferredGender == null,
                    onSelected: (_) => setState(() => _preferredGender = null),
                  ),
                  AppChoiceChip(
                    icon: Icons.woman_2_outlined,
                    label: 'Mujer',
                    selected: _preferredGender == 'F',
                    onSelected: (_) => setState(() => _preferredGender = 'F'),
                  ),
                  AppChoiceChip(
                    icon: Icons.man_2_outlined,
                    label: 'Hombre',
                    selected: _preferredGender == 'M',
                    onSelected: (_) => setState(() => _preferredGender = 'M'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Edad', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppChoiceChip(
                    icon: Icons.all_inclusive_rounded,
                    label: 'Cualquiera',
                    selected: _selectedAgeRange == null,
                    onSelected: (_) => setState(() => _selectedAgeRange = null),
                  ),
                  ..._ageRanges.map(
                    (range) => AppChoiceChip(
                      label: range.label,
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
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _notesCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Indicación adicional (opcional)',
            hintText: 'Ej. Nos encontramos en la entrada principal.',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppSurfaceCard(
          backgroundColor: AppColors.surfaceSoft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.primary),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Las preferencias ayudan a orientar la búsqueda, pero la disponibilidad y la seguridad tienen prioridad.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryStep() {
    final category = _selectedCategory;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        const AppSectionHeader(
          title: 'Resumen de tu solicitud',
          subtitle: 'Revisa los detalles antes de continuar al pago.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSurfaceCard(
          child: Column(
            children: [
              AppInfoRow(
                icon: category == null
                    ? Icons.people_alt_outlined
                    : _categoryIcon(category),
                label: 'Actividad',
                value: category?.name ?? 'Sin actividad',
              ),
              const Divider(),
              AppInfoRow(
                icon: Icons.place_outlined,
                label: 'Punto de encuentro',
                value: _selectedPlace?.title ?? _locationTextCtrl.text.trim(),
              ),
              const Divider(),
              AppInfoRow(
                icon: Icons.event_available_outlined,
                label: 'Fecha y hora',
                value: formatDateTime(_startTime.toIso8601String()),
              ),
              const Divider(),
              AppInfoRow(
                icon: Icons.timer_outlined,
                label: 'Duración aproximada',
                value: '$_durationMinutes minutos',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSurfaceCard(
          backgroundColor: AppColors.tint(AppColors.secondary, 0.07),
          borderColor: AppColors.tint(AppColors.secondary, 0.25),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
                size: 30,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valor estimado',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      formatCop(_estimatedPrice),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('Comisión de la plataforma incluida.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estás protegido',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: AppSpacing.md),
              _SecurityLine(text: 'Punto público validado'),
              _SecurityLine(text: 'Acompañante verificado'),
              _SecurityLine(text: 'Seguimiento de estados'),
              _SecurityLine(text: 'Pago protegido durante la actividad'),
            ],
          ),
        ),
        if (_notesCtrl.text.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppSurfaceCard(
            child: AppInfoRow(
              icon: Icons.notes_outlined,
              label: 'Indicación adicional',
              value: _notesCtrl.text.trim(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bottomBar() {
    final isLast = _step == _stepTitles.length - 1;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            if (_step > 0) ...[
              SizedBox(
                width: 54,
                height: AppSpacing.buttonHeight,
                child: OutlinedButton(
                  onPressed: _loading ? null : _back,
                  child: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: FilledButton.icon(
                onPressed: _loading ? null : _next,
                icon: Icon(
                  isLast
                      ? Icons.lock_outline_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _loading
                      ? 'Creando solicitud…'
                      : isLast
                      ? 'Confirmar y pagar'
                      : 'Continuar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityLine extends StatelessWidget {
  const _SecurityLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 19,
            color: AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _AgeRange {
  const _AgeRange(this.min, this.max, this.label);

  final int min;
  final int max;
  final String label;

  @override
  bool operator ==(Object other) {
    return other is _AgeRange && other.min == min && other.max == max;
  }

  @override
  int get hashCode => Object.hash(min, max);
}
