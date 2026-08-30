import 'package:ak_push/ak_push.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AkPushConfig', () {
    /// La forma EXACTA que devuelve `GET /api/v1/configuracion`.
    const delServicio = {
      'ok': true,
      'comercio': 'mundototal',
      'version': 1,
      'firebase': {
        'projectId': 'mundototal-72162',
        'appId': '1:859769563262:android:69c967f8f8d0a8c516902f',
        'apiKey': 'AIza-falsa-para-la-prueba',
        'messagingSenderId': '859769563262',
      },
    };

    test('lee la respuesta del servicio tal cual llega', () {
      final c = AkPushConfig.fromJson(delServicio);
      expect(c.projectId, 'mundototal-72162');
      expect(c.messagingSenderId, '859769563262');
      expect(c.comercio, 'mundototal');
    });

    test('la versión llega como número y se guarda como texto', () {
      // El servicio la manda como número. Lo único que importa es comparar si
      // cambió, así que se normaliza a texto en vez de arrastrar dos tipos.
      final c = AkPushConfig.fromJson(delServicio);
      expect(c.version, '1');
    });

    test('sobrevive a la ida y vuelta del guardado', () {
      // Lo que se guarda tiene que poder releerse con el mismo fromJson que lo
      // que llega por la red: dos formas distintas serían dos maneras de
      // romperse.
      final ida = AkPushConfig.fromJson(delServicio);
      final vuelta = AkPushConfig.fromJson(ida.toJson());
      expect(vuelta.appId, ida.appId);
      expect(vuelta.version, ida.version);
      expect(vuelta.comercio, ida.comercio);
    });

    test('una versión distinta se distingue — es lo que evita el teléfono mudo', () {
      final a = AkPushConfig.fromJson(delServicio);
      final b = AkPushConfig.fromJson({...delServicio, 'version': 2});
      expect(a.version == b.version, isFalse);
    });

    test('traduce a las opciones que espera Firebase', () {
      final o = AkPushConfig.fromJson(delServicio).toFirebaseOptions();
      expect(o.projectId, 'mundototal-72162');
      expect(o.appId, '1:859769563262:android:69c967f8f8d0a8c516902f');
    });
  });

  group('AccionDePush', () {
    test('los cinco valores son los que el servicio espera', () {
      expect(AccionDePush.delivered.valor, 'DELIVERED');
      expect(AccionDePush.viewed.valor, 'VIEWED');
      expect(AccionDePush.opened.valor, 'OPENED');
      expect(AccionDePush.dismissed.valor, 'DISMISSED');
      expect(AccionDePush.expired.valor, 'EXPIRED');
    });
  });
}
