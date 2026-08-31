import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_client.dart';

/// DÓNDE ESTÁ LA PERSONA, CUANDO ELLA LO PERMITE
///
/// Sirve para dos cosas concretas: segmentar un envío por zona sin que el
/// comercio tenga que mandar la ciudad de cada quien, y ver por dónde anduvo.
///
/// ══ SÓLO APROXIMADA, Y ES UNA DECISIÓN ══
///
/// Se pide `Permission.locationWhenInUse`, que en Android es la aproximada.
/// La precisa la acepta ~25% de la gente contra ~40% la aproximada, y la de
/// segundo plano ~10% **más un video justificando el uso ante Google**, con
/// revisión manual que se rechaza seguido.
///
/// Decisión de Juan, 2026-08-31: *«lo que sea muy difícil de aceptar en esta
/// versión no lo hagan»*. Para saber en qué ciudad está alguien, la aproximada
/// alcanza y sobra.
///
/// ══ 🔴 NO SE PIDE JUNTO CON EL DE NOTIFICACIONES ══
///
/// Dos diálogos del sistema seguidos, apenas se abre la aplicación, es la forma
/// más rápida de que la persona diga que no a los dos. El de notificaciones es
/// el que hace falta para el producto; el de ubicación es opcional y mejora la
/// segmentación. Por eso este se pide **después**, y sólo si el comercio lo
/// activó.
///
/// ══ CADA CUÁNTO SE ACTUALIZA ══
///
/// Al abrir la aplicación, con un freno de [minimoEntreLecturas]. Continuo
/// gasta batería y hace que Android muestre el ícono de ubicación activa — que
/// es exactamente lo que lleva a la gente a revocar el permiso.
class Ubicacion {
  Ubicacion(this._api);

  final AkPushApi _api;

  /// Cada cuánto se vuelve a leer. Seis horas: suficiente para saber en qué
  /// ciudad está alguien, y poco suficiente para no aparecer en el uso de
  /// batería del teléfono.
  static const minimoEntreLecturas = Duration(hours: 6);

  DateTime? _ultimaLectura;

  /// ¿Ya está concedido?
  Future<bool> get concedido async =>
      await Permission.locationWhenInUse.isGranted;

  /// ¿Se puede todavía preguntar, o la persona ya dijo que no para siempre?
  ///
  /// La diferencia importa: a quien nunca se le preguntó hay que preguntarle;
  /// a quien lo denegó permanentemente sólo le queda los Ajustes, e insistir
  /// con un diálogo que el sistema ya no muestra no hace nada salvo confundir
  /// a quien programa.
  Future<bool> get sePuedePreguntar async {
    final s = await Permission.locationWhenInUse.status;
    return !s.isPermanentlyDenied && !s.isGranted;
  }

  /// Pide el permiso. Devuelve si quedó concedido.
  ///
  /// Se llama cuando la aplicación lo decide —después de explicar para qué
  /// sirve— y nunca en el arranque en frío.
  Future<bool> pedir() async {
    final s = await Permission.locationWhenInUse.request();
    return s.isGranted;
  }

  /// Lee la posición y la manda, si corresponde.
  ///
  /// No hace nada si no hay permiso o si se leyó hace poco. Devuelve si mandó
  /// algo, para que la aplicación pueda mostrarlo en su diagnóstico.
  ///
  /// 🔴 Nunca tumba nada: perder una posición cuesta un dato de segmentación;
  /// que falle el arranque de la aplicación cuesta que esa persona no reciba
  /// nada.
  Future<bool> reportarSiCorresponde(String userId, {bool forzar = false}) async {
    try {
      if (!await concedido) return false;

      final ahora = DateTime.now();
      if (!forzar &&
          _ultimaLectura != null &&
          ahora.difference(_ultimaLectura!) < minimoEntreLecturas) {
        return false;
      }

      final p = await _leer();
      if (p == null) return false;

      await _api.reportarUbicacion(userId: userId, posicion: p);
      _ultimaLectura = ahora;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lee la posición del sistema.
  ///
  /// 🔴 CON PRECISIÓN BAJA A PROPÓSITO. `LocationAccuracy.low` le pide al
  /// sistema la posición por antenas y wifi en vez de encender el GPS: llega en
  /// un segundo, no gasta batería y da unos cientos de metros — que para saber
  /// en qué ciudad y qué zona está alguien sobra. Pedir alta precisión enciende
  /// el GPS, tarda, y muestra el ícono de ubicación activa que es lo que lleva
  /// a la gente a revocar el permiso.
  ///
  /// Y con un tiempo máximo: sin él, en un lugar sin señal esto queda esperando
  /// para siempre y el arranque de la aplicación se cuelga con él.
  Future<Map<String, dynamic>?> _leer() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 12),
      ),
    );

    return {
      'lat': p.latitude,
      'lon': p.longitude,
      'precision': p.accuracy,
      // Se declara lo que se pidió, no lo que llegó: el sistema puede entregar
      // una posición más precisa si la persona ya se la había dado a la
      // aplicación por otro motivo, y decir «precisa» sobre algo que pedimos
      // aproximado sería afirmar de más.
      'exactitud': 'aproximada',
      'cuando': p.timestamp.toUtc().toIso8601String(),
    };
  }
}
