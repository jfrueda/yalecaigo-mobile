import 'package:flutter/material.dart';

class ServiceRatingData {
  const ServiceRatingData({
    required this.score,
    required this.privateComment,
    required this.publicComment,
  });

  final int score;
  final String privateComment;
  final String publicComment;
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
  final _privateCommentController = TextEditingController();
  final _publicCommentController = TextEditingController();
  int _score = 5;

  @override
  void dispose() {
    _privateCommentController.dispose();
    _publicCommentController.dispose();
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
                  'Tu confirmación de finalización quedará registrada. La calificación se habilita cuando ambas personas hayan cerrado la actividad.',
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
                controller: _publicCommentController,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Comentario público (opcional)',
                  helperText: 'Se publicará únicamente después de moderación.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _privateCommentController,
                maxLines: 3,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Comentario privado para GoWith (opcional)',
                  helperText:
                      'No será visible para la otra persona ni en su perfil.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ahora no'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(
              ServiceRatingData(
                score: _score,
                privateComment: _privateCommentController.text.trim(),
                publicComment: _publicCommentController.text.trim(),
              ),
            ),
            icon: const Icon(Icons.send),
            label: const Text('Enviar calificación'),
          ),
        ],
      ),
    );
  }
}
