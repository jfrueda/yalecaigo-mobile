import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/features/service_request/data/location_ping_service.dart';

void main() {
  test('GPS coordinates are limited to six decimal places for Django', () {
    expect(formatCoordinateForApi(4.6767123456), '4.676712');
    expect(formatCoordinateForApi(-74.0482129876), '-74.048213');
    expect(formatCoordinateForApi(0), '0.000000');
  });
}
