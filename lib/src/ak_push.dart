import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';
import 'device_info.dart';
import 'errors.dart';
import 'presenter.dart';
import 'push_message.dart';
import 'remote_config.dart';

/// Manejador de segundo plano.
///
/// Tiene que ser una función de nivel superior con `@pragma('vm:entry-point')`
/// para sobrevivir al recorte del árbol y poder correr en su propio aislado
/// cuando la aplicación está en segundo plano o cerrada.
///
/// Está vacío a propósito: el sistema operativo dibuja el aviso por su cuenta.
/// Medir la ENTREGA acá exigiría un cliente HTTP y una credencial propios
/// dentro del aislado, donde no hay acceso a nada de la aplicación. Queda
/// pendiente, y **mientras tanto la entrega en segundo plano no se cuenta** —
/// que es el caso más común. Es un límite conocido, no un descuido.
@pragma('vm:entry-point')
Future<void> manejadorDeSegundoPlano(RemoteMessage mensaje) async {}

/// Recibir notificaciones push con una llave y una línea.
///
/// ```dart
/// await AkPush.init(apiKey: 'akp_...');
/// await AkPush.identify(userId: 'u_123');
/// ```
///
/// No se pega ningún archivo de configuración en el proyecto: la cuenta de
/// Google la sirve el servidor en cada arranque. Eso es lo que permite mover un
/// comercio de una cuenta a otra sin publicar una versión nueva.
///
/// ## Es dueño de la app de Firebase por defecto
///
/// `FirebaseMessaging` solo trabaja con la app **por defecto** de Firebase — no
/// hay API pública para usar una con nombre. Así que este paquete la
/// inicializa. Si la aplicación ya inicializó Firebase por su cuenta con otra
/// configuración, se avisa con un error claro en vez de trabajar con una cuenta
/// que no es la que el servidor asignó.
class AkPush {
  AkPush._();

  static final AkPush _yo = AkPush._();

  AkPushApi? _api;
  AkPushConfig? _config;
  final ConfigStore _almacen = ConfigStore();

  String? _token;
  String? _userId;
  bool _permisoConcedido = false;

  final StreamController<PushMessage> _recibidos =
      StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> _tocados =
      StreamController<PushMessage>.broadcast();

  final Set<String> _toquesYaVistos = <String>{};
  final List<StreamSubscription<dynamic>> _suscripciones = [];

  // ── Lo que la aplicación consume ────────────────────────────────────────

  /// Avisos que llegaron con la aplicación abierta.
  static Stream<PushMessage> get onMessage => _yo._recibidos.stream;

  /// Avisos que la persona tocó, vengan de donde vengan.
  static Stream<PushMessage> get onNotificationTap => _yo._tocados.stream;

  /// Si hay permiso de notificaciones. `false` no es un fallo: es una respuesta.
  static bool get tienePermiso => _yo._permisoConcedido;

  /// El token de este dispositivo, si ya se obtuvo.
  static String? get token => _yo._token;

  // ── Arranque ────────────────────────────────────────────────────────────

  /// Pide la configuración, conecta con Firebase, pide permiso y consigue la
  /// dirección de este teléfono.
  ///
  /// No registra a nadie todavía: para eso está [identify], que se llama cuando
  /// la persona inicia sesión.
  static Future<void> init({
    required String apiKey,
    String? baseUrl,
  }) =>
      _yo._init(apiKey: apiKey, baseUrl: baseUrl);

  Future<void> _init({required String apiKey, String? baseUrl}) async {
    final datos = await DatosDelDispositivo.recolectar();

    _api = AkPushApi(
      apiKey: apiKey,
      baseUrl: (baseUrl ?? 'https://api-push.creditotal.online')
          .replaceAll(RegExp(r'/+$'), ''),
    );

    final cacheada = await _almacen.leer();
    final config = await _resolverConfig(datos.identificadorDePaquete, cacheada);

    // 🔴 La cuenta cambió. Un token de FCM solo vale dentro del proyecto que lo
    // emitió, así que el que tenemos guardado ya no sirve para nada — y si no
    // lo tiramos, este teléfono queda mudo para siempre sin ningún error
    // visible. Es el fallo más caro de todo el mecanismo de configuración
    // remota, y el único momento en que se puede atajar es acá.
    final cambio = cacheada != null && cacheada.version != config.version;
    if (cambio) {
      await _descartarCuentaAnterior();
    }

    await _iniciarFirebase(config);
    _config = config;
    await _almacen.guardar(config);

    await _pedirPermiso();
    await _obtenerToken(descartarElViejo: cambio);

    await Presentador.instancia.iniciar();
    _escuchar();
    await _procesarArranqueEnFrio();
  }

  /// La configuración viene de la red; si no hay red, de lo último que se supo.
  ///
  /// Solo la primerísima instalación depende de tener señal. De ahí en adelante
  /// el teléfono arranca con lo que guardó, aunque esté sin conexión.
  Future<AkPushConfig> _resolverConfig(
    String identificadorDePaquete,
    AkPushConfig? cacheada,
  ) async {
    try {
      return await _api!.obtenerConfig(identificadorDePaquete);
    } on AkPushError catch (e) {
      // Un desacuerdo entre la aplicación y lo registrado NO se resuelve con la
      // caché: seguiría con una configuración que el servidor ya dijo que no
      // corresponde. Se propaga.
      if (e.code == AkPushErrorCode.appMismatch ||
          e.code == AkPushErrorCode.unauthorized) {
        rethrow;
      }
      if (cacheada != null) return cacheada;
      rethrow;
    }
  }

  Future<void> _descartarCuentaAnterior() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Si no se puede borrar el token viejo, igual hay que seguir: el nuevo
      // proyecto va a emitir otro.
    }
    for (final app in List<FirebaseApp>.from(Firebase.apps)) {
      try {
        await app.delete();
      } catch (_) {
        // Una app que no se puede borrar no debe impedir el arranque.
      }
    }
    await _almacen.olvidarSesion();
  }

  Future<void> _iniciarFirebase(AkPushConfig config) async {
    final opciones = config.toFirebaseOptions();

    final existente = Firebase.apps
        .where((a) => a.name == defaultFirebaseAppName)
        .firstOrNull;

    if (existente != null) {
      if (existente.options.appId == opciones.appId) return;
      throw AkPushError(
        AkPushErrorCode.firebaseInit,
        'La aplicación ya inicializó Firebase con otra cuenta',
        details:
            'AkPush necesita ser quien inicialice Firebase, porque el transporte de '
            'notificaciones solo trabaja con la app por defecto. Quitá tu propia '
            'llamada a Firebase.initializeApp() y dejá que AkPush.init() la haga.',
      );
    }

    try {
      await Firebase.initializeApp(options: opciones);
    } catch (e) {
      throw AkPushError(
        AkPushErrorCode.firebaseInit,
        'No se pudo conectar con la cuenta de Google asignada',
        details: e.toString(),
      );
    }
  }

  Future<void> _pedirPermiso() async {
    try {
      final ajustes = await FirebaseMessaging.instance.requestPermission();
      _permisoConcedido =
          ajustes.authorizationStatus == AuthorizationStatus.authorized ||
              ajustes.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      _permisoConcedido = false;
    }
  }

  Future<void> _obtenerToken({bool descartarElViejo = false}) async {
    try {
      FirebaseMessaging.onBackgroundMessage(manejadorDeSegundoPlano);
      if (descartarElViejo) {
        await FirebaseMessaging.instance.deleteToken();
      }
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) await _almacen.guardarToken(_token!);
    } catch (_) {
      _token = null;
    }
  }

  // ── Quién es la persona ─────────────────────────────────────────────────

  /// Ata este teléfono a una persona. Se llama cuando inicia sesión.
  ///
  /// [identityHash] es la firma que calcula el backend del comercio sobre el
  /// [userId]. Hoy el servidor todavía no la verifica; el parámetro está desde
  /// la primera versión para que activarla después no rompa a nadie.
  static Future<void> identify({
    required String userId,
    String? identityHash,
    String? identity,
  }) =>
      _yo._identify(
        userId: userId,
        identityHash: identityHash,
        identity: identity,
      );

  Future<void> _identify({
    required String userId,
    String? identityHash,
    String? identity,
  }) async {
    _asegurarIniciado();

    if (_token == null) {
      // Sin permiso no hay token, y sin token no hay nada que registrar. No es
      // un error: es el resultado de que la persona dijo que no.
      await _almacen.guardarUsuario(userId);
      _userId = userId;
      return;
    }

    final datos = await DatosDelDispositivo.recolectar();

    await _api!.registrarDispositivo(
      userId: userId,
      token: _token!,
      plataforma: datos.plataforma,
      identity: identity,
      identityHash: identityHash,
      deviceInfo: datos.toJson(),
      // El servicio filtra por esto antes de enviar. Reportar `true` cuando la
      // persona dijo que no significa pagar envíos a un teléfono que no va a
      // mostrar nada, e inflar la tasa de entrega con ellos.
      permisoConcedido: _permisoConcedido,
    );

    _userId = userId;
    await _almacen.guardarUsuario(userId);
  }

  /// Desata este teléfono de la persona que estaba usándolo.
  ///
  /// Llamarlo al cerrar sesión no es opcional: sin esto, un teléfono que cambia
  /// de manos —vendido, prestado, compartido en familia— sigue recibiendo los
  /// avisos de la persona anterior.
  static Future<void> logout() => _yo._logout();

  Future<void> _logout() async {
    final userId = _userId ?? await _almacen.leerUsuario();
    final token = _token ?? await _almacen.leerToken();

    if (userId != null && token != null && _api != null) {
      try {
        await _api!.darDeBaja(userId: userId, token: token);
      } catch (_) {
        // Si la baja no llega, se intenta de nuevo en el próximo cierre. No se
        // le muestra nada a nadie.
      }
    }

    _userId = null;
    await _almacen.olvidarSesion();
    await Presentador.instancia.retirarTodos();
  }

  /// Reporta una acción que sólo la aplicación puede saber.
  ///
  /// [AccionDePush.delivered] y [AccionDePush.opened] las reporta el paquete
  /// solo. Las otras tres —vista, descartada, caducada— dependen de cómo esté
  /// hecha la aplicación, así que las reporta quien la escribe.
  static Future<void> reportar(
    PushMessage mensaje,
    AccionDePush accion,
  ) async {
    final id = mensaje.pushLogId;
    if (id == null) return;
    await _yo._api?.reportarEvento(pushLogId: id, accion: accion.valor);
  }

  // ── Lo que llega ────────────────────────────────────────────────────────

  void _escuchar() {
    _suscripciones.add(
      FirebaseMessaging.onMessage.listen(_alLlegarEnPrimerPlano),
    );
    _suscripciones.add(
      FirebaseMessaging.onMessageOpenedApp.listen(_alTocar),
    );
    // El toque sobre el aviso que dibujó ESTE paquete no pasa por FCM. Sin esta
    // línea, tocar una notificación con la aplicación abierta no hace nada.
    _suscripciones.add(
      Presentador.instancia.alTocar.listen(_alTocar),
    );
    _suscripciones.add(
      FirebaseMessaging.instance.onTokenRefresh.listen(_alRotarElToken),
    );
  }

  Future<void> _alLlegarEnPrimerPlano(RemoteMessage crudo) async {
    final mensaje = _traducir(crudo);
    _recibidos.add(mensaje);

    // FCM no dibuja nada con la aplicación abierta. Si esto no corre, el aviso
    // no se ve y nada lo reporta.
    await Presentador.instancia.mostrar(mensaje);

    final id = mensaje.pushLogId;
    if (id != null) {
      await _api?.reportarEvento(
        pushLogId: id,
        accion: AccionDePush.delivered.valor,
        estadoApp: 'FOREGROUND',
      );
    }
  }

  Future<void> _alTocar(dynamic entrada) async {
    final mensaje = entrada is RemoteMessage ? _traducir(entrada) : entrada as PushMessage;

    // El mismo toque llega dos veces con la aplicación cerrada: el sistema lo
    // reporta por getInitialMessage Y por onMessageOpenedApp, con el mismo id.
    // Sin esto se mide doble y se abre dos veces.
    final id = mensaje.messageId;
    if (id != null && !_toquesYaVistos.add(id)) return;

    _tocados.add(mensaje);
    await Presentador.instancia.retirar(mensaje);

    final log = mensaje.pushLogId;
    if (log != null) {
      await _api?.reportarEvento(
        pushLogId: log,
        accion: AccionDePush.opened.valor,
        estadoApp: 'BACKGROUND',
      );
    }
  }

  Future<void> _alRotarElToken(String nuevo) async {
    _token = nuevo;
    await _almacen.guardarToken(nuevo);

    // FCM rota el token solo, y el registro viejo deja de entregar en ese
    // momento. Si hay una persona atada a este teléfono, hay que volver a
    // registrarlo ya: esperar al próximo inicio de sesión deja al teléfono
    // silenciosamente inalcanzable mientras tanto.
    final userId = _userId ?? await _almacen.leerUsuario();
    if (userId == null) return;

    final datos = await DatosDelDispositivo.recolectar();
    try {
      await _api?.registrarDispositivo(
        userId: userId,
        token: nuevo,
        plataforma: datos.plataforma,
        deviceInfo: datos.toJson(),
        permisoConcedido: _permisoConcedido,
      );
    } catch (_) {
      // Se reintenta en el próximo identify().
    }
  }

  Future<void> _procesarArranqueEnFrio() async {
    try {
      final inicial = await FirebaseMessaging.instance.getInitialMessage();
      if (inicial != null) await _alTocar(inicial);
    } catch (_) {
      // Un arranque en frío sin mensaje inicial es lo normal.
    }
  }

  PushMessage _traducir(RemoteMessage m) => PushMessage(
        data: m.data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
        title: m.notification?.title,
        body: m.notification?.body,
        messageId: m.messageId,
      );

  void _asegurarIniciado() {
    if (_api == null || _config == null) {
      throw AkPushError(
        AkPushErrorCode.notInitialized,
        'AkPush todavía no terminó de iniciarse',
        details:
            'AkPush.init() es asíncrono. Esperá a que termine antes de llamar a '
            'identify() o logout() — por ejemplo, deshabilitá el botón de inicio '
            'de sesión hasta que init() resuelva.',
      );
    }
  }
}

extension _Primero<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
