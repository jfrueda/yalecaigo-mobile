import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../core/utils/service_display.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/app_components.dart';
import '../data/account_service.dart';

class ProviderCapabilitiesPage extends StatefulWidget {
  const ProviderCapabilitiesPage({super.key, this.service});

  final AccountService? service;

  @override
  State<ProviderCapabilitiesPage> createState() =>
      _ProviderCapabilitiesPageState();
}

class _ProviderCapabilitiesPageState extends State<ProviderCapabilitiesPage> {
  late final AccountService _service;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _successMessage;
  List<Map<String, dynamic>> _categories = const [];
  Map<int, Map<String, dynamic>> _capabilities = const {};
  Set<int> _selectedCategories = <int>{};
  Set<int> _selectedSubcategories = <int>{};
  Set<int> _lastSavedCategories = <int>{};
  Set<int> _lastSavedSubcategories = <int>{};
  bool _isAvailable = false;
  bool _operationallyAvailable = false;
  String _availabilityMessage = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AccountService();
    _searchController.addListener(() {
      final value = _searchController.text.trim().toLowerCase();
      if (value != _searchQuery) {
        setState(() => _searchQuery = value);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int? _intValue(dynamic value) => int.tryParse(value?.toString() ?? '');

  List<Map<String, dynamic>> _subcategoryMaps(Map<String, dynamic> category) {
    final raw = category['subcategories'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  ({
    List<Map<String, dynamic>> categories,
    Map<int, Map<String, dynamic>> capabilities,
    Set<int> categoryIds,
    Set<int> subcategoryIds,
  })
  _parseCapabilityResponse(Map<String, dynamic> data) {
    final categoriesRaw = data['available_categories'];
    final capabilitiesRaw = data['capabilities'];
    final topLevelSubcategoryIds = data['selected_subcategory_ids'];

    final categories = categoriesRaw is List
        ? categoriesRaw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final capabilities = <int, Map<String, dynamic>>{};
    final categoryIds = <int>{};
    final subcategoryIds = <int>{};

    if (capabilitiesRaw is List) {
      for (final item in capabilitiesRaw.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final categoryId = _intValue(map['category_id']);
        if (categoryId == null) continue;
        capabilities[categoryId] = map;
        if (map['is_selected'] == true) categoryIds.add(categoryId);
        final selectedRaw = map['selected_subcategory_ids'];
        if (selectedRaw is List) {
          for (final value in selectedRaw) {
            final id = _intValue(value);
            if (id != null) subcategoryIds.add(id);
          }
        }
      }
    }

    if (topLevelSubcategoryIds is List) {
      for (final value in topLevelSubcategoryIds) {
        final id = _intValue(value);
        if (id != null) subcategoryIds.add(id);
      }
    }

    for (final category in categories) {
      final categoryId = _intValue(category['id']);
      if (categoryId == null) continue;
      final ids = _subcategoryMaps(
        category,
      ).map((item) => _intValue(item['id'])).whereType<int>().toSet();
      if (ids.any(subcategoryIds.contains)) categoryIds.add(categoryId);
    }

    return (
      categories: categories,
      capabilities: capabilities,
      categoryIds: categoryIds,
      subcategoryIds: subcategoryIds,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        _service.getProviderCapabilities(),
        _service.getAvailability(),
      ]);
      final parsed = _parseCapabilityResponse(responses[0]);
      final availabilityData = responses[1];
      if (!mounted) return;
      setState(() {
        _categories = parsed.categories;
        _capabilities = parsed.capabilities;
        _selectedCategories = parsed.categoryIds;
        _selectedSubcategories = parsed.subcategoryIds;
        _lastSavedCategories = Set<int>.from(parsed.categoryIds);
        _lastSavedSubcategories = Set<int>.from(parsed.subcategoryIds);
        _isAvailable = availabilityData['is_available'] == true;
        _operationallyAvailable =
            availabilityData['operationally_available'] == true;
        _availabilityMessage = availabilityData['message']?.toString() ?? '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible cargar las actividades.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _sameSet(Set<int> left, Set<int> right) =>
      left.length == right.length && left.containsAll(right);

  bool get _hasChanges =>
      !_sameSet(_selectedCategories, _lastSavedCategories) ||
      !_sameSet(_selectedSubcategories, _lastSavedSubcategories);

  int get _legacyCategoryCount {
    var count = 0;
    for (final category in _categories) {
      final id = _intValue(category['id']);
      if (id == null || !_selectedCategories.contains(id)) continue;
      if (_subcategoryMaps(category).isEmpty) count++;
    }
    return count;
  }

  int get _selectedActivityCount =>
      _selectedSubcategories.length + _legacyCategoryCount;

  Future<void> _saveActivities() async {
    if (!_hasChanges) {
      setState(() {
        _successMessage = 'No hay cambios pendientes por guardar.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final response = await _service.updateProviderCapabilities(
        categoryIds: _selectedCategories.toList()..sort(),
        subcategoryIds: _selectedSubcategories.toList()..sort(),
      );
      final parsed = _parseCapabilityResponse(response);
      final summary = response['save_summary'];
      final summaryMap = summary is Map
          ? Map<String, dynamic>.from(summary)
          : const <String, dynamic>{};
      final message = summaryMap['message']?.toString().trim();
      if (!mounted) return;
      setState(() {
        _categories = parsed.categories;
        _capabilities = parsed.capabilities;
        _selectedCategories = parsed.categoryIds;
        _selectedSubcategories = parsed.subcategoryIds;
        _lastSavedCategories = Set<int>.from(parsed.categoryIds);
        _lastSavedSubcategories = Set<int>.from(parsed.subcategoryIds);
        _successMessage = message?.isNotEmpty == true
            ? message
            : 'Las actividades fueron guardadas correctamente.';
      });
    } catch (error) {
      if (!mounted) return;
      final message = apiErrorMessage(
        error,
        fallback: 'No fue posible guardar las actividades.',
      );
      setState(() => _error = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAvailability(bool value) async {
    final previous = _isAvailable;
    setState(() => _isAvailable = value);
    try {
      final data = await _service.updateAvailability(value);
      if (!mounted) return;
      setState(() {
        _isAvailable = data['is_available'] == true;
        _operationallyAvailable = data['operationally_available'] == true;
        _availabilityMessage = data['message']?.toString() ?? '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAvailable = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: 'No fue posible cambiar la disponibilidad.',
            ),
          ),
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return AppColors.success;
      case 'REJECTED':
      case 'SUSPENDED':
        return AppColors.danger;
      case 'PENDING':
      case 'IN_REVIEW':
        return AppColors.warning;
      default:
        return AppColors.information;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'Seleccionada';
      case 'REJECTED':
        return 'Requiere corrección';
      case 'SUSPENDED':
        return 'Suspendida';
      case 'PENDING':
        return 'Seleccionada';
      case 'IN_REVIEW':
        return 'Seleccionada';
      case 'SELECTED':
        return 'Seleccionada';
      default:
        return status.isEmpty ? 'Sin solicitar' : status;
    }
  }

  bool _categoryMatchesSearch(
    Map<String, dynamic> category,
    List<Map<String, dynamic>> subcategories,
  ) {
    if (_searchQuery.isEmpty) return true;
    final categoryText = [
      category['name'],
      category['description'],
      category['code'],
    ].whereType<Object>().join(' ').toLowerCase();
    if (categoryText.contains(_searchQuery)) return true;
    return subcategories.any(_subcategoryMatchesSearch);
  }

  bool _subcategoryMatchesSearch(Map<String, dynamic> subcategory) {
    if (_searchQuery.isEmpty) return true;
    final text = [
      subcategory['name'],
      subcategory['description'],
      subcategory['search_keywords'],
      subcategory['code'],
    ].whereType<Object>().join(' ').toLowerCase();
    return text.contains(_searchQuery);
  }

  void _toggleCategory(
    int categoryId,
    List<Map<String, dynamic>> subcategories,
  ) {
    final subcategoryIds = subcategories
        .map((item) => _intValue(item['id']))
        .whereType<int>()
        .toSet();
    setState(() {
      _successMessage = null;
      if (subcategoryIds.isEmpty) {
        if (_selectedCategories.contains(categoryId)) {
          _selectedCategories.remove(categoryId);
        } else {
          _selectedCategories.add(categoryId);
        }
        return;
      }
      final allSelected = subcategoryIds.every(_selectedSubcategories.contains);
      if (allSelected) {
        _selectedSubcategories.removeAll(subcategoryIds);
        _selectedCategories.remove(categoryId);
      } else {
        _selectedSubcategories.addAll(subcategoryIds);
        _selectedCategories.add(categoryId);
      }
    });
  }

  void _toggleSubcategory(int categoryId, int subcategoryId, bool selected) {
    setState(() {
      _successMessage = null;
      if (selected) {
        _selectedSubcategories.add(subcategoryId);
        _selectedCategories.add(categoryId);
      } else {
        _selectedSubcategories.remove(subcategoryId);
        final remainingIds = _subcategoryMaps(
          _categories.firstWhere(
            (item) => _intValue(item['id']) == categoryId,
            orElse: () => const <String, dynamic>{},
          ),
        ).map((item) => _intValue(item['id'])).whereType<int>().toSet();
        if (!remainingIds.any(_selectedSubcategories.contains)) {
          _selectedCategories.remove(categoryId);
        }
      }
    });
  }

  Widget _categoryCard(Map<String, dynamic> category) {
    final categoryId = _intValue(category['id']);
    if (categoryId == null) return const SizedBox.shrink();
    final allSubcategories = _subcategoryMaps(category);
    if (!_categoryMatchesSearch(category, allSubcategories)) {
      return const SizedBox.shrink();
    }
    final visibleSubcategories = _searchQuery.isEmpty
        ? allSubcategories
        : allSubcategories.where(_subcategoryMatchesSearch).toList();
    final allIds = allSubcategories
        .map((item) => _intValue(item['id']))
        .whereType<int>()
        .toSet();
    final selectedInCategory = allIds
        .where(_selectedSubcategories.contains)
        .length;
    final capability = _capabilities[categoryId];
    final status = capability?['status']?.toString() ?? '';
    final notes = capability?['review_notes']?.toString().trim() ?? '';
    final isLegacyCategory = allSubcategories.isEmpty;
    final legacySelected = _selectedCategories.contains(categoryId);

    if (isLegacyCategory) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AppSurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: legacySelected,
                title: Text(
                  category['name']?.toString() ?? 'Actividad',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Categoría heredada sin actividades específicas configuradas.',
                ),
                onChanged: (_) => _toggleCategory(categoryId, allSubcategories),
              ),
              if (capability != null) ...[
                const Divider(),
                AppStatusPill(
                  label: _statusLabel(status),
                  color: _statusColor(status),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppSurfaceCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          initiallyExpanded: _searchQuery.isNotEmpty || selectedInCategory > 0,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          title: Text(
            category['name']?.toString() ?? 'Categoría',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '$selectedInCategory de ${allIds.length} actividades seleccionadas',
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppStatusPill(
                    label: _statusLabel(status),
                    color: _statusColor(status),
                  ),
                  if (capability?['is_active'] == true)
                    const AppStatusPill(
                      label: 'Operativa',
                      color: AppColors.success,
                      icon: Icons.check_circle_outline,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              tristate: true,
              value: selectedInCategory == 0
                  ? false
                  : selectedInCategory == allIds.length
                  ? true
                  : null,
              title: const Text(
                'Seleccionar todas las actividades',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onChanged: (_) => _toggleCategory(categoryId, allSubcategories),
            ),
            if (notes.isNotEmpty) ...[
              AppSurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                backgroundColor: AppColors.tint(AppColors.warning, 0.10),
                borderColor: AppColors.tint(AppColors.warning, 0.30),
                child: Text(notes),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: visibleSubcategories.map((subcategory) {
                  final subcategoryId = _intValue(subcategory['id']);
                  if (subcategoryId == null) {
                    return const SizedBox.shrink();
                  }
                  return AppChoiceChip(
                    label: subcategory['name']?.toString() ?? 'Actividad',
                    icon: activityIconFromCode(subcategory['icon_code']),
                    selected: _selectedSubcategories.contains(subcategoryId),
                    onSelected: (selected) =>
                        _toggleSubcategory(categoryId, subcategoryId, selected),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleCategoryCount = _categories.where((category) {
      final subcategories = _subcategoryMaps(category);
      return _categoryMatchesSearch(category, subcategories);
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Actividades y disponibilidad'),
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  const AppSectionHeader(
                    title: 'Elige lo que quieres acompañar',
                    subtitle:
                        'Selecciona las actividades que quieres ofrecer. Puedes cambiarlas cuando lo necesites.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppSurfaceCard(
                    backgroundColor: AppColors.tint(AppColors.primary, 0.08),
                    borderColor: AppColors.tint(AppColors.primary, 0.24),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.checklist_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '$_selectedActivityCount actividad${_selectedActivityCount == 1 ? '' : 'es'} seleccionada${_selectedActivityCount == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (_hasChanges)
                          const AppStatusPill(
                            label: 'Sin guardar',
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppSurfaceCard(
                    backgroundColor: AppColors.tint(
                      _operationallyAvailable
                          ? AppColors.success
                          : AppColors.amber,
                      0.10,
                    ),
                    borderColor: AppColors.tint(
                      _operationallyAvailable
                          ? AppColors.success
                          : AppColors.warning,
                      0.30,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _isAvailable,
                          title: const Text(
                            'Quiero recibir actividades',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            _operationallyAvailable
                                ? 'Tu perfil está disponible para recibir coincidencias.'
                                : 'Activa esta opción cuando quieras recibir nuevas solicitudes.',
                          ),
                          onChanged: _setAvailability,
                        ),
                        if (_availabilityMessage.isNotEmpty) ...[
                          const Divider(),
                          Text(
                            _availabilityMessage,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_successMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppSurfaceCard(
                      backgroundColor: AppColors.tint(AppColors.success, 0.10),
                      borderColor: AppColors.tint(AppColors.success, 0.28),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(_successMessage!)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar una actividad',
                      hintText: 'Ejemplo: cine, café, caminar o museo',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_error != null)
                    AppSurfaceCard(
                      backgroundColor: AppColors.coralSoft,
                      borderColor: AppColors.tint(AppColors.danger, 0.28),
                      child: Text(_error!),
                    )
                  else if (_categories.isEmpty)
                    const AppEmptyState(
                      icon: Icons.category_outlined,
                      title: 'No hay actividades activas',
                      message: 'Todavía no hay actividades disponibles.',
                    )
                  else if (visibleCategoryCount == 0)
                    const AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No encontramos coincidencias',
                      message:
                          'Prueba otra palabra o limpia el campo de búsqueda.',
                    )
                  else
                    ..._categories.map(_categoryCard),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _saving || !_hasChanges ? null : _saveActivities,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _hasChanges
                          ? 'Guardar $_selectedActivityCount actividades'
                          : 'Actividades guardadas',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}
