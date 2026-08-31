import 'dart:convert';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'remote_config.dart';

/// Cliente de las rutas del servicio.
///
/// Todo lo que sale de acá lleva la llave **pública** (`akp_pub_…`). Es pública
/// por construcción: va dentro de la aplicación, y lo que va dentro de una
/// aplicación lo puede leer cualquiera que la descomprima. Por eso solo permite
/// pedir la configuración, dar de alta el dispositivo que la presenta, y
/// reportar qué pasó con un aviso. **Enviar necesita la otra llave, que vive en
/// el servidor del comercio y nunca llega acá.**
class AkPushApi {
  AkPushApi({
    required this.apiKey,
    required this.baseUrl,
    http.Client? cliente,
    this.timeout = const Duration(seconds: 10),
  }) : _cliente = cliente ?? http.Client();

  /// Quita el `/api/v1` del final si vino, y las barras sueltas.
  ///
  /// La consola le muestra al comercio la dirección **con** el sufijo, así que
  /// quien la siga al pie de la letra la va a pegar completa — y el paquete lo
  /// agrega por su cuenta. Sin esto la petición sale a `/api/v1/api/v1/…`, el
  /// servidor contesta su 404 genérico, y el error que ve quien integra no se
  /// parece en nada a «el prefijo está dos veces».
  static String normalizarUrl(String url) => url
      .replaceAll(RegExp(r'/+$'), '')
      .replaceAll(RegExp(r'/api/v1$'), '');

  final String apiKey;

  /// La dirección del servicio, **sin** el `/api/v1` final: el paquete lo
  /// agrega.
  ///
  /// Se acepta igual con el sufijo, porque la consola se lo muestra así al
  /// comercio y quien la siga al pie de la letra lo va a pegar completo. Sin
  /// esta normalización la petición sale a `/api/v1/api/v1/…`, el servidor
  /// contesta su 404 genérico, y el error que ve quien integra no se parece en
  /// nada a «la dirección tiene el prefijo dos veces».
  final String baseUrl;

  final Duration timeout;
  final http.Client _cliente;

  Map<String, String> get _cabeceras => {
        'content-type': 'application/json',
        // El comercio NO se declara: sale de la llave, del lado del servicio.
        // Declararlo repitiendo lo que el servicio contestó no comprueba nada, y
        // pedirlo por configuración es pedir un dato que el sistema ya sabe.
        'authorization': 'Bearer $apiKey',
      };

  /// Pide la configuración que le toca a esta aplicación.
  ///
  /// [identificadorDePaquete] no es opcional y no es burocracia: es lo que
  /// permite al servidor verificar que la configuración que va a entregar
  /// corresponde a ESTA aplicación. Si no coincidieran, la aplicación
  /// inicializaría Firebase, pediría su token y no lo obtendría —o lo obtendría
  /// y no le llegaría nada— sin ninguna excepción ni registro. Un 409 explícito
  /// es infinitamente más barato de diagnosticar que una aplicación muda.
  Future<AkPushConfig> obtenerConfig(String identificadorDePaquete) async {
    final uri = Uri.parse('$baseUrl/api/v1/configuracion')
        .replace(queryParameters: {'paquete': identificadorDePaquete});

    final json = await _pedir(() => _cliente.get(uri, headers: _cabeceras));
    return AkPushConfig.fromJson(json);
  }

  /// Da de alta este dispositivo para esta persona.
  Future<void> registrarDispositivo({
    required String userId,
    required String token,
    required String plataforma,
    String? identity,
    String? identityHash,
    Map<String, dynamic>? deviceInfo,
    bool permisoConcedido = true,
    String? estadoDelPermiso,
    DateTime? sePreguntoEl,
    Map<String, dynamic>? consentimiento,
  }) async {
    await _pedir(() => _cliente.post(
          Uri.parse('$baseUrl/api/v1/dispositivos'),
          headers: _cabeceras,
          body: jsonEncode({
            'userId': userId,
            'token': token,
            'platform': plataforma,
            // El servicio filtra por esto antes de enviar: un dispositivo sin
            // permiso concedido no recibe intentos, y por lo tanto no se cobra.
            'permissionsGranted': permisoConcedido,
            // 🔴 El booleano no alcanza, y ésta es la diferencia que el comercio
            // necesita ver: «nunca se le preguntó» y «se le preguntó y dijo que
            // no» son dos cosas distintas y piden acciones opuestas. A la
            // primera hay que preguntarle; a la segunda, dejarla en paz o
            // mandarla a los Ajustes.
            //
            // Y no se puede saber QUÉ contestó alguien a quien nunca se le
            // mostró la pregunta — pero sí se puede saber **que se le mostró**,
            // que es lo único que convierte el «no» en un número medible.
            if (estadoDelPermiso != null) 'estadoDelPermiso': estadoDelPermiso,
            if (sePreguntoEl != null)
              'sePreguntoEl': sePreguntoEl.toUtc().toIso8601String(),
            // El rastro de las DOS preguntas. `punto` es el resumen que la
            // consola puede mostrar sin interpretar fechas: sin_preguntar,
            // dijo_ahora_no, esperando_al_sistema, acepto,
            // denego_en_el_sistema.
            if (consentimiento != null) 'consentimiento': consentimiento,
            if (identity != null) 'identity': identity,
            if (identityHash != null) 'identityHash': identityHash,
            if (deviceInfo != null) 'deviceInfo': deviceInfo,
          }),
        ));
  }

  /// Da de baja este dispositivo.
  ///
  /// Es lo que evita que un teléfono que cambia de manos —vendido, prestado,
  /// compartido en familia— siga recibiendo los avisos de la persona anterior.
  Future<void> darDeBaja({required String userId, required String token}) async {
    // Los dos identificadores van en la ruta, así que hay que escaparlos: un
    // token de FCM trae `:` y otros caracteres que sin escapar parten la ruta
    // en pedazos y producen un 404 que no tiene nada que ver con la baja.
    final uri = Uri.parse(
      '$baseUrl/api/v1/dispositivos/'
      '${Uri.encodeComponent(userId)}/${Uri.encodeComponent(token)}',
    );
    await _pedir(() => _cliente.delete(uri, headers: _cabeceras));
  }

  /// Reporta qué pasó con un aviso. Es «lo mejor que se pueda»: un fallo acá
  /// nunca debe llegar a la persona que usa la aplicación.
  Future<void> reportarEvento({
    required String pushLogId,
    required String accion,
    String? estadoApp,
  }) async {
    try {
      await _pedir(() => _cliente.post(
            Uri.parse('$baseUrl/api/v1/interacciones'),
            headers: _cabeceras,
            body: jsonEncode({
              'pushLogId': pushLogId,
              'accion': accion,
              if (estadoApp != null) 'appState': estadoApp,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            }),
          ));
    } catch (_) {
      // Silencio a propósito: la medición no puede cambiar el comportamiento
      // de la aplicación. Un evento perdido cuesta un dato; un error mostrado
      // por una medición cuesta la confianza en la aplicación.
    }
  }

  Future<Map<String, dynamic>> _pedir(
    Future<http.Response> Function() peticion,
  ) async {
    http.Response respuesta;
    try {
      respuesta = await peticion().timeout(timeout);
    } catch (e) {
      throw AkPushError(
        AkPushErrorCode.network,
        'No se pudo contactar el servicio',
        details: e.toString(),
      );
    }

    Map<String, dynamic> json;
    try {
      json = respuesta.body.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(respuesta.body) as Map).cast<String, dynamic>();
    } catch (_) {
      throw AkPushError(
        AkPushErrorCode.unknown,
        'El servicio devolvió una respuesta que no se pudo leer',
      );
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300 &&
        json['ok'] != false) {
      return json;
    }

    // El servicio contesta `{ ok:false, error?, message }`: `error` sólo viene
    // en los rechazos de credencial, y `message` siempre.
    final mensaje = json['message'] as String? ??
        json['error'] as String? ??
        'Error ${respuesta.statusCode}';
    final detalle = json['error'] as String?;

    final codigo = switch (respuesta.statusCode) {
      401 || 403 => AkPushErrorCode.unauthorized,
      // 🔴 Hay DOS clases de 404 y confundirlas manda a buscar en el lugar
      // equivocado.
      //
      // El del servicio —«este paquete no está registrado en tu comercio»—
      // trae `ok:false` y un `message` que lo explica: ése sí es appMismatch.
      //
      // El OTRO es el 404 genérico del servidor cuando la ruta no existe, y
      // casi siempre significa que la dirección está mal configurada. Decirle a
      // quien integra que «la app no coincide con la registrada» cuando lo que
      // pasa es que la URL tiene el prefijo dos veces le hace revisar el
      // registro del paquete durante una hora.
      404 => json['ok'] == false
          ? AkPushErrorCode.appMismatch
          : AkPushErrorCode.rutaNoEncontrada,
      502 || 503 => AkPushErrorCode.serviceUnavailable,
      _ => AkPushErrorCode.unknown,
    };

    throw AkPushError(codigo, mensaje, details: detalle);
  }
}
