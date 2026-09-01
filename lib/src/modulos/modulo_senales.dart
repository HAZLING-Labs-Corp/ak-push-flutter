/// LAS SEÑALES DE NIVEL 0 — todo lo que se lee del teléfono sin pedir un permiso.
///
/// Son ~90 campos, y **no salen todos del mismo lado**. Fueron cuatro investigaciones en
/// paralelo el 2026-08-31, no una:
///
///   · Los seis primeros grupos —configuración, accesibilidad, batería, sensores, perfil y
///     red— se leen de la **API pública y documentada de Android**: `Settings.Global`,
///     `Settings.Secure`, `Settings.System`, `SensorManager`, `BatteryManager`,
///     `AccessibilityManager` y `ConnectivityManager`. Cada clave de acá abajo está en
///     developer.android.com y cualquiera puede leerlas. Lo que aportó el análisis del
///     mercado fue **cuáles de las cientos que hay vale la pena mirar**, que es una decisión,
///     no un código.
///
///   · El séptimo —`hd_`, la huella digital— **no lo tiene ningún colector del mercado**, y es
///     el único grupo con respaldo independiente: del estudio de Berg, Burg, Gombovic y Puri
///     para **NBER sobre
///     270.000 compras**, donde un modelo hecho *sólo* con huella digital —tipo de aparato,
///     sistema, hora de la compra, canal— alcanzó **AUC 69,6% contra 68,3% del FICO**. Y de la
///     revisión del mercado antifraude, donde la coherencia entre idioma, zona horaria y país
///     de la SIM es la señal más barata que existe.
///
/// 🔴 Ninguna cifra publicada por un proveedor de este sector está auditada por terceros. Las
/// de NBER sí. Y **Kreditech publicitaba 20.000 puntos de datos y quebró**: más campos no es
/// mejor puntaje. Estos se eligieron por lo que aportan, no por llenar una lista.
///
/// 🔴 NINGUNO PIDE PERMISO Y NINGUNO DICE QUIÉN ES LA PERSONA. Dicen cómo está configurado
/// el aparato y si se comporta como un teléfono de verdad. Esa distinción es la que permite
/// que este módulo nazca prendido mientras ubicación y avisos nacen apagados.
///
/// 🔴 NADA DE ESTE ARCHIVO SALE DE CÓDIGO AJENO. Ni una línea, ni una clase, ni un recurso,
/// ni una biblioteca compilada de ningún otro colector entra en este repositorio — está
/// prohibido y se comprueba: `pubspec.yaml` no declara ninguna, y no hay un solo `.jar`,
/// `.aar` ni `.dex` de terceros en el árbol. Lo de abajo está escrito en Kotlin y en Dart
/// contra la API de Android, y se puede auditar línea por línea.
///
/// **Lo que deliberadamente NO se trae**, aunque el resto del sector sí:
///
///   · La lista de sensores con vendedor y resolución. Es una huella de dispositivo bastante
///     única, y Apple prohíbe la huella combinada tenga o no consentimiento. Se manda cuántos
///     hay y cuáles de los básicos existen, que es lo que separa un teléfono de un emulador.
///   · El nombre de la aplicación marcada como depurable si no es la nuestra. Es un dato de
///     terceros que no nos corresponde y no aporta al puntaje.
///   · El BSSID y el nombre de la red WiFi. Exigen permiso de ubicación desde Android 8 y
///     además dicen dónde está la persona.
///   · La lista de paquetes de accesibilidad. Se manda cuántos hay y qué pueden hacer, que es
///     lo único que importa para decir «hay una herramienta de control remoto activa».
library;

import 'dart:io';

import 'package:flutter/services.dart';

import '../permisologia/campos.dart';
import '../permisologia/transformar.dart';
import 'modulo.dart';

export '../permisologia/campos.dart' show camposDeSenales, gruposDeSenales, GrupoDeSenales, grupoDe;

class ModuloDeSenales extends Modulo {
  ModuloDeSenales();

  static const _canal = MethodChannel('hz_collection_sdk/senales');

  DateTime? _ultimaVez;
  String? _ultimoMotivo;

  @override
  String get nombre => 'senales';

  @override
  int get nivel => Nivel.sinPermiso;

  /// Una foto al dar de alta. La configuración de un teléfono no cambia entre sesiones lo
  /// suficiente como para justificar medirla seguido.
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
      // Nunca tumba nada. Perder estas señales cuesta poder de un puntaje; que falle el
      // inicio de sesión cuesta que esa persona no reciba nada.
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

  /// Mide. Público para poder probarlo sin montar toda la fachada.
  ///
  /// 🔴 Sólo Android por ahora, y se dice en vez de devolver ceros: en iOS ni la
  /// configuración del sistema ni los servicios de accesibilidad tienen una API pública
  /// equivalente. Devolver un mapa vacío es honesto; devolverlo lleno de ceros haría que un
  /// puntaje tratara a todos los iPhone como si fueran el mismo teléfono raro.
  Future<Map<String, Object?>> medir() async {
    if (!Platform.isAndroid) return const {};
    final crudo = await _canal.invokeMapMethod<String, Object?>('medir');
    if (crudo == null || crudo.isEmpty) return const {};

    // Todo pasa por la capa de transformación, igual que el resto. Acá casi todo es
    // `taICual` porque son propiedades del aparato y no texto que haya escrito nadie — pero
    // pasa por el mismo camino para que la regla no tenga excepciones.
    return armarPaquete(camposDeSenales, Map<String, Object?>.from(crudo));
  }
}
