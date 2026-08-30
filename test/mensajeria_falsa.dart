import 'package:firebase_messaging/firebase_messaging.dart';

/// Un `FirebaseMessaging` de mentira, escrito a mano.
///
/// Contesta las dos únicas preguntas que le hace `GestorDePermiso` y cuenta por
/// separado cuántas veces se **leyó** el estado y cuántas se **disparó el
/// diálogo**: son la misma llamada para el análisis estático y dos cosas
/// completamente distintas para la persona, porque el diálogo se gasta y la
/// lectura no. Sin contarlas aparte no hay forma de probar que leer el estado
/// no le quema a nadie su única oportunidad.
///
/// Todo lo demás cae en [noSuchMethod] y revienta a propósito: si mañana el
/// gestor empezara a llamar a otra cosa —`getToken()`, por ejemplo, que en iOS
/// arrastra el registro contra APNs—, la prueba se entera en vez de dejarlo
/// pasar en silencio.
class MensajeriaFalsa implements FirebaseMessaging {
  MensajeriaFalsa({
    this.estado = AuthorizationStatus.notDetermined,
    this.respuestaDelDialogo,
    this.rompeAlLeer,
    this.rompeAlPedir,
  });

  /// Lo que contesta el sistema hoy, sin preguntarle nada a la persona.
  AuthorizationStatus estado;

  /// Lo que contestaría la persona si se mostrara el diálogo. En `null` el
  /// diálogo no cambia nada, que es lo que pasa cuando ya no se muestra más.
  AuthorizationStatus? respuestaDelDialogo;

  /// Para el teléfono donde el canal nativo no contesta.
  Object? rompeAlLeer;
  Object? rompeAlPedir;

  int lecturas = 0;
  int dialogos = 0;

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    lecturas++;
    if (rompeAlLeer != null) throw rompeAlLeer!;
    return ajustesCon(estado);
  }

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    dialogos++;
    if (rompeAlPedir != null) throw rompeAlPedir!;
    // El diálogo deja al sistema en el estado que quedó: una lectura posterior
    // tiene que ver lo mismo que devolvió el pedido, o la prueba estaría
    // midiendo un teléfono que no existe.
    estado = respuestaDelDialogo ?? estado;
    return ajustesCon(estado);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  /// De los doce campos de `NotificationSettings`, once son de iOS y ninguno se
  /// mira acá: el único que el SDK lee es [AuthorizationStatus].
  static NotificationSettings ajustesCon(AuthorizationStatus estado) =>
      NotificationSettings(
        alert: AppleNotificationSetting.enabled,
        announcement: AppleNotificationSetting.disabled,
        authorizationStatus: estado,
        badge: AppleNotificationSetting.enabled,
        carPlay: AppleNotificationSetting.disabled,
        lockScreen: AppleNotificationSetting.enabled,
        notificationCenter: AppleNotificationSetting.enabled,
        showPreviews: AppleShowPreviewSetting.always,
        timeSensitive: AppleNotificationSetting.disabled,
        criticalAlert: AppleNotificationSetting.disabled,
        sound: AppleNotificationSetting.enabled,
        providesAppNotificationSettings: AppleNotificationSetting.disabled,
      );
}
