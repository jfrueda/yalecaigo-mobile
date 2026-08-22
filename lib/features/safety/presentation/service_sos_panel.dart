import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../shared/widgets/app_components.dart';
import '../../account/data/account_service.dart';
import '../../tracking/data/device_location_service.dart';
import '../data/pending_sos_store.dart';
import '../data/sos_service.dart';

class ServiceSosPanel extends StatefulWidget {
  const ServiceSosPanel({
    super.key,
    required this.serviceRequestId,
    required this.status,
    this.onSosConfirmed,
  });

  final int serviceRequestId;
  final String status;
  final VoidCallback? onSosConfirmed;

  @override
  State<ServiceSosPanel> createState() => _ServiceSosPanelState();
}

class _ServiceSosPanelState extends State<ServiceSosPanel> {
  final SosService _sosService = SosService();
  final PendingSosStore _pendingStore = PendingSosStore();
  final DeviceLocationService _locationService = DeviceLocationService();
  final AccountService _accountService = AccountService();

  Timer? _retryTimer;
  PendingSosEvent? _pending;
  Map<String, dynamic>? _activeSos;
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _sending = false;
  bool _retrying = false;
  int _activeContacts = 0;
  int _verifiedContacts = 0;

  bool get _supportsSos => const {
    'matched',
    'started',
    'incident',
  }.contains(widget.status.toLowerCase());

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _retryTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!mounted) return;
      if (_pending != null) {
        await _retryPending(silent: true);
      } else if (_activeSos != null) {
        await _refreshActive(silent: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ServiceSosPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceRequestId != widget.serviceRequestId) {
      _pending = null;
      _activeSos = null;
      _detail = null;
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (!_supportsSos) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    final pending = await _pendingStore.forService(widget.serviceRequestId);
    if (!mounted) return;
    setState(() => _pending = pending);

    await Future.wait([_refreshContacts(), _refreshActive(silent: true)]);
    if (!mounted) return;
    setState(() => _loading = false);

    if (_pending != null && _activeSos == null) {
      await _retryPending(silent: true);
    }
  }

  Future<void> _refreshContacts() async {
    try {
      final contacts = await _accountService.listEmergencyContacts();
      final active = contacts.where((contact) => contact['is_active'] == true);
      final verified = active.where(
        (contact) =>
            contact['verification_status']?.toString().toUpperCase() ==
            'VERIFIED',
      );
      if (!mounted) return;
      setState(() {
        _activeContacts = active.length;
        _verifiedContacts = verified.length;
      });
    } catch (_) {
      // El estado de contactos es informativo. Nunca bloquea el botón SOS.
    }
  }

  Future<void> _refreshActive({bool silent = false}) async {
    try {
      final active = await _sosService.active(widget.serviceRequestId);
      if (!mounted) return;
      if (active['active'] == true) {
        setState(() => _activeSos = active);
        final incidentId = _int(active['id']);
        if (incidentId != null) {
          await _loadDetail(incidentId, silent: true);
        }
        final pending = _pending;
        if (pending != null &&
            active['client_event_id']?.toString() == pending.clientEventId) {
          await _pendingStore.remove(pending.clientEventId);
          if (mounted) setState(() => _pending = null);
        }
      } else {
        setState(() {
          _activeSos = null;
          _detail = null;
        });
      }
    } on DioException catch (error) {
      if (!silent && !isSosTransportFailure(error)) {
        _message(
          apiErrorMessage(
            error,
            fallback: 'No fue posible consultar el estado del SOS.',
          ),
        );
      }
    }
  }

  Future<void> _loadDetail(int incidentId, {bool silent = false}) async {
    try {
      final detail = await _sosService.detail(incidentId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } on DioException catch (error) {
      if (!silent) {
        _message(
          apiErrorMessage(
            error,
            fallback: 'No fue posible actualizar el detalle del SOS.',
          ),
        );
      }
    }
  }

  Future<void> _activateSos() async {
    if (_sending || _pending != null || _activeSos != null) return;
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SosConfirmDialog(),
    );
    if (reason == null || !mounted) return;

    setState(() => _sending = true);
    String? latitude;
    String? longitude;
    double? accuracy;
    String? capturedAt;

    try {
      final position = await _locationService.currentPosition().timeout(
        const Duration(seconds: 8),
      );
      latitude = formatSosCoordinate(position.latitude);
      longitude = formatSosCoordinate(position.longitude);
      accuracy = position.accuracy;
      capturedAt = position.timestamp.toUtc().toIso8601String();
    } catch (_) {
      // El backend utilizará el último LocationPing conocido si no fue posible
      // obtener una posición actual. El SOS no se bloquea por una falla de GPS.
    }

    final pending = PendingSosEvent(
      serviceRequestId: widget.serviceRequestId,
      clientEventId: newSosClientEventId(),
      reason: reason,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      latitude: latitude,
      longitude: longitude,
      locationAccuracy: accuracy,
      locationCapturedAt: capturedAt,
    );

    try {
      try {
        await _pendingStore.put(pending);
      } catch (_) {
        // Si el almacenamiento local falla, se intenta el envío inmediato.
        // Mientras la pantalla siga abierta, el evento permanece en memoria.
      }
      if (!mounted) return;
      setState(() => _pending = pending);
      await _sendPending(pending, silent: false);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _retryPending({bool silent = false}) async {
    final pending = _pending;
    if (pending == null || _retrying || _sending) return;
    if (mounted) setState(() => _retrying = true);
    await _sendPending(pending, silent: silent);
    if (mounted) setState(() => _retrying = false);
  }

  Future<void> _sendPending(
    PendingSosEvent pending, {
    required bool silent,
  }) async {
    try {
      final result = await _sosService.create(pending);
      if (result['received_by_server'] != true) {
        if (!silent) {
          _message(
            'GoWith no confirmó la recepción. El SOS permanece pendiente.',
          );
        }
        return;
      }

      await _pendingStore.remove(pending.clientEventId);
      if (!mounted) return;
      setState(() {
        _pending = null;
        _activeSos = {
          ...result,
          'active': true,
          'id': result['incident_id'],
          'client_event_id': pending.clientEventId,
        };
      });
      final incidentId = _int(result['incident_id']);
      if (incidentId != null) {
        await _loadDetail(incidentId, silent: true);
      }
      if (!mounted) return;
      widget.onSosConfirmed?.call();
      if (!silent) {
        _message(
          'SOS recibido por GoWith. Se inició el escalamiento configurado.',
        );
      }
    } on DioException catch (error) {
      if (isSosTransportFailure(error)) {
        if (!silent) {
          _message(
            'Sin confirmación del servidor. El SOS quedó guardado y se reintentará al recuperar conexión.',
          );
        }
        return;
      }

      // Un rechazo HTTP sí llegó al servidor: no debe reintentarse para siempre.
      await _pendingStore.remove(pending.clientEventId);
      if (mounted) setState(() => _pending = null);
      if (!silent) {
        _message(
          apiErrorMessage(
            error,
            fallback:
                'GoWith rechazó el SOS. Revisa el estado de la actividad.',
          ),
        );
      }
      await _refreshActive(silent: true);
    }
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _kindLabel(String? kind) {
    return switch ((kind ?? '').toUpperCase()) {
      'TIMER_ESCALATION' => 'Escalamiento por temporizador',
      'SOS' => 'SOS manual',
      _ => 'Caso de seguridad',
    };
  }

  String _statusLabel(String? status) {
    return switch ((status ?? '').toUpperCase()) {
      'OPEN' => 'Pendiente de revisión',
      'UNDER_REVIEW' => 'En revisión',
      'CLOSED' => 'Cerrado',
      'DISMISSED' => 'Descartado',
      _ => status ?? '—',
    };
  }

  String _locationLabel(String? source) {
    return switch ((source ?? '').toUpperCase()) {
      'DEVICE' => 'GPS capturado al activar SOS',
      'LAST_KNOWN' => 'Última ubicación conocida',
      'LAST_KNOWN_STALE' => 'Última ubicación conocida desactualizada',
      'UNAVAILABLE' => 'Ubicación no disponible',
      _ => 'Ubicación por confirmar',
    };
  }

  Color _deliveryColor(String status) {
    return switch (status.toUpperCase()) {
      'SENT' => AppColors.success,
      'FAILED' => AppColors.danger,
      'PENDING' => AppColors.warning,
      'NOT_CONFIGURED' => AppColors.textSecondary,
      'SKIPPED' => AppColors.textSecondary,
      _ => AppColors.textSecondary,
    };
  }

  String _deliveryLabel(String status) {
    return switch (status.toUpperCase()) {
      'SENT' => 'Enviado',
      'FAILED' => 'Fallido',
      'PENDING' => 'Pendiente',
      'NOT_CONFIGURED' => 'No configurado',
      'SKIPPED' => 'Omitido',
      _ => status,
    };
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsSos) return const SizedBox.shrink();
    if (_loading) {
      return const AppSurfaceCard(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final active = _detail ?? _activeSos;
    final deliveries = active?['deliveries'] is List
        ? (active!['deliveries'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : const <Map<String, dynamic>>[];
    final summary = active?['delivery_summary'] is Map
        ? Map<String, dynamic>.from(active!['delivery_summary'] as Map)
        : const <String, dynamic>{};

    return AppSurfaceCard(
      backgroundColor: AppColors.tint(AppColors.danger, 0.045),
      borderColor: AppColors.tint(AppColors.danger, 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sos_rounded, color: AppColors.danger, size: 30),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOS y escalamiento',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'GoWith no sustituye a los servicios públicos de emergencia.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar SOS',
                onPressed: () => _refreshActive(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_pending != null) ...[
            AppSurfaceCard(
              backgroundColor: AppColors.tint(AppColors.warning, 0.10),
              borderColor: AppColors.tint(AppColors.warning, 0.32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_off_outlined, color: AppColors.warning),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'SOS pendiente de envío',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'El dispositivo guardó el SOS, pero el servidor todavía no confirmó su recepción. Se reintentará automáticamente mientras esta pantalla permanezca abierta.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _retrying ? null : () => _retryPending(),
                    icon: _retrying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: const Text('Reintentar ahora'),
                  ),
                ],
              ),
            ),
          ] else if (active != null) ...[
            AppSurfaceCard(
              backgroundColor: AppColors.tint(AppColors.danger, 0.08),
              borderColor: AppColors.tint(AppColors.danger, 0.30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppStatusPill(
                        label: _kindLabel(active['event_kind']?.toString()),
                        color: AppColors.danger,
                        icon: Icons.emergency_outlined,
                      ),
                      AppStatusPill(
                        label: _statusLabel(
                          (active['status'] ?? active['incident_status'])
                              ?.toString(),
                        ),
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Caso #${active['id'] ?? active['incident_id'] ?? '—'}'),
                  Text(
                    'Ubicación: ${_locationLabel(active['location_source']?.toString())}',
                  ),
                  if ((active['location_captured_at']?.toString() ?? '')
                      .isNotEmpty)
                    Text('Capturada: ${active['location_captured_at']}'),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'La actividad permanece bloqueada mientras GoWith revisa el caso.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Notificaciones: ${summary['sent'] ?? 0} enviadas · ${summary['failed'] ?? 0} fallidas · ${summary['not_configured'] ?? 0} sin canal configurado',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (deliveries.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final delivery in deliveries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        delivery['channel']?.toString().toUpperCase() == 'EMAIL'
                            ? Icons.email_outlined
                            : Icons.phone_outlined,
                        size: 18,
                        color: _deliveryColor(
                          delivery['status']?.toString() ?? '',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              delivery['contact_name_snapshot']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? delivery['contact_name_snapshot'].toString()
                                  : 'Destino de seguridad',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_deliveryLabel(delivery['status']?.toString() ?? '')}${(delivery['destination_hint']?.toString() ?? '').isEmpty ? '' : ' · ${delivery['destination_hint']}'}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ] else ...[
            Text(
              _verifiedContacts > 0
                  ? 'Contactos: $_verifiedContacts verificado(s) de $_activeContacts activo(s).'
                  : _activeContacts > 0
                  ? 'Tienes $_activeContacts contacto(s) activo(s), pero ninguno aparece verificado para envío externo.'
                  : 'No tienes contactos de emergencia activos. El SOS seguirá llegando a GoWith, pero no habrá contactos personales a quienes escalar.',
              style: TextStyle(
                color: _verifiedContacts > 0
                    ? AppColors.textSecondary
                    : AppColors.warning,
                fontWeight: _verifiedContacts > 0
                    ? FontWeight.w400
                    : FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: _sending ? null : _activateSos,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sos_rounded),
              label: Text(_sending ? 'Enviando SOS…' : 'ACTIVAR SOS'),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Solo se mostrará “SOS recibido” cuando el backend confirme received_by_server=true. Si no hay red, el evento queda pendiente y conserva el mismo identificador para un reintento idempotente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SosConfirmDialog extends StatefulWidget {
  const _SosConfirmDialog();

  @override
  State<_SosConfirmDialog> createState() => _SosConfirmDialogState();
}

class _SosConfirmDialogState extends State<_SosConfirmDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.sos_rounded, color: AppColors.danger, size: 42),
      title: const Text('Activar SOS'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GoWith registrará un caso de seguridad, bloqueará la actividad y ejecutará los canales de escalamiento configurados.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Esto no contacta automáticamente a policía, ambulancias ni otras autoridades.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '¿Qué está pasando? (opcional)',
                hintText: 'Información breve para el equipo de seguridad',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          icon: const Icon(Icons.warning_amber_rounded),
          label: const Text('Activar SOS ahora'),
        ),
      ],
    );
  }
}
