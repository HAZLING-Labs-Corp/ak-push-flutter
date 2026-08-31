import 'dart:async';
import 'dart:io' show Platform;

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disk_space_plus/disk_space_plus.dart';

import 'modulo.dart';

/// EL PULSO DEL APARATO — batería, espacio y red.
///
/// ══ POR QUÉ ESTE ES EL MÓDULO POR EL QUE CONVIENE EMPEZAR ══
///
/// **No pide un solo permiso.** No aparece en la ficha de la tienda, no hay diálogo que
/// alguien pueda rechazar, y no baja las instalaciones. Es nivel 0: se tiene en el 100% de
/// los aparatos, siempre.
///
/// Y es justo el tipo de señal que sirve para un puntaje. Un teléfono con 2% de espacio
/// libre y la batería siempre al 8% dice algo de la persona que lo usa — sin leerle un solo
/// contacto ni saber dónde está.
///
/// ══ QUÉ NO HACE ══
///
/// 🔴 No lee el número de teléfono, ni la operadora, ni el IMEI. Todo eso pide
/// `READ_PHONE_STATE`, que es nivel 2: aparece en la ficha de Play y asusta. Si algún día
/// hace falta, va en OTRO módulo — así un comercio puede tener éste sin cargar con aquél.
/// Es exactamente el error que se le vio a CredoLab en Credit CX: cuatro permisos declarados
/// que la aplicación nunca pide, arruinando la ficha por datos que jamás va a obtener.
class ModuloDeAparato extends Modulo {
  ModuloDeAparato();

  final Battery _bateria = Battery();
  final Connectivity _red = Connectivity();

  DateTime? _ultimaVez;
  String? _ultimoMotivo;

  @override
  String get nombre => 'aparato';

  @override
  int get nivel => Nivel.sinPermiso;

  /// Al dar de alta. Es una foto: para un puntaje sirve saber cómo estaba el aparato cuando
  /// esa persona entró, no seguirlo minuto a minuto.
  @override
  Cadencia get cadencia => Cadencia.episodica;

  @override
  List<String> get permisos => const [];

  @override
  Future<void> alEntrar(Contexto c) async {
    final id = c.sujetoId;
    if (id == null) return;
    try {
      final medido = await _medir();
      if (medido.isEmpty) {
        _ultimoMotivo = 'el sistema no devolvió ninguna medición';
        return;
      }
      await c.api.reportarSenales(sujetoId: id, instalacionId: c.instalacionId, senales: medido);
      _ultimaVez = DateTime.now();
      _ultimoMotivo = null;
    } catch (e) {
      // Nunca tumba nada: perder una medición cuesta un dato de segmentación; que falle el
      // inicio de sesión cuesta que esa persona no reciba nada. El motivo queda para el
      // diagnóstico, que es lo que faltaba antes.
      _ultimoMotivo = 'falló al medir o al enviar: $e';
    }
  }

  /// 🔴 CADA LECTURA VA POR SEPARADO Y CON SU PROPIO try.
  ///
  /// Un fabricante que no implementa una de estas —pasa, y sobre todo en gamas bajas— haría
  /// perder las otras tres si estuvieran en el mismo bloque. Se manda lo que se pudo leer.
  Future<Map<String, dynamic>> _medir() async {
    final m = <String, dynamic>{};

    try {
      m['bateria'] = await _bateria.batteryLevel;
      m['cargando'] = (await _bateria.batteryState) == BatteryState.charging;
    } catch (_) {/* algunos fabricantes no lo exponen */}

    try {
      // En megabytes y redondeado: el número exacto no aporta nada y cambia todo el tiempo,
      // así que guardarlo con decimales es guardar ruido.
      final libre = await DiskSpacePlus().getFreeDiskSpace;
      final total = await DiskSpacePlus().getTotalDiskSpace;
      if (libre != null) m['espacioLibreMb'] = libre.round();
      if (total != null) m['espacioTotalMb'] = total.round();
      if (libre != null && total != null && total > 0) {
        m['espacioLibrePorciento'] = ((libre / total) * 100).round();
      }
    } catch (_) {/* idem */}

    try {
      final r = await _red.checkConnectivity();
      // Sólo el TIPO de red, nunca el nombre de la wifi: el nombre de una red doméstica
      // identifica un hogar, y eso es otro nivel de dato del que este módulo declara.
      m['red'] = r.map((x) => x.name).toList();
    } catch (_) {/* idem */}

    try {
      m['sistema'] = Platform.operatingSystem;
    } catch (_) {/* idem */}

    return m;
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
}
