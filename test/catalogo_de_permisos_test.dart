/// PRUEBAS DEL CATÁLOGO DE PERMISOS.
///
/// 🔴 No prueban código: prueban que las FICHAS estén bien escritas. Es a propósito.
/// El muro compara el manifiesto contra este catálogo, así que una ficha mal cargada no
/// hace fallar nada — hace que el muro deje pasar algo, o que el manual mienta. Los dos
/// fallos son silenciosos, y estas pruebas son lo único que los vuelve ruidosos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hz_collection_sdk/src/permisologia/catalogo_de_permisos.dart';
import 'package:hz_collection_sdk/src/permisologia/rubros.dart';

void main() {
  puertaDeDatoSensible();
  group('el catálogo está bien formado', () {
    test('ningún permiso está declarado dos veces', () {
      final nombres = catalogoDePermisos.map((p) => p.nombre).toList();
      expect(nombres.toSet().length, nombres.length,
          reason: 'Hay un permiso repetido. Dos fichas del mismo permiso significa que '
              'una de las dos está mintiendo, y nadie sabe cuál lee el muro.');
    });

    test('ninguna ficha queda sin módulo', () {
      for (final p in catalogoDePermisos) {
        expect(p.modulo.trim(), isNotEmpty,
            reason: '${p.nombre} no dice qué módulo lo necesita. Un permiso sin módulo '
                'es un permiso que alguien arrastró sin querer.');
      }
    });

    test('toda ficha explica para qué sirve, en una frase de verdad', () {
      for (final p in catalogoDePermisos) {
        // El texto se muestra tal cual en el manual y alimenta el modal. Cinco palabras
        // sueltas no le sirven a nadie.
        expect(p.paraQue.length, greaterThan(20),
            reason: '${p.nombre} tiene una explicación demasiado corta para servirle a '
                'alguien que la lee en el teléfono.');
        expect(p.paraQue.trim().endsWith('.'), isTrue,
            reason: '${p.nombre}: la explicación se muestra como frase, así que termina '
                'en punto.');
      }
    });

    test('toda ficha dice quién lo aporta', () {
      for (final p in catalogoDePermisos) {
        expect(p.loAporta.trim(), isNotEmpty,
            reason: '${p.nombre} no dice quién lo mete en el manifiesto, y de eso '
                'depende si el problema es nuestro o del comercio.');
      }
    });

    test('toda ficha contesta qué se declara en Data Safety', () {
      for (final p in catalogoDePermisos) {
        expect(p.dataSafety.trim(), isNotEmpty,
            reason: '${p.nombre} no dice qué se declara en el formulario de Play. Ese '
                'formulario lo llena una persona, y si acá no está, lo inventa.');
      }
    });

    test('toda ficha dice cuánto se retiene lo que trae', () {
      for (final p in catalogoDePermisos) {
        expect(p.retencion.enPalabras.trim(), isNotEmpty,
            reason: '${p.nombre} no dice cuánto se guarda su dato. Sin eso no se puede '
                'contestar un pedido de borrado ni escribir la política de retención.');
      }
    });
  });

  group('las reglas que no se negocian', () {
    test('ningún permiso está a la vez declarado y prohibido', () {
      for (final p in catalogoDePermisos) {
        expect(permisosProhibidos.containsKey(p.nombre), isFalse,
            reason: '${p.nombre} está en las dos listas. El muro lo rechazaría igual '
                '—prohibido gana— pero la contradicción significa que alguien declaró '
                'algo que no se puede pedir.');
      }
    });

    test('todo prohibido explica POR QUÉ, no sólo que no', () {
      permisosProhibidos.forEach((nombre, motivo) {
        expect(motivo.length, greaterThan(40),
            reason: '$nombre está prohibido sin un motivo que sirva. El muro muestra ese '
                'texto cuando falla, y "no se puede" no le dice a nadie qué hacer.');
      });
    });

    test('los que asustan y los de revisión manual no entran solos', () {
      // 🔴 Un permiso de nivel 2 o 3 lo tiene que declarar la APLICACIÓN, nunca una
      // dependencia nuestra. Es la regla que evita el error de CredoLab: que el paquete
      // le llene la ficha de Play a alguien que ni lo pidió.
      for (final p in catalogoDePermisos) {
        if (p.nivel == Nivel.asusta || p.nivel == Nivel.revisionManual) {
          expect(p.esNuestro, isFalse,
              reason: '${p.nombre} es de nivel alto y lo aporta ${p.loAporta}. Un '
                  'permiso que asusta en la ficha de la tienda lo declara la aplicación '
                  'que decide asumirlo, no un paquete que se instaló de arrastre.');
        }
      }
    });

    test('lo que se pide con consentimiento tiene retención acotada', () {
      // Si la base es el consentimiento, revocar obliga a borrar. Un dato "para siempre"
      // con base en consentimiento es una promesa que no se puede cumplir.
      for (final p in catalogoDePermisos) {
        if (p.base != BaseLegal.consentimiento) continue;
        final acotada = p.retencion.dias != null ||
            p.retencion.enPalabras.contains('mientras');
        expect(acotada, isTrue,
            reason: '${p.nombre} se pide con consentimiento pero no dice hasta cuándo se '
                'guarda. Revocar tiene que poder significar algo.');
      }
    });

    test('las cuatro señales que sacan la app de la tienda están prohibidas', () {
      // Salen de la política de Servicios Financieros de Google Play. Si alguien las
      // saca de la lista, esta prueba falla — que es el punto.
      for (final p in const [
        'android.permission.READ_CONTACTS',
        'android.permission.READ_SMS',
        'android.permission.READ_MEDIA_IMAGES',
        'android.permission.ACCESS_FINE_LOCATION',
      ]) {
        expect(permisosProhibidos.containsKey(p), isTrue,
            reason: '$p salió de la lista de prohibidos. Está vetado por la política de '
                'préstamos personales de Google Play desde el 31 de mayo de 2023.');
      }
    });
  });

  group('lo que el muro necesita para funcionar', () {
    test('fichaDe encuentra lo declarado y no inventa lo que no está', () {
      expect(fichaDe('android.permission.INTERNET'), isNotNull);
      expect(fichaDe('android.permission.READ_CONTACTS'), isNull);
      expect(fichaDe('cualquier.cosa'), isNull);
    });

    test('permisosDeclarados coincide con el catálogo', () {
      expect(permisosDeclarados.length, catalogoDePermisos.length);
    });
  });
}

/// Pruebas de la puerta cerrada. Están aparte a propósito: no comprueban el catálogo,
/// comprueban una DECISIÓN — y una decisión que sólo vive en una constante se cambia sin
/// que nadie lo note. Con esto, abrirla hace fallar una prueba con nombre propio, que es
/// la forma de que el cambio se discuta en vez de colarse.
void puertaDeDatoSensible() {
  group('la puerta de datos sensibles', () {
    test('está cerrada', () {
      expect(sistemaAdmiteDatoSensible, isFalse,
          reason: 'Alguien abrió la puerta de datos sensibles. Antes de abrirla hacen '
              'falta consentimiento explícito por categoría, borrado a pedido y '
              'registro de accesos — nada de eso existe todavía.');
    });

    test('con la puerta cerrada, lo sensible queda prohibido pase lo que pase', () {
      expect(conLaPuertaCerrada(Estado.libre, [DatoSensible.biometria]),
          Estado.prohibido);
      expect(conLaPuertaCerrada(Estado.condicionado, [DatoSensible.salud]),
          Estado.prohibido);
    });

    test('lo que no es sensible pasa sin tocar', () {
      expect(conLaPuertaCerrada(Estado.libre, const []), Estado.libre);
      expect(conLaPuertaCerrada(Estado.condicionado, const []), Estado.condicionado);
    });

    test('sin rubro declarado se resuelve al caso más restrictivo', () {
      final d = Disponibilidad.condicionadoSalvo(
        [Rubro.prestamoPersonal],
        porQue: 'de prueba',
      );
      expect(d.para(Rubro.sinDeclarar), Estado.prohibido,
          reason: 'No declarar el rubro no puede salir más barato que declararlo.');
      expect(d.para(Rubro.seguros), Estado.condicionado);
      expect(d.para(Rubro.prestamoPersonal), Estado.prohibido);
    });
  });
}
