/// Qué se le preguntó a esta persona y qué contestó.
///
/// ## Son dos preguntas, no una
///
///   **El modal** lo levanta la aplicación. Un «no» acá no cuesta nada: el
///   diálogo del sistema queda intacto y se le puede volver a preguntar.
///
///   **El diálogo del sistema** lo levanta Android o iOS. Un «no» acá es caro, y
///   en iPhone definitivo: ese diálogo se muestra una sola vez en la vida de la
///   instalación.
///
/// Alguien puede decir **que sí al modal y que no al del sistema**. Con un solo
/// campo —«se le preguntó»— esa persona queda marcada igual que quien nunca vio
/// nada, y son situaciones opuestas: a una se le puede volver a preguntar, a la
/// otra sólo le quedan los Ajustes.
///
/// Con las dos por separado, el comercio puede leer dónde se le va la gente:
/// si pocos ven el modal, el momento está mal; si muchos ven el modal y dicen
/// que no, **el texto no convence**; si dicen que sí y el sistema los pierde,
/// hay otro problema.
class Consentimiento {
  const Consentimiento({
    this.modalMostradoEl,
    this.aceptoElModal,
    this.sistemaRespondioEl,
    this.acepto,
  });

  /// Cuándo se le levantó el modal de la aplicación.
  final DateTime? modalMostradoEl;

  /// Qué dijo en el modal. `null` si nunca se le mostró.
  final bool? aceptoElModal;

  /// Cuándo contestó el diálogo del sistema. `null` si nunca llegó a mostrarse
  /// —que es lo que pasa cuando dijo «ahora no» en el modal, y es justamente el
  /// caso que había que poder distinguir.
  final DateTime? sistemaRespondioEl;

  /// **Aceptó las notificaciones o no.** Es la respuesta que importa: la del
  /// sistema, no la del modal.
  final bool? acepto;

  /// En qué punto quedó. Es lo que se manda al servicio y lo que la consola
  /// muestra sin tener que interpretar dos fechas.
  String get punto {
    if (acepto == true) return 'acepto';
    if (acepto == false) return 'denego_en_el_sistema';
    if (aceptoElModal == false) return 'dijo_ahora_no';
    if (aceptoElModal == true) return 'esperando_al_sistema';
    return 'sin_preguntar';
  }

  Consentimiento conModal({required bool acepto, required DateTime cuando}) =>
      Consentimiento(
        modalMostradoEl: cuando,
        aceptoElModal: acepto,
        // Una respuesta nueva al modal empieza un intento nuevo: lo que el
        // sistema haya contestado antes ya no describe a ésta.
        sistemaRespondioEl: null,
        acepto: null,
      );

  Consentimiento conSistema({required bool acepto, required DateTime cuando}) =>
      Consentimiento(
        modalMostradoEl: modalMostradoEl,
        aceptoElModal: aceptoElModal,
        sistemaRespondioEl: cuando,
        acepto: acepto,
      );

  Map<String, dynamic> toJson() => {
        'punto': punto,
        if (acepto != null) 'acepto': acepto,
        if (modalMostradoEl != null)
          'modalMostradoEl': modalMostradoEl!.toUtc().toIso8601String(),
        if (aceptoElModal != null) 'aceptoElModal': aceptoElModal,
        if (sistemaRespondioEl != null)
          'sistemaRespondioEl': sistemaRespondioEl!.toUtc().toIso8601String(),
      };

  static Consentimiento fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Consentimiento();
    DateTime? fecha(String k) => DateTime.tryParse(j[k] as String? ?? '');
    return Consentimiento(
      modalMostradoEl: fecha('modalMostradoEl'),
      aceptoElModal: j['aceptoElModal'] as bool?,
      sistemaRespondioEl: fecha('sistemaRespondioEl'),
      acepto: j['acepto'] as bool?,
    );
  }
}
