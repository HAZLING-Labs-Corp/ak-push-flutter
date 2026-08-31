/// La política de notificaciones que el comercio configura desde su consola.
///
/// ## Por qué esto existe
///
/// Cuándo pedirle el permiso a una persona no es una decisión del programador que
/// integra el SDK: es del comercio, y cambia con el negocio. Una app de banca
/// puede querer pedirlo apenas la persona entra —porque sus avisos son de
/// seguridad y nadie discute que los quiere—, y una de comercio conviene que
/// espere a la primera compra.
///
/// Hoy eso está escrito en el código de cada aplicación, así que cambiarlo
/// significa publicar una versión nueva. Sirviéndolo con la configuración, el
/// comercio lo cambia desde su consola y toma efecto en el siguiente arranque.
///
/// ## 🔴 Lo que «obligatorio» NO puede significar
///
/// Ningún SDK puede obligar a nadie a aceptar notificaciones. El diálogo es del
/// sistema operativo y la respuesta es de la persona; no hay API que lo fuerce, y
/// la que lo intentara sería rechazada por las tiendas.
///
/// Acá `obligatorio` significa una cosa concreta y más chica: **el SDK le avisa a
/// la aplicación que este comercio considera el permiso indispensable**, para que
/// la aplicación insista —una pantalla que explique, un aviso que no se cierra, lo
/// que decida—. Lo que hace con esa señal es de la aplicación. El SDK informa; no
/// bloquea pantallas ajenas.
///
/// Prometer más que eso sería prometer algo que no se puede cumplir, y se
/// descubriría en la primera integración.
library;

import 'permiso.dart';

/// En qué momento el SDK pide el permiso del sistema.
enum MomentoDelPermiso {
  /// Apenas arranca la aplicación. Es lo que hace hoy el SDK y lo que hace la
  /// app de la que nos copiamos, así que es el valor por defecto: un comercio
  /// que no configure nada no ve ningún cambio.
  ///
  /// Es también el peor momento en términos de aceptación —la persona todavía no
  /// sabe qué hace la app— pero cambiarlo por su cuenta sería cambiarle el
  /// comportamiento a quien ya integró sin que lo pidiera.
  arranque,

  /// Cuando la persona inicia sesión, en `identify()`. Para entonces ya sabe qué
  /// es la aplicación y qué esperar de ella.
  login,

  /// El SDK no pide nada solo: espera a que la aplicación llame a
  /// `pedirPermiso()` en el momento que le parezca. Es el que más convierte y el
  /// que más trabajo le da a quien integra.
  laAppDecide,
}

/// Los textos de la pregunta blanda. Son del comercio, no nuestros: hablan con su
/// voz y de su negocio, y por eso viajan con la configuración en vez de estar
/// escritos en el paquete.
class TextosDeLaPregunta {
  const TextosDeLaPregunta({
    required this.titulo,
    required this.cuerpo,
    required this.aceptar,
    required this.ahoraNo,
  });

  final String titulo;
  final String cuerpo;
  final String aceptar;
  final String ahoraNo;

  static const predeterminados = TextosDeLaPregunta(
    titulo: '¿Te avisamos?',
    cuerpo: 'Podemos avisarte cuando haya algo importante en tu cuenta.',
    aceptar: 'Sí, avísenme',
    ahoraNo: 'Ahora no',
  );

  factory TextosDeLaPregunta.fromJson(Map<String, dynamic> json) =>
      TextosDeLaPregunta(
        titulo: json['titulo'] as String? ?? predeterminados.titulo,
        cuerpo: json['cuerpo'] as String? ?? predeterminados.cuerpo,
        aceptar: json['aceptar'] as String? ?? predeterminados.aceptar,
        ahoraNo: json['ahoraNo'] as String? ?? predeterminados.ahoraNo,
      );

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'cuerpo': cuerpo,
        'aceptar': aceptar,
        'ahoraNo': ahoraNo,
      };
}

/// Lo que el comercio decidió sobre las notificaciones en su aplicación.
class PoliticaDeNotificaciones {
  const PoliticaDeNotificaciones({
    this.momento = MomentoDelPermiso.arranque,
    this.obligatorio = false,
    this.preguntaBlanda = false,
    this.reintentarCadaDias = 7,
    this.textos = TextosDeLaPregunta.predeterminados,
  });

  final MomentoDelPermiso momento;

  /// El comercio considera el permiso indispensable. Ver la nota de la cabecera
  /// sobre lo que esto puede y no puede significar.
  final bool obligatorio;

  /// Si la aplicación tiene que mostrar su propia pantalla ANTES del diálogo del
  /// sistema.
  ///
  /// Es lo que convierte un «no» irreversible en un «ahora no» reversible: en
  /// iPhone el diálogo del sistema se muestra una sola vez en la vida de la
  /// instalación, y en Android 13+ dos descartes lo dan por denegado. Un «ahora
  /// no» en una pantalla propia no gasta ese único intento.
  final bool preguntaBlanda;

  /// Cuántos días esperar antes de volver a mostrar la pregunta blanda a quien
  /// dijo «ahora no». Cero significa preguntar en cada arranque, que es cómo se
  /// consigue que alguien desinstale la aplicación.
  final int reintentarCadaDias;

  final TextosDeLaPregunta textos;

  /// La política que rige cuando el servidor no manda ninguna.
  ///
  /// Reproduce exactamente lo que el SDK hace hoy: pedir el permiso en el
  /// arranque, sin pregunta blanda. Es deliberado — mientras el servicio no
  /// sirva el campo, nadie ve un cambio de comportamiento.
  static const comoEstabaAntes = PoliticaDeNotificaciones();

  /// Lee la política de la configuración del comercio.
  ///
  /// Tolera que el campo no exista: mientras el servicio no lo sirva, se usa
  /// [comoEstabaAntes]. Es lo que permite que el SDK traiga esto hoy sin esperar
  /// al servidor.
  factory PoliticaDeNotificaciones.fromJson(Map<String, dynamic>? json) {
    if (json == null) return comoEstabaAntes;
    return PoliticaDeNotificaciones(
      momento: _momentoDesde(json['momento'] as String?),
      obligatorio: json['obligatorio'] as bool? ?? false,
      preguntaBlanda: json['preguntaBlanda'] as bool? ?? false,
      reintentarCadaDias: (json['reintentarCadaDias'] as num?)?.toInt() ?? 7,
      textos: json['textos'] is Map
          ? TextosDeLaPregunta.fromJson(
              (json['textos'] as Map).cast<String, dynamic>())
          : TextosDeLaPregunta.predeterminados,
    );
  }

  Map<String, dynamic> toJson() => {
        'momento': momento.name,
        'obligatorio': obligatorio,
        'preguntaBlanda': preguntaBlanda,
        'reintentarCadaDias': reintentarCadaDias,
        'textos': textos.toJson(),
      };

  /// Un valor desconocido cae en el que ya andaba, y no rompe.
  ///
  /// Es a propósito: si mañana el servicio agrega un momento nuevo, una
  /// aplicación vieja tiene que seguir funcionando en vez de fallar al arrancar
  /// por una palabra que no conoce.
  static MomentoDelPermiso _momentoDesde(String? v) => switch (v) {
        'login' => MomentoDelPermiso.login,
        'laAppDecide' => MomentoDelPermiso.laAppDecide,
        _ => MomentoDelPermiso.arranque,
      };
}

/// Qué hay que hacer ahora con el permiso, según la política y lo que ya pasó.
///
/// Es una decisión pura: no toca el sistema operativo ni la red. Recibe el estado
/// y devuelve la acción, lo que la hace comprobable sin un teléfono — que es la
/// única forma de probar de verdad la parte que más importa.
enum AccionDePermiso {
  /// No hacer nada: ya está concedido, o no es el momento.
  ninguna,

  /// Mostrar la pantalla propia del comercio antes del diálogo del sistema.
  mostrarPreguntaBlanda,

  /// Disparar el diálogo del sistema.
  pedirAlSistema,

  /// Está denegado para siempre y el comercio lo considera indispensable: lo
  /// único que queda es ofrecer los Ajustes del teléfono.
  ofrecerAjustes,
}

/// Cuándo se está evaluando la decisión.
enum Disparador { arranque, login, laAppLoPidio }

/// Decide qué hacer, dada la política, el estado del permiso y cuándo se
/// preguntó por última vez.
///
/// [estado] es lo que reportó el sistema operativo. La función no lo consulta:
/// lo recibe. Por eso se puede probar entera sin un teléfono, que es justo la
/// parte que más importa de todo este módulo.
AccionDePermiso decidirQueHacer({
  required PoliticaDeNotificaciones politica,
  required Disparador disparador,
  required EstadoDelPermiso estado,
  required bool yaSePregunto,
  Duration? desdeLaUltimaPregunta,
}) {
  // Ya está: no hay nada que decidir. `provisional` de iOS también entrega, así
  // que tampoco hay nada que pedir.
  if (estado == EstadoDelPermiso.concedido ||
      estado == EstadoDelPermiso.provisional) {
    return AccionDePermiso.ninguna;
  }

  // Sin vuelta atrás desde la app. Sólo se ofrece si el comercio lo considera
  // indispensable; si no, insistir con los Ajustes es molestar por algo que la
  // persona ya contestó.
  if (estado.soloQuedanLosAjustes) {
    return politica.obligatorio
        ? AccionDePermiso.ofrecerAjustes
        : AccionDePermiso.ninguna;
  }

  // ¿Es el momento que el comercio eligió?
  final esElMomento = switch (politica.momento) {
    MomentoDelPermiso.arranque => disparador == Disparador.arranque,
    MomentoDelPermiso.login => disparador == Disparador.login,
    MomentoDelPermiso.laAppDecide => disparador == Disparador.laAppLoPidio,
  };

  // Cuando la app lo pide explícitamente, se le hace caso siempre: pidió, y
  // negarse porque «no es el momento» sería desobedecer a quien integra.
  if (!esElMomento && disparador != Disparador.laAppLoPidio) {
    return AccionDePermiso.ninguna;
  }

  // A quien ya dijo «ahora no» se le respeta la espera. Preguntar en cada
  // arranque es cómo se consigue una desinstalación.
  if (yaSePregunto &&
      disparador != Disparador.laAppLoPidio &&
      politica.reintentarCadaDias > 0) {
    final espera = Duration(days: politica.reintentarCadaDias);
    if (desdeLaUltimaPregunta == null || desdeLaUltimaPregunta < espera) {
      return AccionDePermiso.ninguna;
    }
  }

  return politica.preguntaBlanda
      ? AccionDePermiso.mostrarPreguntaBlanda
      : AccionDePermiso.pedirAlSistema;
}


/// LOS TEXTOS DEL MODAL DE UBICACIÓN, TAL COMO LOS ESCRIBIÓ EL COMERCIO
///
/// Vienen de `/api/v1/configuracion`. Si el comercio no escribió nada, valen los de
/// abajo — que no son de relleno: están redactados para contestar las tres preguntas
/// que alguien se hace antes de decir que sí (¿qué tan preciso?, ¿cuándo?, ¿lo puedo
/// deshacer?), y las tres respuestas son verdad en este SDK.
class TextosDeUbicacion {
  const TextosDeUbicacion({
    this.titulo = 'Avisos de tu zona',
    this.cuerpo =
        'Si nos dejás saber en qué zona estás, te escribimos sólo lo que pasa cerca '
        'tuyo en vez de mandarte todo.',
    this.aceptar = 'Compartir mi zona',
    this.ahoraNo = 'Ahora no',
    this.motivos = const [
      'Es la zona, no la dirección exacta',
      'Sólo mientras usás la aplicación',
      'Lo cambiás cuando quieras desde los ajustes',
    ],
  });

  final String titulo;
  final String cuerpo;
  final String aceptar;
  final String ahoraNo;
  final List<String> motivos;

  /// Cada campo cae por separado en su valor por omisión.
  ///
  /// 🔴 A propósito: un comercio que sólo quiso cambiar el título no tiene por qué
  /// quedarse sin los tres motivos. Si esto fuera «o todo lo del servidor o todo lo de
  /// fábrica», el primero que edita una palabra se queda con el modal vacío.
  factory TextosDeUbicacion.fromJson(Map<String, dynamic>? j) {
    const d = TextosDeUbicacion();
    if (j == null) return d;
    String t(String k, String x) {
      final v = j[k];
      return (v is String && v.trim().isNotEmpty) ? v.trim() : x;
    }
    final m = j['motivos'];
    return TextosDeUbicacion(
      titulo: t('titulo', d.titulo),
      cuerpo: t('cuerpo', d.cuerpo),
      aceptar: t('aceptar', d.aceptar),
      ahoraNo: t('ahoraNo', d.ahoraNo),
      motivos: (m is List && m.isNotEmpty)
          ? m.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList()
          : d.motivos,
    );
  }
}

/// SI SE LE OFRECE LA UBICACIÓN, CUÁNDO, Y CADA CUÁNTO SE REINSISTE.
///
/// Nace apagada. Un comercio que no la necesita no le muestra a su gente un diálogo
/// de más, y prender esto sin querer es pedir un permiso que no hace falta.
class PoliticaDeUbicacion {
  const PoliticaDeUbicacion({
    this.activa = false,
    this.momento = MomentoDeUbicacion.despuesDeEntrar,
    this.reintentarCadaDias = 14,
    this.textos = const TextosDeUbicacion(),
  });

  final bool activa;
  final MomentoDeUbicacion momento;

  /// Cada cuántos días volver a ofrecerla a quien cerró el modal sin aceptar.
  ///
  /// 🔴 Esto NO reintenta contra quien le dijo que no al diálogo del SISTEMA: ese «no»
  /// Android lo recuerda solo y ya no vuelve a mostrar nada. Reinsistir ahí sería
  /// levantar un modal que no lleva a ninguna parte. Sólo se le vuelve a ofrecer a
  /// quien todavía puede decir que sí.
  final int reintentarCadaDias;
  final TextosDeUbicacion textos;

  factory PoliticaDeUbicacion.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const PoliticaDeUbicacion();
    return PoliticaDeUbicacion(
      activa: j['activa'] == true,
      momento: j['momento'] == 'laAppDecide'
          ? MomentoDeUbicacion.laAppDecide
          : MomentoDeUbicacion.despuesDeEntrar,
      reintentarCadaDias:
          (j['reintentarCadaDias'] is num) ? (j['reintentarCadaDias'] as num).toInt() : 14,
      textos: TextosDeUbicacion.fromJson(
          j['textos'] is Map ? Map<String, dynamic>.from(j['textos'] as Map) : null),
    );
  }
}

enum MomentoDeUbicacion {
  /// Al iniciar sesión, DESPUÉS de que se resolvió el permiso de notificaciones.
  ///
  /// 🔴 Nunca los dos diálogos juntos: dos permisos seguidos apenas se abre la
  /// aplicación es la forma más rápida de que la persona diga que no a los dos, y el
  /// de notificaciones es el que el producto necesita.
  despuesDeEntrar,

  /// La aplicación decide cuándo, llamando a `AkPush.ofrecerUbicacion(context)`.
  /// Para quien quiera pedirla recién cuando sirve para algo — al abrir el mapa de
  /// sucursales, por ejemplo, que es cuando más gente acepta.
  laAppDecide,
}
