import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_message.dart';

/// Dibuja el aviso cuando la aplicación está ABIERTA, y es dueño de los canales
/// de Android.
///
/// ## Por qué existe
///
/// FCM **no dibuja nada** cuando la aplicación está en primer plano en Android.
/// Sin esta pieza, un push que llega con la app abierta no se ve, no falla, y no
/// deja rastro: simplemente no pasa nada.
///
/// ## Y por qué expone su propio flujo de toques
///
/// El aviso que dibuja este paquete lo dibuja el sistema operativo a pedido del
/// plugin local, no de FCM. Por eso **su toque nunca llega por el flujo de
/// FCM**. Si nadie escucha [alTocar], tocar una notificación con la aplicación
/// abierta no hace absolutamente nada — y es un fallo mudo, sin excepción ni
/// registro.
class Presentador {
  Presentador._();

  /// Único por proceso: los canales y el plugin son globales del sistema, así
  /// que una segunda instancia solo duplicaría manejadores.
  static final Presentador instancia = Presentador._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<PushMessage> _toques =
      StreamController<PushMessage>.broadcast();

  Future<void>? _arranque;

  /// Toques sobre los avisos que dibujó este paquete.
  Stream<PushMessage> get alTocar => _toques.stream;

  /// Canal por defecto. Tiene que coincidir con el `default_notification_channel_id`
  /// del AndroidManifest de la aplicación, o los avisos que dibuja FCM en
  /// segundo plano caen en un canal que no existe.
  static const String canalPorDefecto = 'default';

  /// Canal gemelo del anterior, pero mudo.
  ///
  /// Hace falta un canal aparte porque en Android el sonido y la vibración son
  /// propiedad del CANAL, no del aviso, y un canal ya creado **no se puede
  /// cambiar**: el sistema ignora en silencio cualquier cambio de importancia o
  /// de sonido posterior a su creación. Sin este segundo canal, pedir un aviso
  /// sin ruido no haría nada y sonaría igual.
  static const String canalSilencioso = 'silencioso';

  static const List<AndroidNotificationChannel> _canales = [
    AndroidNotificationChannel(
      canalPorDefecto,
      'Avisos',
      description: 'Avisos generales de la aplicación',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      canalSilencioso,
      'Avisos sin sonido',
      description: 'Avisos que la aplicación pidió mostrar sin ruido',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    ),
  ];

  Future<void> iniciar() => _arranque ??= _iniciar();

  Future<void> _iniciar() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const apple = DarwinInitializationSettings();

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: apple),
      onDidReceiveNotificationResponse: _alResponder,
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      for (final canal in _canales) {
        await androidPlugin.createNotificationChannel(canal);
      }
    }
  }

  /// Dibuja el aviso. Si no trae ni título ni cuerpo no dibuja nada: un aviso
  /// vacío en la barra de estado es peor que ninguno.
  ///
  /// Con [silencioso] el aviso se ve igual pero no suena ni vibra. Es para
  /// cuando la persona ya está adentro de la aplicación: va a ver el aviso de
  /// todos modos, y el ruido es lo único que sobra. El id del sistema no cambia
  /// por esto, así que [retirar] sigue alcanzando también al aviso mudo.
  Future<void> mostrar(PushMessage mensaje, {bool silencioso = false}) async {
    if (mensaje.title == null && mensaje.body == null) return;

    await iniciar();

    // Con `silencioso` manda el canal mudo y no el que pidió el mensaje: el
    // `channelId` que viaja en `data` elige entre canales que suenan, y
    // respetarlo acá haría sonar justamente al que se pidió callado.
    final canal = silencioso
        ? canalSilencioso
        : (mensaje.data['channelId'] ?? canalPorDefecto);
    final definicion = _canales.firstWhere(
      (c) => c.id == canal,
      orElse: () => _canales.first,
    );

    final detalles = NotificationDetails(
      android: AndroidNotificationDetails(
        definicion.id,
        definicion.name,
        channelDescription: definicion.description,
        importance: silencioso ? Importance.low : Importance.high,
        priority: silencioso ? Priority.low : Priority.high,
        playSound: !silencioso,
        enableVibration: !silencioso,
      ),
      // En iOS no hay canales: el silencio se pide aviso por aviso.
      iOS: DarwinNotificationDetails(presentSound: !silencioso),
    );

    await _plugin.show(
      id: _idDelSistema(mensaje),
      title: mensaje.title,
      body: mensaje.body,
      notificationDetails: detalles,
      // El payload viaja como JSON para poder reconstruir el mensaje cuando lo
      // toquen: el toque llega por el plugin, no por FCM, así que sin esto se
      // perdería el pushLogId y con él la medición de apertura.
      payload: jsonEncode(mensaje.data),
    );
  }

  /// Retira un aviso de la barra de estado.
  Future<void> retirar(PushMessage mensaje) =>
      _plugin.cancel(id: _idDelSistema(mensaje));

  /// Retira todos. Es el único camino que alcanza también a los avisos que
  /// dibujó FCM en segundo plano: esos llevan un id que asigna FCM y ningún
  /// código de la aplicación puede direccionar.
  Future<void> retirarTodos() => _plugin.cancelAll();

  void _alResponder(NotificationResponse respuesta) {
    final crudo = respuesta.payload;
    if (crudo == null) return;
    try {
      final datos = (jsonDecode(crudo) as Map).cast<String, dynamic>();
      _toques.add(PushMessage(
        data: datos.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      ));
    } catch (_) {
      // Un payload ilegible no puede tumbar el manejador de toques.
    }
  }

  /// El id del aviso se **deriva** del mensaje, no se guarda.
  ///
  /// Quien lo dibuja y quien lo retira pueden ser dos partes de la aplicación
  /// que nunca se hablan; derivándolo, las dos llegan al mismo número desde el
  /// mismo dato. Enmascarado a 31 bits porque el id de Android es un entero con
  /// signo de Java.
  int _idDelSistema(PushMessage mensaje) {
    final semilla = mensaje.codeEvent ?? mensaje.pushLogId ?? mensaje.title ?? '';
    if (semilla.isEmpty) return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    return semilla.hashCode & 0x7fffffff;
  }
}
