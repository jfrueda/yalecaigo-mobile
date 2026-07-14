import 'package:flutter/material.dart';

class ServiceRatingData {
  const ServiceRatingData({required this.score, required this.comment});

  final int score;
  final String comment;
}

Future<ServiceRatingData?> showRequiredServiceRatingDialog(
  BuildContext context, {
  required String targetLabel,
  bool includeFinishMessage = true,
}) {
  return showDialog<ServiceRatingData>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ServiceRatingDialog(
      targetLabel: targetLabel,
      includeFinishMessage: includeFinishMessage,
    ),
  );
}

class _ServiceRatingDialog extends StatefulWidget {
  const _ServiceRatingDialog({
    required this.targetLabel,
    required this.includeFinishMessage,
  });

  final String targetLabel;
  final bool includeFinishMessage;

  @override
  State<_ServiceRatingDialog> createState() => _ServiceRatingDialogState();
}

class _ServiceRatingDialogState extends State<_ServiceRatingDialog> {
  final _commentController = TextEditingController();
  int _score = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(
          widget.includeFinishMessage
              ? 'Finalizar y calificar'
              : 'Calificar ${widget.targetLabel}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.includeFinishMessage) ...[
                const Text(
                  'Tu confirmación de finalización quedará registrada. Para cerrar el servicio, califica ahora la experiencia.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                '¿Cómo fue ${widget.targetLabel}?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    tooltip: '${index + 1} estrellas',
                    onPressed: () => setState(() => _score = index + 1),
                    icon: Icon(
                      index < _score ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  ),
                ),
              ),
              Text('$_score de 5'),
              const SizedBox(height: 14),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(
              ServiceRatingData(
                score: _score,
                comment: _commentController.text.trim(),
              ),
            ),
            icon: Icon(widget.includeFinishMessage ? Icons.flag : Icons.send),
            label: Text(
              widget.includeFinishMessage
                  ? 'Finalizar y enviar calificación'
                  : 'Enviar calificación',
            ),
          ),
        ],
      ),
    );
  }
}
