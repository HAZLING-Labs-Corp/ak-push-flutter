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
    this.deviceId,
    this.modelo,
    this.fabricante,
    this.marca,
    this.versionDelSistema,
    this.versionDeLaApp,
    this.esFisico,
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
      };

  static Future<DatosDelDispositivo> recolectar() async {
    final paquete = await _leerPaquete();
    final plataforma = _plataformaActual();

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
        );
      }
    } catch (_) {
      // Degrada, no falla. Ver la nota de arriba.
    }

    return DatosDelDispositivo(
      identificadorDePaquete: paquete.$1,
      plataforma: plataforma,
      versionDeLaApp: paquete.$2,
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
}
