import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../location/data/location_search_service.dart';
import '../../location/presentation/pick_location_page.dart';
import '../data/category_service.dart';
import '../data/service_request_service.dart';
import '../data/service_request_query_service.dart';
import 'request_detail_page.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();

  // Servicios
  final _service = ServiceRequestService();
  final _queryService = ServiceRequestQueryService();
  final _categoryService = CategoryService();

  // Categorías
  List<CategoryItem> _categories = [];
  bool _loadingCategories = false;
  int? _selectedCategoryId;

  // Ubicación
  final _locationTextCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  LatLng _location = const LatLng(4.6767, -74.0482);

  final MapController _mapController = MapController();

  final _locationSearchService = LocationSearchService(
    rules: LocationRules.defaultBogota(),
  );

  List<LocationPlace> _locationResults = [];
  bool _searchingLocation = false;
  String? _locationHintError;
  Timer? _debounce;

  // ✅ NUEVO: evita que al seleccionar una sugerencia se dispare otra búsqueda
  bool _suppressLocationListener = false;

  // Fecha/hora
  DateTime? _startTime;

  // Duración (min 30, max 180)
  final List<int> _durationOptions = const [30, 60, 90, 120, 150, 180];
  int _durationMinutes = 60;

  // Preferencias
  String? _preferredGender; // null / 'M' / 'F'
  final List<_AgeRange> _ageRanges = _buildAgeRanges();
  _AgeRange? _selectedAgeRange;

  // Notas
  final _notesCtrl = TextEditingController();

  // UI state
  bool _loading = false;
  String? _result;

  // Valor estimado (placeholder MVP)
  static const int _pricePerMinuteCop = 500; // ~30.000/hora

  @override
  void initState() {
    super.initState();
    _preferredGender = _normalizeGender(_preferredGender);
    _loadCategories();

    // init lat/lng text
    _latCtrl.text = _fmtCoord(_location.latitude);
    _lngCtrl.text = _fmtCoord(_location.longitude);

    _locationTextCtrl.addListener(_onLocationTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locationTextCtrl.removeListener(_onLocationTextChanged);
    _locationTextCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // -----------------------------
  // Helpers
  // -----------------------------
  static List<_AgeRange> _buildAgeRanges() {
    final ranges = <_AgeRange>[];
    ranges.add(const _AgeRange(18, 25));
    for (int start = 25; start <= 60; start += 5) {
      ranges.add(_AgeRange(start, start + 5));
    }
    return ranges;
  }

  String? _normalizeGender(String? v) {
    if (v == null) return null;
    if (v == 'M' || v == 'F') return v;
    return null;
  }

  void _setGender(String? code) {
    setState(() => _preferredGender = _normalizeGender(code));
  }

  int _estimatedPriceCop() => _durationMinutes * _pricePerMinuteCop;

  String _formatCop(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write('.');
    }
    return buf.toString();
  }

  String _fmtCoord(double v) {
    // Evita error backend "no more than 9 digits in total"
    // 6 decimales suele ser suficiente para GPS y no exagera longitud.
    return v.toStringAsFixed(6);
  }

  void _moveMapSafe(LatLng target, double zoom) {
    // ✅ en flutter_map a veces el controller aún no está listo en el mismo frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(target, zoom);
      } catch (_) {
        // no-op MVP
      }
    });
  }

  Future<void> _pickStartDateTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 15))),
    );
    if (time == null) return;

    setState(() {
      _startTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final items = await _categoryService.listCategories();
      if (!mounted) return;
      setState(() {
        _categories = items;
        _selectedCategoryId ??= items.isNotEmpty ? items.first.id : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = [];
        _selectedCategoryId ??= 1; // fallback
      });
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  String _categoryLabel() {
    final id = _selectedCategoryId;
    if (id == null) return 'Sin categoría';
    final match = _categories.where((c) => c.id == id).toList();
    if (match.isNotEmpty) return match.first.name;
    return 'Categoría #$id';
  }

  // -----------------------------
  // Location autocomplete
  // -----------------------------
  void _onLocationTextChanged() {
    if (_suppressLocationListener) return; // ✅ evita re-búsqueda al seleccionar

    final q = _locationTextCtrl.text.trim();
    _debounce?.cancel();

    if (q.isEmpty) {
      setState(() {
        _locationResults = [];
        _locationHintError = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await _searchLocation(q);
    });
  }

  Future<void> _searchLocation(String q) async {
    setState(() {
      _searchingLocation = true;
      _locationHintError = null;
    });

    try {
      final results = await _locationSearchService.search(q, limit: 8);
      if (!mounted) return;

      // Mostramos sugerencias, pero en el mensaje de error nos basamos en permitidos.
      final allowed = results.where((r) => r.isAllowed).toList();

      setState(() {
        _locationResults = results;
        _locationHintError = allowed.isEmpty
            ? 'No encontramos lugares públicos válidos en la ciudad permitida. '
                  'Prueba con un parque, café o centro comercial.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationResults = [];
        _locationHintError = 'Error buscando ubicación. Intenta de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _searchingLocation = false);
    }
  }

  void _applyPlace(LocationPlace p) {
    // ✅ clave: al setear texto desde código, no queremos disparar otro search
    _debounce?.cancel();
    _suppressLocationListener = true;

    final label = (p.title.isNotEmpty) ? p.title : p.displayName;

    setState(() {
      _locationTextCtrl.text = label;
      _location = LatLng(p.lat, p.lng);
      _latCtrl.text = _fmtCoord(p.lat);
      _lngCtrl.text = _fmtCoord(p.lng);
      _locationResults = [];
      _locationHintError = p.isAllowed
          ? null
          : (p.rejectReason ?? _locationHintError);
    });

    _moveMapSafe(_location, 16);

    // re-habilita listener en el siguiente microtask/frame
    Future.microtask(() {
      if (!mounted) return;
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

    final dLat = result.point.latitude;
    final dLng = result.point.longitude;
    final label = result.name?.trim();

    setState(() {
      _location = LatLng(dLat, dLng);
      _latCtrl.text = _fmtCoord(dLat);
      _lngCtrl.text = _fmtCoord(dLng);
      if (label != null && label.isNotEmpty) {
        _suppressLocationListener = true;
        _locationTextCtrl.text = label;
      }
      _locationResults = [];
      _locationHintError = null;
    });

    if (label != null && label.isNotEmpty) {
      Future.microtask(() {
        if (mounted) _suppressLocationListener = false;
      });
    }

    _moveMapSafe(_location, 16);
  }

  // -----------------------------
  // Create request
  // -----------------------------
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null) {
      setState(() => _result = '❌ Selecciona fecha y hora de inicio');
      return;
    }

    final categoryId = _selectedCategoryId ?? 1;
    final locationText = _locationTextCtrl.text.trim();
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      setState(() => _result = '❌ Lat/Lng inválidas');
      return;
    }

    final preferredAgeMin = _selectedAgeRange?.min;
    final preferredAgeMax = _selectedAgeRange?.max;

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final latValue = double.parse(_fmtCoord(lat));
      final lngValue = double.parse(_fmtCoord(lng));

      final res = await _service.createRequest(
        categoryId: categoryId,
        locationText: locationText,
        locationLat: latValue,
        locationLng: lngValue,
        requestedStartTime: _startTime!.toUtc(),
        requestedDurationMinutes: _durationMinutes,
        notes: _notesCtrl.text.trim(),
        preferredGender: _preferredGender,
        preferredAgeMin: preferredAgeMin,
        preferredAgeMax: preferredAgeMax,
      );

      final created = Map<String, dynamic>.from(res.data ?? {});

      // Estado inmediato en UI
      created['status'] ??= 'pending';

      // Datos inmediatos (si backend tarda en refrescar)
      created['category'] ??= categoryId;
      created['location_text'] ??= locationText;
      created['location_lat'] ??= lat;
      created['location_lng'] ??= lng;
      created['requested_duration_minutes'] ??= _durationMinutes;
      created['requested_start_time'] ??= _startTime!.toUtc().toIso8601String();

      created['preferred_gender'] ??= _preferredGender;
      created['preferred_age_min'] ??= preferredAgeMin;
      created['preferred_age_max'] ??= preferredAgeMax;

      // Valor estimado MVP (solo UI)
      created['calculated_price'] ??= _estimatedPriceCop();

      // id puede no venir
      final id = created['id'];
      if (id == null) {
        final active = await _queryService.getActiveRequest();
        if (!mounted) return;

        if (active != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => RequestDetailPage(request: active),
            ),
          );
          return;
        }

        setState(
          () => _result = '❌ No tengo ID válido de solicitud. Revisa backend.',
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RequestDetailPage(request: created)),
      );
    } catch (e) {
      String msg = '❌ Error creando solicitud: $e';
      if (e is DioException) {
        msg = '❌ Error (${e.response?.statusCode}): ${e.response?.data}';
      }
      if (mounted) setState(() => _result = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -----------------------------
  // UI Blocks
  // -----------------------------
  Widget _categorySelector() {
    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_categories.isNotEmpty) {
      return DropdownButtonFormField<int>(
        initialValue: _selectedCategoryId,
        decoration: const InputDecoration(
          labelText: 'Categoría',
          border: OutlineInputBorder(),
        ),
        items: _categories
            .map(
              (c) => DropdownMenuItem<int>(
                value: c.id,
                child: Text('${c.name} (ID: ${c.id})'),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _selectedCategoryId = v),
      );
    }

    // Fallback si no hay endpoint / no cargó: input ID + label
    return TextFormField(
      initialValue: (_selectedCategoryId ?? 1).toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Categoría (ID)',
        helperText: 'Nombre: ${_categoryLabel()}',
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        final t = (v ?? '').trim();
        final id = int.tryParse(t);
        if (id == null || id <= 0) return 'ID inválido';
        return null;
      },
      onChanged: (v) {
        final id = int.tryParse(v.trim());
        setState(() => _selectedCategoryId = id);
      },
    );
  }

  Widget _durationSelector() {
    return DropdownButtonFormField<int>(
      initialValue: _durationMinutes,
      decoration: const InputDecoration(
        labelText: 'Duración (minutos)',
        border: OutlineInputBorder(),
        helperText: 'Mínimo 30 min, máximo 3 horas',
      ),
      items: _durationOptions
          .map(
            (m) => DropdownMenuItem<int>(value: m, child: Text('$m minutos')),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _durationMinutes = v);
      },
    );
  }

  Widget _priceCard() {
    final price = _estimatedPriceCop();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Valor estimado',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${_formatCop(price)} COP'),
          ],
        ),
      ),
    );
  }

  Widget _genderChecks() {
    final isM = _preferredGender == 'M';
    final isF = _preferredGender == 'F';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preferencias',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sin preferencia'),
              value: _preferredGender == null,
              onChanged: (v) {
                if (v == true) _setGender(null);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Masculino'),
              value: isM,
              onChanged: (v) {
                if (v == true) {
                  _setGender('M');
                } else {
                  _setGender(null);
                }
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Femenino'),
              value: isF,
              onChanged: (v) {
                if (v == true) {
                  _setGender('F');
                } else {
                  _setGender(null);
                }
              },
            ),
            const Divider(height: 24),
            DropdownButtonFormField<_AgeRange?>(
              initialValue: _selectedAgeRange,
              decoration: const InputDecoration(
                labelText: 'Rango de edad (opcional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<_AgeRange?>(
                  value: null,
                  child: Text('Sin preferencia'),
                ),
                ..._ageRanges.map(
                  (r) => DropdownMenuItem<_AgeRange?>(
                    value: r,
                    child: Text('${r.min} a ${r.max}'),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedAgeRange = v),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nota: si no defines preferencias, la app buscará el mejor match disponible.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapPreview() {
    final marker = Marker(
      point: _location,
      width: 40,
      height: 40,
      child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mapa', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _location,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'co.opentic.yalecaigo',
                    ),
                    MarkerLayer(markers: [marker]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Latitud',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final d = double.tryParse((v ?? '').trim());
                      if (d == null) return 'Latitud inválida';
                      return null;
                    },
                    onChanged: (v) {
                      final d = double.tryParse(v.trim());
                      if (d == null) return;
                      setState(
                        () => _location = LatLng(d, _location.longitude),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Longitud',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final d = double.tryParse((v ?? '').trim());
                      if (d == null) return 'Longitud inválida';
                      return null;
                    },
                    onChanged: (v) {
                      final d = double.tryParse(v.trim());
                      if (d == null) return;
                      setState(() => _location = LatLng(_location.latitude, d));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickOnMap,
              icon: const Icon(Icons.map),
              label: const Text('Elegir en el mapa'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Solo puntos públicos (parques, cafés, centros comerciales). '
              'No hoteles ni residencias. Debe estar dentro de la ciudad permitida.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationSuggestions() {
    if (_locationTextCtrl.text.trim().isEmpty) return const SizedBox.shrink();

    final hint = _locationHintError;
    final results = _locationResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searchingLocation)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(hint, style: const TextStyle(color: Colors.red)),
          ),
        if (results.isNotEmpty)
          Card(
            child: Column(
              children: results.map<Widget>((LocationPlace r) {
                final subtitle = r.displayName;
                final allowed = r.isAllowed;

                return ListTile(
                  dense: true,
                  title: Text(r.title),
                  subtitle: Text(
                    allowed ? subtitle : '$subtitle\n${r.rejectReason ?? ''}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: allowed
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.block, color: Colors.redAccent),

                  // ✅ SOLO PERMITE TAP SI ES ALLOWED
                  onTap: allowed ? () => _applyPlace(r) : null,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // -----------------------------
  // Build
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final categoryName = _categoryLabel();

    return Scaffold(
      appBar: AppBar(title: const Text('Crear solicitud')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _categorySelector(),
              const SizedBox(height: 8),
              Text(
                'Nombre categoría: $categoryName',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationTextCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ubicación (texto)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return 'Ubicación requerida';
                  return null;
                },
              ),
              _locationSuggestions(),
              const SizedBox(height: 12),
              _mapPreview(),
              const SizedBox(height: 12),
              _durationSelector(),
              const SizedBox(height: 12),
              _priceCard(),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Fecha/hora inicio',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _startTime == null
                      ? 'Selecciona fecha y hora'
                      : _startTime.toString(),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickStartDateTime,
              ),
              const SizedBox(height: 12),
              _genderChecks(),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear solicitud'),
              ),
              const SizedBox(height: 12),
              if (_result != null)
                Text(
                  _result!,
                  style: TextStyle(
                    color: _result!.startsWith('✅') ? Colors.green : Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgeRange {
  final int min;
  final int max;
  const _AgeRange(this.min, this.max);

  @override
  String toString() => '$min-$max';

  @override
  bool operator ==(Object other) =>
      other is _AgeRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}
