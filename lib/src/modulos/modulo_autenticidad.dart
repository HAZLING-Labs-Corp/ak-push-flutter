/// ¿ESTO ES UN TELÉFONO DE VERDAD, O UNA GRANJA DE DISPOSITIVOS?
///
/// Es la pregunta que más rápido destruye una cartera, y la que mejor relación
/// señal-esfuerzo tiene de todo el plan: **cuesta cero permisos**, no le muestra ningún
/// diálogo a nadie, y no dice absolutamente nada sobre la persona — dice sobre el aparato.
///
/// De dónde sale: del núcleo de CredoLab, leído de su bytecode el 2026-08-31. De los ~150
/// campos que recolecta, la batería de detectores de emulador y root es **lo que más aporta
/// y lo que menos cuesta**. Todo lo demás que hacen —contactos, calendario, cuentas— pide
/// permisos caros y da menos.
///
/// 🔴 QUÉ NO ES ESTO, y hay que decirlo antes de que alguien lo tome por más de lo que da:
///
/// **La detección de root desde una aplicación sin privilegios es, y va a seguir siendo, de
/// mejor esfuerzo.** Quien tiene el teléfono rooteado tiene más poder que nosotros sobre lo
/// que este código puede ver: hay herramientas hechas exactamente para esconderse de estas
/// comprobaciones, y funcionan. Un `false` acá significa «no encontré señales», no «este
/// teléfono está limpio», y el código lo devuelve con ese nombre a propósito.
///
/// Sirve igual, y mucho: no para atrapar a un atacante decidido, sino para separar el
/// volumen —una granja de emuladores dando de alta cuentas en serie deja rastros que nadie
/// se molesta en esconder—. Es un filtro de ruido, no una cerradura.
library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../permisologia/transformar.dart';
import 'modulo.dart';

/// Los campos que este módulo manda, y qué manda cada uno.
///
/// 🔴 Todos son `taICual` y eso está bien: ninguno viene de algo que haya escrito una
/// persona. Son propiedades del aparato y booleanos calculados. Ver `transformar.dart` — la
/// regla es que un campo que PUEDA llevar texto de alguien no use `taICual`, y acá ninguno
/// puede.
const List<CampoRecolectado> camposDeAutenticidad = [
  CampoRecolectado('esFisico', Transformacion.taICual,
      queManda: 'si el sistema dice que es un teléfono de verdad y no un emulador'),
  CampoRecolectado('pareceEmulador', Transformacion.taICual,
      queManda: 'si las propiedades del aparato coinciden con las de un emulador conocido'),
  CampoRecolectado('senalesDeEmulador', Transformacion.taICual,
      queManda: 'cuántas señales de emulador se encontraron, de las que se miran'),
  CampoRecolectado('senalesDeRoot', Transformacion.taICual,
      queManda: 'cuántas señales de root se encontraron. Cero no quiere decir limpio'),
  CampoRecolectado('compilacionDePrueba', Transformacion.taICual,
      queManda: 'si el sistema operativo está firmado con llaves de prueba y no de fábrica'),
];

class ModuloDeAutenticidad extends Modulo {
  ModuloDeAutenticidad();

  DateTime? _ultimaVez;
  String? _ultimoMotivo;

  @override
  String get nombre => 'autenticidad';

  @override
  int get nivel => Nivel.sinPermiso;

  /// Una foto al dar de alta. Un aparato no deja de ser un emulador entre sesiones, así que
  /// medirlo seguido gasta batería para confirmar lo mismo.
  @override
  Cadencia get cadencia => Cadencia.episodica;

  @override
  List<String> get permisos => const [];

  @override
  Future<void> alEntrar(Contexto c) async {
    final id = c.sujetoId;
    if (id == null) return;
    try {
      final medido = await medir();
      if (medido.isEmpty) {
        _ultimoMotivo = 'el sistema no devolvió ninguna medición';
        return;
      }
      await c.api.reportarSenales(
        sujetoId: id,
        instalacionId: c.instalacionId,
        modulo: nombre,
        senales: medido,
      );
      _ultimaVez = DateTime.now();
      _ultimoMotivo = null;
    } catch (e) {
      // Igual que los demás módulos: nunca tumba nada. Perder esta medición cuesta una señal
      // antifraude; que falle el inicio de sesión cuesta que esa persona no reciba nada.
      _ultimoMotivo = 'falló al medir o al enviar: $e';
    }
  }

  @override
  Future<EstadoDeModulo> estado(Contexto c) async => EstadoDeModulo(
        andando: _ultimoMotivo == null,
        detalle: _ultimaVez == null
            ? 'todavía no midió'
            : 'midió hace ${DateTime.now().difference(_ultimaVez!).inMinutes} min',
        ultimoMotivo: _ultimoMotivo,
        ultimaVez: _ultimaVez,
      );

  /// Mide y devuelve el paquete ya transformado. Público para poder probarlo sin montar
  /// toda la fachada.
  Future<Map<String, Object?>> medir() async {
    final crudo = <String, Object?>{};

    if (Platform.isAndroid) {
      final a = await DeviceInfoPlugin().androidInfo;
      final e = _senalesDeEmuladorAndroid(a);
      crudo['esFisico'] = a.isPhysicalDevice;
      crudo['pareceEmulador'] = !a.isPhysicalDevice || e > 0;
      crudo['senalesDeEmulador'] = e;
      crudo['senalesDeRoot'] = _senalesDeRoot();
      // `test-keys` significa que el sistema no está firmado por el fabricante. Es la señal
      // de root más vieja y la más barata: no hay que tocar el disco para verla.
      crudo['compilacionDePrueba'] = a.tags.contains('test-keys');
    } else if (Platform.isIOS) {
      final i = await DeviceInfoPlugin().iosInfo;
      crudo['esFisico'] = i.isPhysicalDevice;
      crudo['pareceEmulador'] = !i.isPhysicalDevice;
      // 🔴 En iOS no se miran rutas de jailbreak. Apple trata el husmeo del sistema de
      // archivos fuera del contenedor de la aplicación como motivo de rechazo, y el dato no
      // vale que le reboten la subida al comercio que nos instale. Queda en cero, declarado.
      crudo['senalesDeEmulador'] = i.isPhysicalDevice ? 0 : 1;
      crudo['senalesDeRoot'] = 0;
      crudo['compilacionDePrueba'] = false;
    } else {
      return const {};
    }

    return armarPaquete(camposDeAutenticidad, crudo);
  }

  /// Cuántas propiedades del aparato coinciden con las de un emulador conocido.
  ///
  /// Se devuelve el CONTEO y no un booleano a propósito: una sola coincidencia puede ser un
  /// teléfono raro de verdad —hay fabricantes chicos con propiedades genéricas— y tres
  /// coincidencias ya no. Quien arme el puntaje decide dónde poner el corte; el SDK no le
  /// impone un umbral que no puede saber.
  int _senalesDeEmuladorAndroid(AndroidDeviceInfo a) {
    var n = 0;
    final huella = a.fingerprint.toLowerCase();
    final modelo = a.model.toLowerCase();
    final marca = a.brand.toLowerCase();
    final aparato = a.device.toLowerCase();
    final hw = a.hardware.toLowerCase();
    final producto = a.product.toLowerCase();

    if (huella.startsWith('generic') || huella.contains('unknown')) {
      n++;
    }
    if (huella.contains('emulator') || huella.contains('sdk_gphone')) {
      n++;
    }
    if (modelo.contains('sdk') ||
        modelo.contains('emulator') ||
        modelo.contains('android sdk built for')) {
      n++;
    }
    if (marca.startsWith('generic') && aparato.startsWith('generic')) {
      n++;
    }
    // goldfish y ranchu son los emuladores de Android; vbox y ttvm son de VirtualBox y
    // Genymotion; nox y andy son emuladores de juegos.
    if (hw.contains('goldfish') ||
        hw.contains('ranchu') ||
        hw.contains('vbox') ||
        hw.contains('ttvm') ||
        hw.contains('nox') ||
        hw.contains('andy')) {
      n++;
    }
    if (producto.contains('sdk') ||
        producto.contains('vbox') ||
        producto.contains('emulator') ||
        producto.contains('simulator')) {
      n++;
    }
    if (a.manufacturer.toLowerCase().contains('genymotion')) {
      n++;
    }
    return n;
  }

  /// Cuántas rutas conocidas de root existen.
  ///
  /// 🔴 CERO NO QUIERE DECIR LIMPIO, y por eso el campo se llama «señales de root» y no
  /// «está rooteado». Desde Android 11 el almacenamiento con alcance hace que muchas de
  /// estas rutas no sean legibles ni siquiera cuando existen, así que la ausencia no prueba
  /// nada. Y quien esconde el root a propósito usa herramientas hechas para esto.
  ///
  /// Cada comprobación va en su propio try: en un teléfono donde una ruta lanza excepción,
  /// las demás se siguen mirando.
  int _senalesDeRoot() {
    const rutas = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
      // Magisk, KernelSU y APatch: los tres gestores de root que se usan hoy.
      '/data/adb/magisk',
      '/data/adb/ksu',
      '/data/adb/ap',
      '/dev/kernelsu',
    ];
    var n = 0;
    for (final r in rutas) {
      try {
        if (File(r).existsSync() || Directory(r).existsSync()) {
          n++;
        }
      } catch (_) {
        // Una ruta que no se puede ni consultar no es una señal: es una ruta que no se pudo
        // consultar. Contarla infla el número justo en los teléfonos más cerrados.
      }
    }
    return n;
  }
}
