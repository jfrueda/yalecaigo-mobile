import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/features/safety/data/pending_sos_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const event = PendingSosEvent(
    serviceRequestId: 42,
    clientEventId: '123e4567-e89b-42d3-a456-426614174000',
    reason: 'Prueba QA F5B',
    createdAt: '2026-08-21T23:00:00Z',
    latitude: '4.676712',
    longitude: '-74.048213',
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('PendingSosStore - cola mutable', () {
    test('clearService sobre almacenamiento vacío no falla', () async {
      final store = PendingSosStore();

      await expectLater(store.clearService(42), completes);
      expect(await store.forService(42), isNull);
    });

    test('primer put persiste y remove elimina el evento', () async {
      final store = PendingSosStore();

      await store.put(event);
      final restored = await store.forService(42);
      expect(restored, isNotNull);
      expect(restored!.clientEventId, event.clientEventId);

      await store.remove(event.clientEventId);
      expect(await store.forService(42), isNull);
    });

    test('almacenamiento malformado se recupera como lista mutable', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        PendingSosStore.storageKey: '{json-invalido',
      });
      final store = PendingSosStore();

      await store.put(event);
      expect((await store.forService(42))?.clientEventId, event.clientEventId);
    });
  });
}
