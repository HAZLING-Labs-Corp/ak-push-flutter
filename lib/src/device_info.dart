import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Quién es este teléfono, y cómo se llama esta aplicación.
///
/// Dos usos distintos y conviene no confundirlos:
///
///  - El **identificador del paquete** es obligatorio: sin él el servidor no
///    puede verificar que la configuración que entrega sirve para esta
///    aplicación.
///  - Todo lo demás —modelo, marca, versión— es metadata y es **opcional**. Si
///    el canal nativo que la provee no responde, el alta sigue igual. Perder el
///    modelo del teléfono cuesta un dato de inventario; perder el alta cuesta
///    que esa persona no reciba nada.
class DatosDelDispositivo {
  const DatosDelDispositivo({
    required this.identificadorDePaquete,
    required this.plataforma,
    required this.desfaseUtcMinutos,
    this.deviceId,
    this.modelo,
    this.fabricante,
    this.marca,
    this.versionDelSistema,
    this.versionDeLaApp,
    this.esFisico,
    this.zonaHorariaAbreviada,
    this.idioma,
  });

  final String identificadorDePaquete;
  final String plataforma;
  final String? deviceId;
  final String? modelo;
  final String? fabricante;
  final String? marca;
  final String? versionDelSistema;
  final String? versionDeLaApp;
  final bool? esFisico;

  // ── Cuándo y en qué idioma ──────────────────────────────────────────────
  //
  // El SDK no decide a qué hora sale un aviso —eso es del servidor—, pero es el
  // ÚNICO que puede saber en qué huso horario está el aparato: el servidor solo
  // ve una petición HTTP. Sin estos campos, «no enviar de madrugada» se calcula
  // contra la hora del servidor, y un aviso de cuota a las 3 de la mañana no se
  // lee: se desinstala la aplicación.
  //
  // 🔴 Son del APARATO, no de la persona. El idioma del teléfono es el que
  // eligió quien lo configuró, que no es necesariamente el que esa persona
  // quiere para SUS avisos —un teléfono en inglés en manos de alguien que lee
  // en español es lo más común del mundo—. Eso último es una PREFERENCIA, se
  // pregunta y se guarda contra la persona, no contra el dispositivo. Estos
  // campos sirven para adivinar bien cuando no hay preferencia, y nada más: en
  // cuanto exista una preferencia declarada, gana ella.

  /// Desfase respecto de UTC **en minutos**, con signo (Caracas: `-240`).
  ///
  /// Va siempre, porque siempre se puede calcular sin preguntarle nada a
  /// ninguna plataforma. Es el dato que de verdad permite decidir la hora de
  /// envío.
  ///
  /// Es el desfase **en el momento de recolectarlo**, no una regla: un país con
  /// horario de verano queda corrido una hora cuando cambia la estación, hasta
  /// el próximo arranque de la aplicación. Para programar con meses de
  /// anticipación en esos países haría falta el identificador IANA — ver
  /// [zonaHorariaAbreviada].
  final int desfaseUtcMinutos;

  /// Nombre corto del huso tal como lo da el sistema operativo (`VET`, `-04`,
  /// `GMT-04:00`).
  ///
  /// 🔴 **No es un identificador IANA** y el servidor no debe tratarlo como
  /// tal: no se puede pasar a una librería de husos horarios ni comparar con
  /// `America/Caracas`. Se llama «abreviada» justamente para que nadie lo
  /// confunda del otro lado.
  ///
  /// Dart no expone el identificador IANA por ningún camino, en ninguna
  /// plataforma: `DateTime.timeZoneName` devuelve lo que da la biblioteca de C
  /// del sistema, que es la abreviatura. Conseguir `America/Caracas` exige una
  /// dependencia nueva (`flutter_timezone`), y agregarla no estaba en el
  /// encargo. Mientras tanto viaja esto, que sirve para desempatar husos con el
  /// mismo desfase, más [desfaseUtcMinutos], que es lo que se usa para decidir.
  final String? zonaHorariaAbreviada;

  /// Idioma del aparato como etiqueta BCP-47 (`es-VE`, `pt-BR`).
  ///
  /// Es opcional porque puede no saberse todavía: el motor de Flutter contesta
  /// `und` mientras no le llegó el idioma del sistema.
  final String? idioma;

  /// Omite los nulos: un campo ausente y un campo con el texto "null" son cosas
  /// distintas para quien los lee del otro lado.
  Map<String, dynamic> toJson() => {
        if (deviceId != null) 'deviceId': deviceId,
        if (modelo != null) 'model': modelo,
        if (fabricante != null) 'manufacturer': fabricante,
        if (marca != null) 'brand': marca,
        if (versionDelSistema != null) 'osVersion': versionDelSistema,
        if (versionDeLaApp != null) 'appVersion': versionDeLaApp,
        if (esFisico != null) 'isPhysicalDevice': esFisico,
        // Sin `if`: este siempre se pudo calcular, así que siempre viaja.
        'utcOffsetMinutes': desfaseUtcMinutos,
        if (zonaHorariaAbreviada != null)
          'timeZoneAbbreviation': zonaHorariaAbreviada,
        // `locale` y no `language` porque lo que viaja es la etiqueta completa
        // —idioma y región—, y porque es el nombre con el que el servicio ya
        // guarda este dato.
        if (idioma != null) 'locale': idioma,
      };

  static Future<DatosDelDispositivo> recolectar() async {
    final paquete = await _leerPaquete();
    final plataforma = _plataformaActual();

    // Se leen ANTES de tocar el canal nativo y no dentro de cada rama: son
    // cálculos locales que no dependen de que el canal conteste, así que el
    // camino degradado del final los conserva igual que el camino feliz.
    final desfase = DateTime.now().timeZoneOffset.inMinutes;
    final zona = _zonaHorariaAbreviada();
    final idioma = _idiomaDelAparato();

    try {
      final info = DeviceInfoPlugin();

      if (!kIsWeb && Platform.isAndroid) {
        final a = await info.androidInfo;
        return DatosDelDispositivo(
          identificadorDePaquete: paquete.$1,
          plataforma: plataforma,
          deviceId: a.id,
          modelo: a.model,
          fabricante: a.manufacturer,
          marca: a.brand,
          versionDelSistema: a.version.release,
          versionDeLaApp: paquete.$2,
          esFisico: a.isPhysicalDevice,
          desfaseUtcMinutos: desfase,
          zonaHorariaAbreviada: zona,
          idioma: idioma,
        );
      }

      if (!kIsWeb && Platform.isIOS) {
        final i = await info.iosInfo;
        return DatosDelDispositivo(
          identificadorDePaquete: paquete.$1,
          plataforma: plataforma,
          deviceId: i.identifierForVendor,
          modelo: i.utsname.machine,
          fabricante: 'Apple',
          marca: 'Apple',
          versionDelSistema: i.systemVersion,
          versionDeLaApp: paquete.$2,
          esFisico: i.isPhysicalDevice,
          desfaseUtcMinutos: desfase,
          zonaHorariaAbreviada: zona,
          idioma: idioma,
        );
      }
    } catch (_) {
      // Degrada, no falla. Ver la nota de arriba.
    }

    return DatosDelDispositivo(
      identificadorDePaquete: paquete.$1,
      plataforma: plataforma,
      versionDeLaApp: paquete.$2,
      desfaseUtcMinutos: desfase,
      zonaHorariaAbreviada: zona,
      idioma: idioma,
    );
  }

  static Future<(String, String?)> _leerPaquete() async {
    try {
      final p = await PackageInfo.fromPlatform();
      return (p.packageName, p.version);
    } catch (_) {
      // Sin identificador de paquete el servidor no puede verificar nada, así
      // que se manda vacío y él decide: es preferible un 400 explicable a
      // inventar un identificador que no es el de esta aplicación.
      return ('', null);
    }
  }

  static String _plataformaActual() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  static String? _zonaHorariaAbreviada() {
    try {
      final nombre = DateTime.now().timeZoneName.trim();
      // Vacío no es un huso: es no saber. Y un campo ausente se distingue de un
      // campo vacío del otro lado; una cadena vacía, no.
      return nombre.isEmpty ? null : nombre;
    } catch (_) {
      return null;
    }
  }

  /// Idioma del aparato, con dos fuentes porque ninguna sirve sola.
  ///
  /// El motor de Flutter es la única que funciona en web, pero contesta `und`
  /// si todavía no le llegó el idioma del sistema —pasa en el arranque más
  /// temprano, que es exactamente cuando corre esto—. El respaldo de `dart:io`
  /// no tiene esa ventana, pero no existe en web.
  static String? _idiomaDelAparato() {
    try {
      final etiqueta = PlatformDispatcher.instance.locale.toLanguageTag();
      if (_esIdiomaUtil(etiqueta)) return etiqueta;
    } catch (_) {
      // Sigue por el respaldo: no saber el idioma nunca puede costar el alta.
    }

    if (!kIsWeb) {
      try {
        // Llega como `es_VE.UTF-8`: la codificación no es parte del idioma, y
        // el guion bajo es la convención POSIX, no la de BCP-47.
        final crudo =
            Platform.localeName.split('.').first.replaceAll('_', '-').trim();
        if (_esIdiomaUtil(crudo)) return crudo;
      } catch (_) {
        // Última fuente: si tampoco está, el campo se omite y listo.
      }
    }

    return null;
  }

  /// `und` es lo que contesta el motor cuando no sabe, y `C`/`POSIX` es la
  /// configuración de un proceso sin idioma. Mandar cualquiera de las tres es
  /// peor que no mandar nada: el servidor las tomaría por un idioma real.
  static bool _esIdiomaUtil(String etiqueta) =>
      etiqueta.isNotEmpty &&
      !etiqueta.startsWith('und') &&
      etiqueta != 'C' &&
      etiqueta != 'POSIX';
}
