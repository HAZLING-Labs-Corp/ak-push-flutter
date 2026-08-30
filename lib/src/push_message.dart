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

/// Lo que la aplicación puede reportar sobre un aviso.
///
/// Son cinco y no dos porque el servicio las distingue, y cada una contesta una
/// pregunta distinta del negocio: `delivered` mide el transporte, `viewed` y
/// `opened` miden si el mensaje sirvió, y `dismissed` mide si molestó.
enum AccionDePush {
  /// Llegó al teléfono. Hoy sólo se puede reportar con la app abierta.
  delivered,

  /// La persona lo vio en la barra, sin abrirlo.
  viewed,

  /// La persona lo tocó.
  opened,

  /// La persona lo descartó sin abrirlo.
  dismissed,

  /// Caducó antes de que hiciera nada con él.
  expired;

  /// El valor que espera el servicio, tal cual.
  String get valor => switch (this) {
        AccionDePush.delivered => 'DELIVERED',
        AccionDePush.viewed => 'VIEWED',
        AccionDePush.opened => 'OPENED',
        AccionDePush.dismissed => 'DISMISSED',
        AccionDePush.expired => 'EXPIRED',
      };
}
