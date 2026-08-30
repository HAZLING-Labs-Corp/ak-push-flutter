import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'consentimiento.dart';
import 'politica.dart';

/// La configuración de Firebase que este comercio tiene asignada hoy.
///
/// No viene de un archivo pegado en el proyecto: la sirve el servidor en cada
/// arranque. Ése es el mecanismo que permite mover un comercio de una cuenta de
/// Google a otra **sin publicar una versión nueva** de la aplicación — que es la
/// operación que hoy obliga a recompilar, subir a las tiendas, esperar la
/// revisión de Apple y después esperar a que cada persona actualice.
class AkPushConfig {
  const AkPushConfig({
    required this.projectId,
    required this.appId,
    required this.apiKey,
    required this.messagingSenderId,
    required this.version,
    this.comercio,
    this.politica = PoliticaDeNotificaciones.comoEstabaAntes,
    this.trajoPolitica = false,
  });

  final String projectId;
  final String appId;
  final String apiKey;
  final String messagingSenderId;

  /// Huella de esta configuración.
  ///
  /// Es lo que deja detectar que el comercio cambió de cuenta. Sin ella no hay
  /// forma de saberlo, y un cambio de cuenta dejaría mudos a todos los
  /// teléfonos **sin ningún error visible**: los tokens viejos pertenecen al
  /// proyecto anterior y el nuevo no los reconoce.
  final String version;

  FirebaseOptions toFirebaseOptions() => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
      );

  /// El comercio al que pertenece esta configuración. Sirve para diagnosticar,
  /// no para decidir: quien manda es la llave.
  final String? comercio;

  /// Lo que el comercio configuró sobre cuándo y cómo pedir el permiso.
  ///
  /// Si el servicio todavía no manda el campo, es la política de siempre: pedir
  /// en el arranque, sin pregunta blanda. Nadie ve un cambio hasta que el
  /// comercio configure algo.
  final PoliticaDeNotificaciones politica;

  /// Si la política vino del servidor o es la de siempre porque el campo todavía
  /// no existe. Sirve para no pisar la que declaró la aplicación.
  final bool trajoPolitica;

  factory AkPushConfig.fromJson(Map<String, dynamic> json) {
    final fb = (json['firebase'] as Map).cast<String, dynamic>();
    return AkPushConfig(
      projectId: fb['projectId'] as String,
      appId: fb['appId'] as String,
      apiKey: fb['apiKey'] as String,
      messagingSenderId: fb['messagingSenderId'] as String,
      // El servicio la manda como número; acá se guarda como texto porque lo
      // único que importa es comparar si cambió, no cuánto vale.
      version: '${json['version'] ?? ''}',
      comercio: json['comercio'] as String?,
      trajoPolitica: json['politica'] is Map,
      politica: PoliticaDeNotificaciones.fromJson(
        json['politica'] is Map
            ? (json['politica'] as Map).cast<String, dynamic>()
            : null,
      ),
    );
  }

  /// Se guarda con la MISMA forma que devuelve el servicio, para que
  /// [fromJson] sirva igual para lo que llega por la red y para lo que se leyó
  /// del disco. Dos formas distintas serían dos maneras de romperse.
  Map<String, dynamic> toJson() => {
        'firebase': {
          'projectId': projectId,
          'appId': appId,
          'apiKey': apiKey,
          'messagingSenderId': messagingSenderId,
        },
        'version': version,
        if (comercio != null) 'comercio': comercio,
        'politica': politica.toJson(),
      };
}

/// Guarda y recupera la última configuración conocida.
///
/// Sin esto, un primer arranque sin señal deja al teléfono sin registrar y sin
/// forma de recuperarse hasta la próxima vez que abra con conexión. Con esto,
/// **solo la primerísima instalación depende de tener red**.
class ConfigStore {
  static const _claveConfig = 'akpush.config';
  static const _claveToken = 'akpush.token';
  static const _claveUsuario = 'akpush.userId';
  static const _claveHuella = 'akpush.huella';
  static const _clavePregunta = 'akpush.ultimaPregunta';
  static const _claveConsentimiento = 'akpush.consentimiento';

  Future<AkPushConfig?> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_claveConfig);
    if (crudo == null) return null;
    try {
      return AkPushConfig.fromJson(jsonDecode(crudo) as Map<String, dynamic>);
    } catch (_) {
      // Una configuración guardada que ya no se puede leer es peor que
      // ninguna: se descarta en silencio y se pide de nuevo.
      return null;
    }
  }

  Future<void> guardar(AkPushConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveConfig, jsonEncode(config.toJson()));
  }

  Future<String?> leerToken() async =>
      (await SharedPreferences.getInstance()).getString(_claveToken);

  Future<void> guardarToken(String token) async =>
      (await SharedPreferences.getInstance()).setString(_claveToken, token);

  Future<String?> leerUsuario() async =>
      (await SharedPreferences.getInstance()).getString(_claveUsuario);

  Future<void> guardarUsuario(String userId) async =>
      (await SharedPreferences.getInstance()).setString(_claveUsuario, userId);

  /// La huella del último registro. Ver [HuellaDelRegistro] en `sesion.dart`.
  Future<Map<String, dynamic>?> leerHuella() async {
    final crudo = (await SharedPreferences.getInstance()).getString(_claveHuella);
    if (crudo == null) return null;
    try {
      return (jsonDecode(crudo) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarHuella(Map<String, dynamic> h) async =>
      (await SharedPreferences.getInstance())
          .setString(_claveHuella, jsonEncode(h));

  /// Cuándo se le preguntó por última vez. Es lo que hace que a quien dijo
  /// «ahora no» no se le vuelva a preguntar al día siguiente — que es cómo se
  /// consigue una desinstalación.
  Future<void> anotarQueSePregunto() async =>
      (await SharedPreferences.getInstance())
          .setString(_clavePregunta, DateTime.now().toIso8601String());

  Future<bool> yaSePreguntoElPermiso() async =>
      (await SharedPreferences.getInstance()).getString(_clavePregunta) != null;

  /// Cuándo se le mostró la pregunta por última vez. Es lo que le permite al
  /// comercio distinguir a quien dijo que no de quien nunca fue preguntado.
  Future<DateTime?> cuandoSePregunto() async {
    final crudo =
        (await SharedPreferences.getInstance()).getString(_clavePregunta);
    return crudo == null ? null : DateTime.tryParse(crudo);
  }

  Future<Duration?> desdeLaUltimaPregunta() async {
    final crudo =
        (await SharedPreferences.getInstance()).getString(_clavePregunta);
    final cuando = crudo == null ? null : DateTime.tryParse(crudo);
    return cuando == null ? null : DateTime.now().difference(cuando);
  }

  /// Qué se le preguntó a esta persona y qué contestó. Sobrevive al cierre de
  /// sesión: el permiso es del TELÉFONO, no de quien entra.
  Future<Consentimiento> leerConsentimiento() async {
    final crudo =
        (await SharedPreferences.getInstance()).getString(_claveConsentimiento);
    if (crudo == null) return const Consentimiento();
    try {
      return Consentimiento.fromJson(
          (jsonDecode(crudo) as Map).cast<String, dynamic>());
    } catch (_) {
      return const Consentimiento();
    }
  }

  Future<void> guardarConsentimiento(Consentimiento c) async =>
      (await SharedPreferences.getInstance())
          .setString(_claveConsentimiento, jsonEncode(c.toJson()));

  Future<void> olvidarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveToken);
    await prefs.remove(_claveUsuario);
    // La huella se va con la sesión: era de esa persona, no de este teléfono.
    await prefs.remove(_claveHuella);
  }
}
