import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  factory AkPushConfig.fromJson(Map<String, dynamic> json) {
    final fb = (json['firebase'] as Map).cast<String, dynamic>();
    return AkPushConfig(
      projectId: fb['projectId'] as String,
      appId: fb['appId'] as String,
      apiKey: fb['apiKey'] as String,
      messagingSenderId: fb['messagingSenderId'] as String,
      version: json['version'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'firebase': {
          'projectId': projectId,
          'appId': appId,
          'apiKey': apiKey,
          'messagingSenderId': messagingSenderId,
        },
        'version': version,
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

  Future<void> olvidarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveToken);
    await prefs.remove(_claveUsuario);
  }
}
