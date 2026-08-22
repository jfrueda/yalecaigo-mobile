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

class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({super.key});

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  final AccountService _service = AccountService();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _documentNumber = TextEditingController();
  final TextEditingController _documentCountry = TextEditingController(
    text: 'CO',
  );

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _current;
  List<Map<String, dynamic>> _documentTypes = const [];
  Map<String, dynamic> _requirements = const {};

  String _documentType = 'CC';
  DateTime? _expirationDate;
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
    _documentNumber.dispose();
    _documentCountry.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _service.getIdentityVerification();
      if (!mounted) return;
      final current = response['current'];
      setState(() {
        _current = current is Map ? Map<String, dynamic>.from(current) : null;
        _documentTypes = _mapList(response['document_types']);
        _requirements = _map(response['requirements']);
        if (_current != null) {
          _documentType = _current!['document_type']?.toString() ?? 'CC';
          _documentCountry.text =
              _current!['document_country']?.toString() ?? 'CO';
          final expiration = _current!['document_expiration_date']?.toString();
          _expirationDate = expiration == null
              ? null
              : DateTime.tryParse(expiration);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible consultar la verificación de identidad.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' => 'Pendiente de revisión',
      'IN_REVIEW' => 'En revisión',
      'VERIFIED' => 'Identidad verificada',
      'REJECTED' => 'Rechazada',
      'REQUIRES_UPDATE' => 'Requiere actualización',
      'EXPIRED' => 'Vencida',
      'SUSPENDED' => 'Suspendida',
      _ => status.isEmpty ? 'Sin enviar' : status,
    };
  }

  Color _statusColor(String status) {
    return switch (status.toUpperCase()) {
      'VERIFIED' => AppColors.success,
      'REJECTED' || 'SUSPENDED' => AppColors.danger,
      'REQUIRES_UPDATE' || 'EXPIRED' => AppColors.warning,
      _ => AppColors.information,
    };
  }

  bool get _canSubmit {
    if (_current == null) return true;
    return _current!['can_resubmit'] == true;
  }

  bool get _requiresBack {
    final values = _requirements['back_required_for'];
    if (values is! List) return {'CC', 'CE'}.contains(_documentType);
    return values.map((item) => item.toString()).contains(_documentType);
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _selectExpirationDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime(today.year + 5),
      firstDate: today,
      lastDate: DateTime(today.year + 30),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Vencimiento del documento',
      cancelText: 'Sin fecha',
      confirmText: 'Aceptar',
    );
    if (selected != null && mounted) {
      setState(() => _expirationDate = selected);
    }
  }

  Future<XFile?> _pickImage({required bool selfie}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(selfie ? 'Tomar selfie' : 'Tomar fotografía'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2200,
      maxHeight: 2200,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
    );
  }

  Future<void> _selectFile(String kind) async {
    final file = await _pickImage(selfie: kind == 'selfie');
    if (file == null || !mounted) return;
    setState(() {
      if (kind == 'front') {
        _front = file;
      } else if (kind == 'back') {
        _back = file;
      } else {
        _selfie = file;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_front == null || _selfie == null || (_requiresBack && _back == null)) {
      setState(() {
        _error = _requiresBack
            ? 'Carga el frente, el reverso y la selfie.'
            : 'Carga el documento frontal y la selfie.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final values = <String, dynamic>{
        'document_type': _documentType,
        'document_country': _documentCountry.text.trim().toUpperCase(),
        'document_number': _documentNumber.text.trim(),
        'document_front_image': await MultipartFile.fromFile(
          _front!.path,
          filename: _front!.name,
        ),
        'selfie_image': await MultipartFile.fromFile(
          _selfie!.path,
          filename: _selfie!.name,
        ),
        'use_selfie_as_profile_photo': true,
      };
      if (_back != null) {
        values['document_back_image'] = await MultipartFile.fromFile(
          _back!.path,
          filename: _back!.name,
        );
      }
      if (_expirationDate != null) {
        values['document_expiration_date'] = _formatDate(_expirationDate!);
      }

      await _service.submitIdentity(
        FormData.fromMap(values),
        resubmission: _current != null,
      );
      _documentNumber.clear();
      _front = null;
      _back = null;
      _selfie = null;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Documentos enviados. Te avisaremos cuando la revisión termine.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: 'No fue posible enviar los documentos.',
        );
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _fileCard({
    required String title,
    required String subtitle,
    required String kind,
    required XFile? file,
    required IconData icon,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (file != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: kind == 'selfie' ? 1 : 1.55,
                child: Image.file(File(file.path), fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : () => _selectFile(kind),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(file == null ? 'Seleccionar' : 'Cambiar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = _current?['status']?.toString() ?? '';
    final rejectionReason = _current?['rejection_reason']?.toString() ?? '';
    final showDecisionReason = {
      'REJECTED',
      'REQUIRES_UPDATE',
      'SUSPENDED',
    }.contains(currentStatus.toUpperCase());
    final maxSize = _requirements['maximum_size_mb']?.toString() ?? '8';

    return Scaffold(
      appBar: AppBar(
        title: const AppBrandAppBarTitle(label: 'Verificación de identidad'),
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
                    title: 'Comprueba tu identidad',
                    subtitle:
                        'Tus documentos son privados y solo se usan para la validación y la seguridad de la plataforma.',
                  ),
                  if (_current != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppSurfaceCard(
                      backgroundColor: AppColors.tint(
                        _statusColor(currentStatus),
                        0.08,
                      ),
                      borderColor: AppColors.tint(
                        _statusColor(currentStatus),
                        0.28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppStatusPill(
                            label: _statusLabel(currentStatus),
                            color: _statusColor(currentStatus),
                            icon: currentStatus == 'VERIFIED'
                                ? Icons.verified_user_outlined
                                : Icons.fact_check_outlined,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Documento terminado en ${_current!['document_number_last4'] ?? '----'}',
                          ),
                          if (showDecisionReason &&
                              rejectionReason.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              rejectionReason,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_current != null &&
                      {
                        'PENDING',
                        'IN_REVIEW',
                      }.contains(currentStatus.toUpperCase())) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppSurfaceCard(
                      backgroundColor: AppColors.tint(
                        AppColors.information,
                        0.08,
                      ),
                      borderColor: AppColors.tint(AppColors.information, 0.24),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.hourglass_top_rounded,
                            color: AppColors.information,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Recibimos tus documentos. Te avisaremos cuando la revisión termine.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!_canSubmit) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppSurfaceCard(
                      child: Text(
                        currentStatus == 'VERIFIED'
                            ? 'Tu identidad ya fue aprobada. No necesitas volver a cargar documentos.'
                            : 'La solicitud está siendo revisada. Actualiza esta pantalla para conocer el resultado.',
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<String>(
                      initialValue: _documentType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de documento',
                      ),
                      items:
                          (_documentTypes.isEmpty
                                  ? const [
                                      {
                                        'value': 'CC',
                                        'label': 'Cédula de ciudadanía',
                                      },
                                      {
                                        'value': 'CE',
                                        'label': 'Cédula de extranjería',
                                      },
                                      {
                                        'value': 'PASSPORT',
                                        'label': 'Pasaporte',
                                      },
                                    ]
                                  : _documentTypes)
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item['value']?.toString(),
                                  child: Text(item['label']?.toString() ?? ''),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _documentType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _documentCountry,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 2,
                      decoration: const InputDecoration(
                        labelText: 'País emisor',
                        helperText: 'Código de dos letras. Ejemplo: CO',
                      ),
                      validator: (value) => (value ?? '').trim().length != 2
                          ? 'Ingresa un código de país válido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _documentNumber,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Número de documento',
                        helperText:
                            'Se transforma en una huella segura y no se muestra públicamente.',
                      ),
                      validator: (value) {
                        final length = (value ?? '').trim().length;
                        return length < 5 || length > 30
                            ? 'Utiliza entre 5 y 30 caracteres'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectExpirationDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de vencimiento (opcional)',
                          suffixIcon: Icon(Icons.event_outlined),
                        ),
                        child: Text(
                          _expirationDate == null
                              ? 'No indicada'
                              : _formatDate(_expirationDate!),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _fileCard(
                      title: 'Frente del documento',
                      subtitle: 'Imagen completa, legible y sin reflejos.',
                      kind: 'front',
                      file: _front,
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_requiresBack)
                      _fileCard(
                        title: 'Reverso del documento',
                        subtitle: 'Obligatorio para este tipo de documento.',
                        kind: 'back',
                        file: _back,
                        icon: Icons.flip_to_back_outlined,
                      ),
                    if (_requiresBack) const SizedBox(height: AppSpacing.md),
                    _fileCard(
                      title: 'Selfie',
                      subtitle:
                          'Usa buena iluminación y muestra el rostro completo. También la usaremos como tu foto de perfil.',
                      kind: 'selfie',
                      file: _selfie,
                      icon: Icons.face_retouching_natural_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Formatos admitidos: JPG, PNG y WEBP. Máximo $maxSize MB por imagen.',
                      style: Theme.of(context).textTheme.bodySmall,
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
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: Text(
                        _current == null
                            ? 'Enviar documentos'
                            : 'Reenviar documentos',
                      ),
                    ),
                  ],
                  if (_error != null && !_canSubmit) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppSurfaceCard(
                      backgroundColor: AppColors.coralSoft,
                      child: Text(_error!),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}
