import 'package:ak_push/ak_push.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AkPushConfig', () {
    const crudo = {
      'firebase': {
        'projectId': 'juan-push',
        'appId': '1:1:android:abc',
        'apiKey': 'AIza-x',
        'messagingSenderId': '1',
      },
      'version': 'cfg_ab12',
    };

    test('lee lo que manda el servidor', () {
      final c = AkPushConfig.fromJson(crudo);
      expect(c.projectId, 'juan-push');
      expect(c.appId, '1:1:android:abc');
      expect(c.version, 'cfg_ab12');
    });

    test('sobrevive a la ida y vuelta del guardado', () {
      final ida = AkPushConfig.fromJson(crudo);
      final vuelta = AkPushConfig.fromJson(ida.toJson());
      expect(vuelta.appId, ida.appId);
      expect(vuelta.version, ida.version);
    });

    test('la huella distingue dos cuentas — es lo que evita el teléfono mudo', () {
      final a = AkPushConfig.fromJson(crudo);
      final b = AkPushConfig.fromJson({
        ...crudo,
        'version': 'cfg_otra',
      });
      expect(a.version == b.version, isFalse);
    });

    test('traduce a las opciones que espera Firebase', () {
      final o = AkPushConfig.fromJson(crudo).toFirebaseOptions();
      expect(o.projectId, 'juan-push');
      expect(o.messagingSenderId, '1');
    });
  });
}
