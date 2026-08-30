/// Un push recibido, sin nada del SDK de Firebase adentro.
///
/// El paquete traduce `RemoteMessage` a esto en un solo lugar, de modo que
/// quien lo use nunca importe `firebase_messaging` ni quede atado a su forma.
class PushMessage {
  const PushMessage({
    required this.data,
    this.title,
    this.body,
    this.messageId,
  });

  final Map<String, String> data;
  final String? title;
  final String? body;

  /// Id que asigna FCM. Es lo que permite reconocer que el MISMO toque llegó
  /// dos veces: con la aplicación cerrada, el sistema lo reporta por dos
  /// caminos distintos, y sin deduplicar se mide doble.
  final String? messageId;

  /// Identificador del envío. Sin él no hay nada que medir — el aviso llegó,
  /// pero no se puede decir a cuál corresponde.
  String? get pushLogId => data['pushLogId'];

  /// Código del aviso en la bandeja, si el emisor lo mandó.
  String? get codeEvent => data['code_event'];

  /// Señal: un push cuyo único propósito es decirle a la aplicación «andá a
  /// revisar algo». No trae contenido que mostrar.
  String? get signal => data['type'];
}
