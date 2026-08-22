import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/network/endpoints.dart';
import 'package:gowith/features/trust/presentation/trust_dialogs.dart';

void main() {
  test('expone los endpoints de confianza de fase 4B', () {
    expect(Endpoints.ratingRequest(17), '/services/requests/17/rating/');
    expect(Endpoints.behaviorReport(17), '/services/requests/17/report/');
    expect(Endpoints.blockedUsers, '/services/blocked-users/');
    expect(Endpoints.blockUser(8), '/services/users/8/block/');
    expect(
      Endpoints.providerReputation(8),
      '/services/providers/8/reputation/',
    );
  });

  test('mantiene las categorías backend de reporte de comportamiento', () {
    expect(behaviorReportCategoryLabels.keys.toSet(), {
      'NO_SHOW',
      'UNSAFE_BEHAVIOR',
      'HARASSMENT',
      'INAPPROPRIATE_BEHAVIOR',
      'DISCRIMINATION',
      'FRAUD',
      'OTHER',
    });
  });
}
