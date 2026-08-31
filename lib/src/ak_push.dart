import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show ValueListenable, VoidCallback;

import 'api_client.dart';
import 'decision_de_dibujo.dart';
import 'device_info.dart';
import 'diagnostico.dart';
import 'errors.dart';
import 'permiso.dart';
import 'consentimiento.dart';
import 'politica.dart';
import 'sesion.dart';
import 'presenter.dart';
import 'push_message.dart';
import 'remote_config.dart';
import 'ruta.dart';

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

  /// Lo que el comercio configuró. Hasta que el servicio sirva el campo, es la
  /// que reproduce el comportamiento de siempre.
  PoliticaDeNotificaciones _politica = PoliticaDeNotificaciones.comoEstabaAntes;

  /// La última vez que se registró, para no repetir una llamada que no cambia
  /// nada — y para que la huella venza y se revalide sola.
  HuellaDelRegistro? _huella;

  /// Qué se le preguntó y qué contestó. Se lee del disco al arrancar y
  /// sobrevive al cierre de sesión: el permiso es del teléfono, no de quien entra.
  Consentimiento _consentimiento = const Consentimiento();

  AkPushApi? _api;
  AkPushConfig? _config;
  final ConfigStore _almacen = ConfigStore();

  /// Una sola instancia para todo el paquete: cachea el nivel de Android que
  /// hace falta para saber si un «no» todavía admite otro diálogo, y ese dato
  /// se consulta en cada vuelta del segundo plano.
  final GestorDePermiso _permiso = GestorDePermiso();

  /// El portero no depende de nada del arranque, así que se construye ya: el
  /// callback se puede registrar antes de `init()` sin que nada lo pise.
  final PorteroDeDibujo _portero = PorteroDeDibujo();

  String? _token;
  String? _userId;
  EstadoDelPermiso _estado = EstadoDelPermiso.sinPreguntar;

  // ── Lo que el diagnóstico necesita saber y nadie más guardaba ────────────
  //
  // Son cinco datos que sólo la fachada puede conocer —de dónde vino la
  // configuración de ESTE arranque, cuándo se consiguió el token, si el alta
  // LLEGÓ al servidor y qué error se tragó el SDK para no romperle el arranque
  // a nadie—. Sin ellos, `diagnostico()` puede decir qué falta pero no por qué.

  bool _configDelServidor = false;
  DateTime? _tokenObtenidoEl;
  bool _registrado = false;
  DateTime? _registradoEl;
  AkPushError? _ultimoError;

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
  ///
  /// Sigue siendo un `bool` para no romper a quien ya lo consume, pero adentro
  /// ya no hay un `bool`: hay un [EstadoDelPermiso]. Quien tenga que decidir
  /// **qué ofrecerle a la persona** —volver a preguntar o mandarla a los
  /// Ajustes— necesita el estado entero, con [estadoDelPermiso].
  static bool get tienePermiso => _yo._estado.permiteRecibir;

  /// El token de este dispositivo, si ya se obtuvo.
  static String? get token => _yo._token;

  /// Deja que la aplicación decida si el aviso se dibuja. En `null` se dibuja
  /// todo, que es como venía siendo.
  ///
  /// Es asignable en cualquier momento, **incluso antes de [init]**: el portero
  /// no depende del arranque. Eso evita el error clásico de registrar el
  /// callback y que se pise al inicializar.
  ///
  /// La decisión afecta ÚNICAMENTE al dibujo: el evento `delivered` y
  /// [onMessage] ocurren igual, incluso con [DecisionDeDibujo.noMostrar].
  static DecidirDibujo? get alDecidirDibujo => _yo._portero.alDecidir;

  static set alDecidirDibujo(DecidirDibujo? decidir) =>
      _yo._portero.alDecidir = decidir;

  /// La ruta que dejó el último toque, para mirar sin consumirla. Observable:
  /// sirve con `ValueListenableBuilder` / `ListenableBuilder`.
  static ValueListenable<RutaDelAviso?> get rutaPendiente =>
      IntencionPendiente.instancia;

  /// Devuelve la ruta pendiente UNA vez y la limpia.
  static RutaDelAviso? consumirRuta() => IntencionPendiente.instancia.consumir();

  /// Lo que va a usar el 95% de las integraciones: entrega la ruta que ya
  /// estaba guardada (toque en frío, con la aplicación muerta) y todas las que
  /// lleguen después (toque caliente).
  ///
  /// Devuelve la función para cortar; llamarla en `dispose()` no es opcional:
  /// un consumidor muerto que siga suscrito se lleva la intención que le tocaba
  /// al que está vivo.
  ///
  /// ```dart
  /// late final VoidCallback _cortar;
  /// @override void initState() {
  ///   super.initState();
  ///   _cortar = AkPush.alRutear((r) => _navegador.go(r.destino));
  /// }
  /// @override void dispose() { _cortar(); super.dispose(); }
  /// ```
  static VoidCallback alRutear(void Function(RutaDelAviso ruta) navegar) =>
      IntencionPendiente.instancia.alLlegar(navegar);

  /// Por qué no llegan los push.
  ///
  /// No tiene efectos: no pide permiso, no registra, no envía nada. Se puede
  /// llamar desde un botón escondido de soporte, y **se puede llamar aunque
  /// [init] haya fallado** — que es justamente cuando más sirve. Por eso no
  /// pasa por `_asegurarIniciado()`: un diagnóstico que lanza `notInitialized`
  /// es inútil, porque el caso número uno es que `init()` no terminó.
  static Future<Diagnostico> diagnostico() => _yo._diagnostico();

  /// Lo que el comercio configuró sobre las notificaciones en su aplicación.
  ///
  /// Sirve para que la app sepa qué textos usar en su pregunta blanda y si el
  /// comercio considera el permiso indispensable.
  static PoliticaDeNotificaciones get politica => _yo._politica;

  /// Qué se le preguntó a esta persona y qué contestó.
  static Consentimiento get consentimiento => _yo._consentimiento;

  /// La aplicación avisa qué contestó la persona **en su propio modal**.
  ///
  /// Hay que llamarlo en los dos casos, no sólo cuando acepta: un «ahora no»
  /// también es un dato, y es el que distingue a quien se puede recuperar de
  /// quien ya dijo que no de verdad.
  ///
  /// Si aceptó, después se llama a [pedirPermiso] para el diálogo del sistema.
  static Future<void> reportarModal({required bool acepto}) =>
      _yo._reportarModal(acepto: acepto);

  Future<void> _reportarModal({required bool acepto}) async {
    _consentimiento =
        _consentimiento.conModal(acepto: acepto, cuando: DateTime.now());
    await _almacen.guardarConsentimiento(_consentimiento);
    await _almacen.anotarQueSePregunto();

    // Un «ahora no» hay que reportarlo al servicio: el comercio necesita
    // distinguirlo de quien nunca vio la pregunta, y sin esto los dos se ven
    // igual. Si no hay con quién asociarlo todavía, viaja en el próximo alta.
    if (!acepto && _userId != null && _token != null) {
      try {
        await _registrarAhora(userId: _userId!, concedido: false);
      } catch (_) {
        // Es telemetría: no puede romperle nada a la aplicación.
      }
    }
  }

  // ── El ciclo de sesión ──────────────────────────────────────────────────

  /// Deja este teléfono en orden para esta persona: da de baja a la anterior si
  /// era otra, resuelve el permiso según lo que configuró el comercio, y
  /// registra sólo si hace falta.
  ///
  /// Es lo que hay que llamar al iniciar sesión. Devuelve el resumen de cómo
  /// quedó, que es lo que la aplicación necesita para decidir qué mostrar.
  static Future<ResultadoDeSesion> alIniciarSesion({
    required String userId,
    String? identityHash,
    String? identity,
  }) =>
      _yo._alIniciarSesion(
        userId: userId,
        identityHash: identityHash,
        identity: identity,
      );

  /// Cierra el ciclo: da de baja el teléfono y limpia la barra de estado.
  static Future<void> alCerrarSesion() => _yo._logout();

  // ── Arranque ────────────────────────────────────────────────────────────

  /// Pide la configuración, conecta con Firebase, pide permiso y consigue la
  /// dirección de este teléfono.
  ///
  /// No registra a nadie todavía: para eso está [identify], que se llama cuando
  /// la persona inicia sesión.
  ///
  /// [pedirPermisoAlIniciar] viene en `true` porque es lo que hacía este
  /// paquete desde la primera versión y no puede cambiar solo. Pero el arranque
  /// en frío es el **peor** momento para disparar el diálogo del sistema: la
  /// persona acaba de abrir la aplicación, todavía no sabe qué hace, y el «no»
  /// que se lleva ahí no se recupera nunca más. Poniéndolo en `false`, `init()`
  /// sólo **lee** el permiso y la aplicación decide cuándo pedirlo con
  /// [pedirPermiso], después de su propia pantalla que explica para qué sirve.
  /// Arranca el SDK. Son tres valores, y ninguno más.
  ///
  /// [llave] es lo único secreto de los tres, y es lo que decide de qué comercio
  /// es cada llamada. [comercio] no da acceso: sirve para que una llave mal
  /// pegada **falle en el arranque** en vez de registrar a esta gente en otro
  /// comercio y mandarle avisos a los clientes de un tercero. Y [url] se
  /// configura en vez de quemarse, para poder apuntar a calidad o a producción
  /// sin publicar una versión nueva de la aplicación.
  static Future<void> init({
    required String llave,
    String? comercio,
    String? url,
    bool pedirPermisoAlIniciar = true,
    PoliticaDeNotificaciones? politicaPorDefecto,
  }) =>
      _yo._init(
        apiKey: llave,
        comercio: comercio,
        baseUrl: url,
        pedirPermisoAlIniciar: pedirPermisoAlIniciar,
        politicaPorDefecto: politicaPorDefecto,
      );

  Future<void> _init({
    required String apiKey,
    String? comercio,
    String? baseUrl,
    bool pedirPermisoAlIniciar = true,
    PoliticaDeNotificaciones? politicaPorDefecto,
  }) async {
    // La que declara la aplicación rige mientras el servicio no mande la suya.
    // Cuando la mande, gana la del servidor: la decisión es del comercio, y el
    // sentido de servirla es que la cambie sin publicar una versión nueva.
    if (politicaPorDefecto != null) _politica = politicaPorDefecto;
    // Un reintento que funciona no puede seguir reportando el error de la vez
    // pasada: el diagnóstico diría que está roto algo que ya se arregló.
    _ultimoError = null;

    try {
      final datos = await DatosDelDispositivo.recolectar();

      _api = AkPushApi(
        apiKey: apiKey,
        comercio: comercio,
        baseUrl: AkPushApi.normalizarUrl(
            baseUrl ?? 'https://api-push.creditotal.online'),
      );

      _consentimiento = await _almacen.leerConsentimiento();

      final cacheada = await _almacen.leer();
      final config =
          await _resolverConfig(datos.identificadorDePaquete, cacheada);

      // 🔴 La cuenta cambió. Un token de FCM solo vale dentro del proyecto que
      // lo emitió, así que el que tenemos guardado ya no sirve para nada — y si
      // no lo tiramos, este teléfono queda mudo para siempre sin ningún error
      // visible. Es el fallo más caro de todo el mecanismo de configuración
      // remota, y el único momento en que se puede atajar es acá.
      // El servidor manda. Si todavía no sirve el campo, `config.politica` es la
      // de siempre y no piso lo que declaró la aplicación.
      if (config.trajoPolitica) _politica = config.politica;

      final cambio = cacheada != null && cacheada.version != config.version;
      if (cambio) {
        await _descartarCuentaAnterior();
      }

      await _iniciarFirebase(config);
      _config = config;
      await _almacen.guardar(config);

      _estado = pedirPermisoAlIniciar
          ? await _permiso.pedir()
          : await _permiso.estadoActual();
      await _obtenerToken(descartarElViejo: cambio);

      await Presentador.instancia.iniciar();
      _escuchar();
      await _procesarArranqueEnFrio();
    } on AkPushError catch (e) {
      // Se guarda ANTES de propagarlo. El error de `init()` se le tira a quien
      // integra y hasta acá no quedaba anotado en ningún lado, que es
      // exactamente el caso que más hay que diagnosticar.
      _ultimoError = e;
      rethrow;
    }
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
      final delServidor = await _api!.obtenerConfig(identificadorDePaquete);
      _configDelServidor = true;
      return delServidor;
    } on AkPushError catch (e) {
      // Un desacuerdo entre la aplicación y lo registrado NO se resuelve con la
      // caché: seguiría con una configuración que el servidor ya dijo que no
      // corresponde. Se propaga.
      if (e.code == AkPushErrorCode.appMismatch ||
          e.code == AkPushErrorCode.unauthorized) {
        rethrow;
      }
      if (cacheada != null) {
        // Éste es el único lugar que sabe si la configuración de este arranque
        // vino de la red o del disco. Sin anotarlo, el diagnóstico no puede
        // avisar «este teléfono todavía no se enteró de que el comercio cambió
        // de cuenta».
        _configDelServidor = false;
        _ultimoError = e;
        return cacheada;
      }
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

    // Nada de lo que sabíamos sigue valiendo: el token es de otro proyecto y el
    // alta que el servidor tiene anotada es contra ese token. Dejarlos en pie
    // haría que el diagnóstico diga «registrado» sobre un registro muerto.
    _token = null;
    _tokenObtenidoEl = null;
    _registrado = false;
    _registradoEl = null;
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

  Future<void> _obtenerToken({bool descartarElViejo = false}) async {
    try {
      FirebaseMessaging.onBackgroundMessage(manejadorDeSegundoPlano);
      if (descartarElViejo) {
        await FirebaseMessaging.instance.deleteToken();
      }
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) {
        _tokenObtenidoEl = DateTime.now();
        await _almacen.guardarToken(_token!);
      }
    } catch (e) {
      _token = null;
      _ultimoError = AkPushError(
        AkPushErrorCode.unknown,
        'No se pudo obtener el token',
        details: e.toString(),
      );
    }
  }

  // ── El permiso ──────────────────────────────────────────────────────────

  /// Qué contestó —o no contestó todavía— la persona. **No dispara ningún
  /// diálogo**, así que se puede llamar todas las veces que haga falta.
  ///
  /// Hay que llamarlo cada vez que la aplicación vuelve del segundo plano
  /// (`AppLifecycleState.resumed`): el permiso se cambia desde los Ajustes del
  /// teléfono y **nada le avisa a la aplicación** cuando eso pasa.
  static Future<EstadoDelPermiso> estadoDelPermiso() => _yo._estadoDelPermiso();

  Future<EstadoDelPermiso> _estadoDelPermiso() async {
    _estado = await _permiso.estadoActual();
    await _reconciliar();
    return _estado;
  }

  /// Dispara el diálogo del SISTEMA, que es lo que se gasta.
  ///
  /// En iPhone se muestra una sola vez en la vida de la instalación; en
  /// Android 13+ alcanzan dos descartes para que no se muestre más. Por eso se
  /// llama **después** de la pantalla propia de la aplicación —la que explica
  /// para qué sirven los avisos— y sólo si ahí la persona dijo que sí.
  ///
  /// Devuelve el estado que quedó, que no siempre es el que se esperaba: pedir
  /// cuando ya está [EstadoDelPermiso.denegadoParaSiempre] no muestra nada.
  static Future<EstadoDelPermiso> pedirPermiso() => _yo._pedirPermisoAhora();

  Future<EstadoDelPermiso> _pedirPermisoAhora() async {
    _estado = await _permiso.pedir();
    await _reconciliar();
    return _estado;

  }

  /// Abre la ficha de la aplicación en los Ajustes del teléfono.
  ///
  /// Es lo único que queda cuando el estado es
  /// [EstadoDelPermiso.denegadoParaSiempre]. Abre la ficha y no la pantalla
  /// exacta de notificaciones porque no hay una API que lleve directo a esa
  /// pantalla en las dos plataformas; desde la ficha están a un toque.
  ///
  /// Devuelve si se pudo abrir, **no** si la persona activó algo: eso no se
  /// puede saber desde acá. Hay que volver a llamar a [estadoDelPermiso] cuando
  /// la aplicación vuelve del segundo plano — que es exactamente lo que pasa
  /// cuando alguien sale a los Ajustes y vuelve.
  static Future<bool> abrirAjustesDeNotificaciones() =>
      _yo._permiso.abrirAjustes();

  /// Pone al día el alta cuando el permiso cambia DESPUÉS del arranque.
  ///
  /// 🔴 Es el punto que se pasa por alto y deja teléfonos mudos. En iOS
  /// `getToken()` necesita el token de APNS, que sólo existe después de que se
  /// concedió el permiso: con `pedirPermisoAlIniciar: false`, `init()` deja el
  /// token en `null` y `identify()` se va por la rama que sólo guarda el
  /// usuario. Eso está bien mientras nadie diga que sí — pero en cuanto dice
  /// que sí hay que conseguir el token y volver a registrar, o el servicio
  /// sigue viendo `permisoConcedido: false` (o directamente ningún alta) y
  /// filtra el envío antes de mandarlo.
  Future<void> _reconciliar() async {
    if (!_estado.permiteRecibir) return;
    if (_token == null) await _obtenerToken();

    final userId = _userId ?? await _almacen.leerUsuario();
    if (userId == null || _token == null) return;

    final datos = await DatosDelDispositivo.recolectar();
    try {
      await _api?.registrarDispositivo(
        userId: userId,
        token: _token!,
        plataforma: datos.plataforma,
        deviceInfo: datos.toJson(),
        permisoConcedido: _estado.permiteRecibir,
      );
      _registrado = true;
      _registradoEl = DateTime.now();
    } catch (_) {
      // Se reintenta en el próximo identify(), o la próxima vez que la
      // aplicación vuelva del segundo plano y consulte el estado.
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

  /// El ciclo de sesión completo. La lógica de qué hacer vive en `sesion.dart`,
  /// separada de quien la ejecuta: acá sólo se cumple el plan.
  Future<ResultadoDeSesion> _alIniciarSesion({
    required String userId,
    String? identityHash,
    String? identity,
  }) async {
    _asegurarIniciado();

    // 🔴 Se le PREGUNTA al sistema operativo, no se confía en lo guardado. La
    // persona pudo haber apagado las notificaciones desde los Ajustes del
    // teléfono seis meses atrás y nada le avisó a la aplicación: lo que está en
    // disco puede estar viejo, y el sistema siempre tiene la verdad.
    final anterior = _userId ?? await _almacen.leerUsuario();
    _huella ??= HuellaDelRegistro.fromJson(await _almacen.leerHuella());
    var estado = await _permiso.estadoActual();

    final plan = planearInicioDeSesion(
      politica: _politica,
      userId: userId,
      estado: estado,
      token: _token,
      userIdAnterior: anterior,
      ultimoRegistro: _huella,
      yaSePregunto: await _almacen.yaSePreguntoElPermiso(),
      desdeLaUltimaPregunta: await _almacen.desdeLaUltimaPregunta(),
      ahora: DateTime.now(),
    );

    // Primero la baja de la anterior: si el registro nuevo falla a mitad, el
    // teléfono tiene que quedar sin dueño y no con el de antes, que seguiría
    // recibiendo lo suyo.
    if (plan.darDeBajaALaAnterior && anterior != null && _token != null) {
      try {
        await _api!.darDeBaja(userId: anterior, token: _token!);
      } catch (_) {
        // Si la baja no llega, igual hay que seguir: dejar a la persona nueva
        // sin registrar sería peor que dejar a la anterior de más.
      }
    }

    if (plan.pedirPermiso) {
      estado = await _pedirPermisoAhora();
    }

    // Con el permiso ya resuelto, para que el servidor guarde el estado de
    // verdad y no el de hace un segundo.
    final concedido = estado.permiteRecibir;

    // Si el sistema dice algo distinto de lo que teníamos anotado, gana el
    // sistema y queda registrado el cambio. Es el caso de quien lo apagó —o lo
    // encendió— desde los Ajustes: sin esto, el servicio le sigue enviando a un
    // teléfono que no muestra nada, o deja de enviarle a uno que sí.
    if (_consentimiento.acepto != null && _consentimiento.acepto != concedido) {
      _consentimiento = _consentimiento.conSistema(
        acepto: concedido,
        cuando: DateTime.now(),
      );
      await _almacen.guardarConsentimiento(_consentimiento);
    }

    var seRegistro = false;

    if (plan.registrar || (plan.pedirPermiso && _token != null)) {
      try {
        await _registrarAhora(
          userId: userId,
          identity: identity,
          identityHash: identityHash,
          concedido: concedido,
          estado: estado,
        );
        seRegistro = true;
      } catch (e) {
        _ultimoError = e is AkPushError ? e : null;
      }
    }

    _userId = userId;
    await _almacen.guardarUsuario(userId);

    return ResultadoDeSesion(
      puedeRecibir: concedido && _token != null && _registrado,
      estadoDelPermiso: estado,
      accionSugerida: plan.accionSugerida,
      huboCambioDePersona: plan.darDeBajaALaAnterior,
      seRegistro: seRegistro,
      motivo: motivoDeSesion(
        estado: estado,
        hayToken: _token != null,
        registrado: _registrado,
      ),
    );
  }

  /// El alta contra el servicio, más la huella que evita repetirla.
  Future<void> _registrarAhora({
    required String userId,
    required bool concedido,
    EstadoDelPermiso? estado,
    String? identity,
    String? identityHash,
  }) async {
    final datos = await DatosDelDispositivo.recolectar();
    final cuandoSePregunto = await _almacen.cuandoSePregunto();

    await _api!.registrarDispositivo(
      userId: userId,
      token: _token!,
      plataforma: datos.plataforma,
      identity: identity,
      identityHash: identityHash,
      deviceInfo: datos.toJson(),
      permisoConcedido: concedido,
      estadoDelPermiso: (estado ?? _estado).name,
      sePreguntoEl: cuandoSePregunto,
      consentimiento: _consentimiento.toJson(),
    );

    _registrado = true;
    _registradoEl = DateTime.now();
    _huella = HuellaDelRegistro(
      userId: userId,
      token: _token!,
      permisoConcedido: concedido,
      cuando: _registradoEl!,
    );
    await _almacen.guardarHuella(_huella!.toJson());
  }

  Future<void> _identify({
    required String userId,
    String? identityHash,
    String? identity,
  }) async {
    _asegurarIniciado();

    if (_token == null) {
      // Sin permiso no hay token, y sin token no hay nada que registrar. No es
      // un error: es el resultado de que la persona dijo que no. `_registrado`
      // queda en false a propósito, y eso es lo que hace que el diagnóstico
      // pueda decir «se llamó a identify() pero el alta no llegó».
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
      permisoConcedido: _estado.permiteRecibir,
    );

    _registrado = true;
    _registradoEl = DateTime.now();

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
    _registrado = false;
    _registradoEl = null;
    await _almacen.olvidarSesion();
    await Presentador.instancia.retirarTodos();

    // Una ruta guardada apunta a los datos de quien estaba usando el teléfono:
    // entregarla después del cierre lo llevaría a la pantalla de otro.
    IntencionPendiente.instancia.limpiar();
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

  Future<Diagnostico> _diagnostico() => Diagnostico.reunir(
        config: _config,
        configPedidaAlServidor: _configDelServidor,
        token: _token,
        tokenObtenidoEl: _tokenObtenidoEl,
        userId: _userId,
        registradoEnElServidor: _registrado,
        registradoEl: _registradoEl,
        ultimoError: _ultimoError,
        almacen: _almacen,
        // Se le pasa el gestor y NO el estado: `_estado` es el del último
        // momento en que alguien preguntó, y el permiso se apaga desde los
        // Ajustes sin avisarle a nadie. Diagnosticar con el valor viejo diría
        // «permiso concedido» justo en el caso que más se reporta. El gestor sí
        // se reutiliza, para no volver a pagar la lectura del nivel de Android.
        gestorDePermiso: _permiso,
      );

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
    final decision = await _portero.resolver(mensaje);
    if (decision.seDibuja) {
      await Presentador.instancia.mostrar(mensaje, silencioso: decision.sinRuido);
    }

    // El reporte queda FUERA del `if` a propósito: el aviso llegó al teléfono, y
    // que la aplicación haya decidido no dibujarlo es una decisión posterior a
    // la entrega. Contarlo adentro haría que el comercio que MÁS cuida a su
    // gente sea el que peor mide.
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

    // La intención se guarda ANTES de publicar el toque: quien escuche
    // onNotificationTap y mire la ruta pendiente en el mismo instante tiene que
    // encontrarla ya guardada, no medio cuadro después. Y va después del guard
    // de duplicados, o el toque doble del arranque en frío la guardaría dos
    // veces.
    IntencionPendiente.instancia.guardarDesde(mensaje);

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
    _tokenObtenidoEl = DateTime.now();
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
        permisoConcedido: _estado.permiteRecibir,
      );
      _registrado = true;
      _registradoEl = DateTime.now();
    } catch (e) {
      // Ésta es la ventana muda: el token nuevo no lo tiene nadie anotado y el
      // viejo ya no entrega. Se anota para que el diagnóstico pueda decirlo, en
      // vez de que el teléfono quede inalcanzable sin ningún síntoma.
      _registrado = false;
      _ultimoError = e is AkPushError
          ? e
          : AkPushError(
              AkPushErrorCode.unknown,
              'No se pudo re-registrar el token rotado',
              details: e.toString(),
            );
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
