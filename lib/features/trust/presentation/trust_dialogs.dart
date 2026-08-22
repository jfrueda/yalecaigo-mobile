import 'package:flutter/material.dart';

class BehaviorReportData {
  const BehaviorReportData({required this.category, required this.description});

  final String category;
  final String description;
}

class UserBlockData {
  const UserBlockData({required this.reason});

  final String reason;
}

const Map<String, String> behaviorReportCategoryLabels = {
  'NO_SHOW': 'No se presentó',
  'UNSAFE_BEHAVIOR': 'Comportamiento inseguro',
  'HARASSMENT': 'Acoso',
  'INAPPROPRIATE_BEHAVIOR': 'Comportamiento inapropiado',
  'DISCRIMINATION': 'Discriminación',
  'FRAUD': 'Fraude o engaño',
  'OTHER': 'Otro',
};

Future<BehaviorReportData?> showBehaviorReportDialog(
  BuildContext context, {
  required String targetLabel,
}) {
  return showDialog<BehaviorReportData>(
    context: context,
    builder: (_) => _BehaviorReportDialog(targetLabel: targetLabel),
  );
}

Future<UserBlockData?> showUserBlockDialog(
  BuildContext context, {
  required String targetLabel,
}) {
  return showDialog<UserBlockData>(
    context: context,
    builder: (_) => _UserBlockDialog(targetLabel: targetLabel),
  );
}

class _BehaviorReportDialog extends StatefulWidget {
  const _BehaviorReportDialog({required this.targetLabel});

  final String targetLabel;

  @override
  State<_BehaviorReportDialog> createState() => _BehaviorReportDialogState();
}

class _BehaviorReportDialogState extends State<_BehaviorReportDialog> {
  final _descriptionController = TextEditingController();
  String _category = 'OTHER';

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reportar comportamiento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'El reporte sobre ${widget.targetLabel} será privado y revisado por GoWith. No implica una sanción automática.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              items: behaviorReportCategoryLabels.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Detalle (opcional)',
                hintText: 'Describe brevemente lo ocurrido.',
                border: OutlineInputBorder(),
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
          onPressed: () => Navigator.of(context).pop(
            BehaviorReportData(
              category: _category,
              description: _descriptionController.text.trim(),
            ),
          ),
          icon: const Icon(Icons.report_outlined),
          label: const Text('Enviar reporte'),
        ),
      ],
    );
  }
}

class _UserBlockDialog extends StatefulWidget {
  const _UserBlockDialog({required this.targetLabel});

  final String targetLabel;

  @override
  State<_UserBlockDialog> createState() => _UserBlockDialogState();
}

class _UserBlockDialogState extends State<_UserBlockDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bloquear usuario'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Al bloquear a ${widget.targetLabel}, no volverán a ser emparejados en nuevas actividades. El historial existente se conserva.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Motivo privado (opcional)',
                border: OutlineInputBorder(),
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
          onPressed: () => Navigator.of(
            context,
          ).pop(UserBlockData(reason: _reasonController.text.trim())),
          icon: const Icon(Icons.block_outlined),
          label: const Text('Bloquear'),
        ),
      ],
    );
  }
}
