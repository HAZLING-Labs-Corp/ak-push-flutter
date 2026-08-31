/// Errores del paquete.
///
/// Existen para poder ramificar sin leer textos: «la llave está mal» y «no hay
/// señal» piden reacciones opuestas, y distinguirlas comparando mensajes es
/// cómo se escriben integraciones que se rompen al corregir una tilde.
enum AkPushErrorCode {
  /// La llave falta, es inválida, o se usó la secreta donde va la pública.
  unauthorized,

  /// La configuración que pedimos no corresponde a esta aplicación. Casi
  /// siempre: el identificador del paquete no es el que quedó registrado.
  appMismatch,

  /// No hubo respuesta: red, DNS o tiempo agotado. Transitorio.
  network,

  /// El comercio exige que el `userId` venga firmado, y la firma falta o no
  /// coincide.
  ///
  /// Tiene código propio y no se mezcla con [unauthorized] porque el arreglo es
  /// otro: la llave está bien, lo que falta es que **el backend del comercio**
  /// calcule el HMAC del `userId` y la aplicación lo pase en `identify()`.
  /// Decir «no autorizado» manda a revisar la llave, que no tiene nada que ver.
  firmaDeIdentidad,

  /// El servicio contestó, pero esa ruta no existe.
  ///
  /// Casi siempre es la dirección mal configurada. Tiene código propio porque
  /// el síntoma —un 404— es idéntico al de «este paquete no está registrado», y
  /// confundirlos manda a revisar el registro del paquete cuando lo que hay que
  /// mirar es la URL.
  rutaNoEncontrada,

  /// El servicio contestó, pero no pudo servir la configuración.
  serviceUnavailable,

  /// Firebase no pudo inicializarse con la configuración recibida.
  firebaseInit,

  /// La persona no dio permiso de notificaciones. No es una falla: es una
  /// respuesta.
  permissionDenied,

  /// Se llamó a algo antes de que `AkPush.init()` terminara.
  ///
  /// Tiene código propio porque es el error que más se comete integrando —
  /// `init()` es asíncrono y una pantalla puede ofrecer el botón de inicio de
  /// sesión antes de que termine—. Devolverlo como «desconocido» deja a quien
  /// integra sin ninguna pista de qué hacer.
  notInitialized,

  unknown,
}

class AkPushError implements Exception {
  AkPushError(this.code, this.message, {this.details});

  final AkPushErrorCode code;
  final String message;
  final String? details;

  /// Si esperar y reintentar puede cambiar el resultado.
  bool get retryable =>
      code == AkPushErrorCode.network ||
      code == AkPushErrorCode.serviceUnavailable;

  @override
  String toString() =>
      'AkPushError(${code.name}): $message${details != null ? ' — $details' : ''}';
}
