import 'package:ak_push/ak_push.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AkPushError', () {
    test('solo son reintentables los que mejoran esperando', () {
      expect(AkPushError(AkPushErrorCode.network, 'x').retryable, isTrue);
      expect(AkPushError(AkPushErrorCode.serviceUnavailable, 'x').retryable, isTrue);
    });

    test('un dato mal no se arregla reintentando', () {
      for (final c in [
        AkPushErrorCode.unauthorized,
        AkPushErrorCode.appMismatch,
        AkPushErrorCode.permissionDenied,
        AkPushErrorCode.firebaseInit,
        AkPushErrorCode.notInitialized,
      ]) {
        expect(AkPushError(c, 'x').retryable, isFalse, reason: c.name);
      }
    });

    test('el detalle acompaña al mensaje', () {
      final e = AkPushError(
        AkPushErrorCode.appMismatch,
        'No coincide',
        details: 'registrado com.acme.app',
      );
      expect(e.toString(), contains('appMismatch'));
      expect(e.toString(), contains('registrado com.acme.app'));
    });
  });
}
