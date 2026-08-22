import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/utils/service_display.dart';

void main() {
  test('mapea los estados operativos principales de la fase 4A', () {
    expect(operationalStageLabel('accepted'), 'Aceptada');
    expect(operationalStageLabel('confirmed'), 'Confirmada');
    expect(operationalStageLabel('en_route'), 'Acompañante en camino');
    expect(operationalStageLabel('ready_to_start'), 'Listos para iniciar');
    expect(operationalStageLabel('in_progress'), 'En curso');
    expect(
      operationalStageLabel('completion_pending'),
      'Pendiente de confirmar cierre',
    );
    expect(operationalStageLabel('completed'), 'Finalizada');
    expect(operationalStageLabel('no_show'), 'No presentado');
  });
}
