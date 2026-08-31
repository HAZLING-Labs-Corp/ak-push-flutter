import 'dart:async';

import '../modal_de_ubicacion.dart';
import '../politica.dart';
import '../ubicacion.dart';
import 'modulo.dart';

/// LA ZONA DONDE ESTÁ LA PERSONA, CUANDO ELLA LO PERMITE.
///
/// Sirve para dos cosas concretas: segmentar un envío por zona sin que el comercio tenga que
/// mandar la ciudad de cada quien, y ver por dónde anduvo un aparato.
///
/// ══ POR QUÉ ESTE ARCHIVO EXISTE ══
///
/// Todo esto vivía repartido en la fachada: siete métodos estáticos, un campo, una política,
/// tres líneas en el diagnóstico y dos en el inicio de sesión. Cada módulo nuevo iba a
/// agregar otros siete. Acá está junto, y la fachada no lo nombra.
///
/// ══ SÓLO APROXIMADA, Y ES UNA DECISIÓN ══
///
/// Se pide `locationWhenInUse`, que en Android es la aproximada. La precisa la acepta ~25%
/// de la gente contra ~40% la aproximada, y la de segundo plano ~10% **más un video
/// justificando el uso ante Google**. Para saber en qué zona está alguien, la aproximada
/// alcanza y sobra.
class ModuloDeUbicacion extends Modulo {
  ModuloDeUbicacion(this._ubicacion, this._politica, this._navegador);

  final Ubicacion _ubicacion;
  final PoliticaDeUbicacion Function() _politica;

  /// De dónde sacar una pantalla para dibujar el modal. Puede devolver `null` si la
  /// aplicación no le prestó su `navigatorKey` — y entonces el módulo no pregunta nada.
  final dynamic Function() _navegador;

  @override
  String get nombre => 'ubicacion';

  @override
  int get nivel => Nivel.permisoSimple;

  @override
  Cadencia get cadencia => Cadencia.periodica;

  @override
  List<String> get permisos => const ['android.permission.ACCESS_COARSE_LOCATION'];

  /// 🔴 NO SE PIDE EN EL ARRANQUE. NUNCA.
  ///
  /// Dos diálogos del sistema seguidos apenas se abre la aplicación es la forma más rápida
  /// de que la persona diga que no a los dos — y el de notificaciones es el que el producto
  /// necesita. Acá sólo se manda lo que ya se tenga permitido.
  @override
  Future<void> alIniciar(Contexto c) async {
    if (!await _ubicacion.concedido) return;
    if (c.sujetoId != null) await _ubicacion.reportarSiCorresponde(c.sujetoId!);
  }

  /// Al entrar es donde se ofrece, **después** de que el permiso de avisos se resolvió.
  @override
  Future<void> alEntrar(Contexto c) async {
    final id = c.sujetoId;
    if (id == null) return;

    // A quien ya dio permiso se le lee y listo. El freno de seis horas vive adentro de
    // `reportarSiCorresponde`, así que llamarlo en cada inicio no gasta batería.
    if (await _ubicacion.concedido) {
      await _ubicacion.reportarSiCorresponde(id);
      return;
    }

    // Y a quien no, se le ofrece — si el comercio lo activó y si el sistema todavía admite
    // preguntar. Un modal que pide algo que el sistema ya no va a mostrar no lleva a ningún
    // lado salvo a confundir.
    final p = _politica();
    if (!p.activa || p.momento != MomentoDeUbicacion.despuesDeEntrar) return;
    if (!await _ubicacion.sePuedePreguntar) return;

    final ctx = _navegador();
    if (ctx == null) return;
    final quiere = await ModalDeUbicacion.mostrar(ctx, textos: p.textos);
    if (!quiere) return;
    if (await _ubicacion.pedir()) {
      await _ubicacion.reportarSiCorresponde(id, forzar: true);
    }
  }

  @override
  Future<EstadoDeModulo> estado(Contexto c) async {
    final permitida = await _ubicacion.concedido;
    final prendida = await _ubicacion.servicioPrendido;
    final falta = <String>[
      if (!permitida) 'sin permiso',
      if (!prendida) 'el teléfono tiene la ubicación apagada',
    ];
    return EstadoDeModulo(
      // 🔴 Los dos interruptores puestos y cero posiciones NO es «anda». Un eslabón en
      // verde que hay que leer con lupa para descubrir que está en rojo es peor que no
      // tenerlo: el que diagnostica lo saltea.
      andando: permitida && prendida &&
          (_ubicacion.ultimoEnvio != null || _ubicacion.ultimoMotivo == null),
      detalle: falta.isNotEmpty
          ? falta.join(' + ')
          : (_ubicacion.ultimoEnvio == null
              ? 'nunca se mandó una posición'
              : 'última hace ${DateTime.now().difference(_ubicacion.ultimoEnvio!).inMinutes} min'),
      ultimoMotivo: _ubicacion.ultimoMotivo,
      ultimaVez: _ubicacion.ultimoEnvio,
    );
  }
}
