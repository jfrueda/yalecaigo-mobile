import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/service_display.dart';

class ServiceCancellationData {
  const ServiceCancellationData({required this.code, required this.reason});

  final String code;
  final String reason;
}

class ServiceRescheduleData {
  const ServiceRescheduleData({
    required this.proposedStartTime,
    required this.reason,
  });

  final DateTime proposedStartTime;
  final String reason;
}

Future<ServiceCancellationData?> showServiceCancellationDialog(
  BuildContext context, {
  required bool isProvider,
}) {
  return showDialog<ServiceCancellationData>(
    context: context,
    builder: (_) => _ServiceCancellationDialog(isProvider: isProvider),
  );
}

Future<ServiceRescheduleData?> showServiceRescheduleDialog(
  BuildContext context, {
  required DateTime currentStartTime,
}) {
  return showDialog<ServiceRescheduleData>(
    context: context,
    builder: (_) =>
        _ServiceRescheduleDialog(currentStartTime: currentStartTime),
  );
}

class _ServiceCancellationDialog extends StatefulWidget {
  const _ServiceCancellationDialog({required this.isProvider});

  final bool isProvider;

  @override
  State<_ServiceCancellationDialog> createState() =>
      _ServiceCancellationDialogState();
}

class _ServiceCancellationDialogState
    extends State<_ServiceCancellationDialog> {
  late String _code;
  final _reasonCtrl = TextEditingController();

  Map<String, String> get _options => widget.isProvider
      ? const {
          'cannot_arrive': 'No puedo llegar',
          'client_no_show': 'El solicitante no se presentó',
          'activity_mismatch': 'La actividad no coincide',
          'schedule_not_agreed': 'No fue posible acordar un nuevo horario',
          'unsafe': 'No me siento seguro',
          'other': 'Otro',
        }
      : const {
          'no_longer_needed': 'Ya no necesito la actividad',
          'provider_no_show': 'El acompañante no llegó',
          'schedule_not_agreed': 'No fue posible acordar un nuevo horario',
          'unsafe': 'No me siento seguro',
          'activity_changed': 'La actividad cambió',
          'other': 'Otro',
        };

  @override
  void initState() {
    super.initState();
    _code = _options.keys.first;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancelar actividad'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'La otra persona recibirá una notificación y el motivo quedará registrado.',
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _code,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: _options.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _code = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Detalle (opcional)',
                  hintText: 'Explica brevemente el motivo.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.pop(
                  context,
                  ServiceCancellationData(
                    code: _code,
                    reason: _reasonCtrl.text.trim(),
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Confirmar cancelación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRescheduleDialog extends StatefulWidget {
  const _ServiceRescheduleDialog({required this.currentStartTime});

  final DateTime currentStartTime;

  @override
  State<_ServiceRescheduleDialog> createState() =>
      _ServiceRescheduleDialogState();
}

class _ServiceRescheduleDialogState extends State<_ServiceRescheduleDialog> {
  int _offsetMinutes = 15;
  final _reasonCtrl = TextEditingController();

  static const _offsetOptions = <int>[
    -60,
    -45,
    -30,
    -20,
    -15,
    -10,
    -5,
    5,
    10,
    15,
    20,
    30,
    45,
    60,
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  DateTime get _proposedStart =>
      widget.currentStartTime.add(Duration(minutes: _offsetMinutes));

  String _offsetLabel(int value) {
    if (value < 0) return '${value.abs()} minutos antes';
    return '$value minutos después';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Proponer nueva hora'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Hora actual: ${formatDateTime(widget.currentStartTime)}'),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: _offsetMinutes,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mover la reunión',
                ),
                items: _offsetOptions
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text(_offsetLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _offsetMinutes = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Text(
                  'Nueva hora propuesta: ${formatDateTime(_proposedStart)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Motivo opcional',
                  hintText: 'Ej. Necesito veinte minutos adicionales.',
                  alignLabelWithHint: true,
                ),
              ),
              const Text(
                'La hora original seguirá vigente hasta que la otra persona acepte.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  ServiceRescheduleData(
                    proposedStartTime: _proposedStart,
                    reason: _reasonCtrl.text.trim(),
                  ),
                ),
                icon: const Icon(Icons.schedule_send_outlined),
                label: const Text('Enviar propuesta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
