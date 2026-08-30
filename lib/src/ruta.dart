import 'dart:async';

import 'package:flutter/foundation.dart';

import 'push_message.dart';

/// El ruteo del toque, por convención.
///
/// Sin esto, cada comercio escribe el mismo `switch` sobre `code_event` para
/// decidir a qué pantalla ir, y lo escribe distinto. La convención mueve esa
/// decisión al servidor del comercio, que es el único que sabe a dónde apunta
/// cada aviso el día que lo manda: cambiar el destino de una campaña deja de
/// exigir una versión nueva en las tiendas.
///
/// ## El contrato — esto es lo que el backend del comercio tiene que mandar
///
/// Dentro de `data`, dos claves y nada más:
///
/// ```json
/// {
///   "ruta": "/compras/:id",
///   "ruta_id": "9912",
///   "ruta_tab": "pagos"
/// }
/// ```
///
/// - **`ruta`** es lo único obligatorio. Un camino absoluto, empezando con `/`,
///   con o sin marcadores `:nombre`. Mandar la ruta ya resuelta —
///   `"/compras/9912"` — es igual de válido y no necesita ningún parámetro.
/// - **`ruta_<nombre>`** son los parámetros, sueltos y planos: `ruta_id` es el
///   parámetro `id`.
///
/// El resultado de arriba es `destino == '/compras/9912'` y
/// `parametros == {'id': '9912', 'tab': 'pagos'}`.
///
/// ### Por qué parámetros sueltos con prefijo, y no un JSON en `params`
///
/// `data` de FCM es un mapa plano de texto: un objeto anidado tendría que
/// viajar serializado, y entonces **existe la posibilidad de que no parsee**.
/// Un aviso con el JSON mal armado dejaría de rutear sin ningún síntoma —
/// llega, se ve, se toca, y no pasa nada—. Con claves planas no hay nada que
/// parsear y por lo tanto nada que pueda fallar; además se leen de un vistazo
/// en la consola de FCM y en los registros del servicio, que es donde se
/// diagnostica cuando un aviso «no abre donde tenía que abrir».
///
/// ### Y por qué el prefijo `ruta_` y no claves libres
///
/// Porque `data` ya es de alguien: `pushLogId`, `code_event`, `type` y
/// `channelId` los usa este paquete. Un comercio que mandara un parámetro
/// llamado `type` rompería la detección de señales sin enterarse. El prefijo
/// reserva un espacio propio y hace imposible esa colisión.
///
/// ### La ruta también puede traer su propia consulta
///
/// `"/compras/9912?tab=pagos"` funciona: lo que venga después del `?` entra
/// como parámetro igual, porque es lo que un backend escribe naturalmente y no
/// tiene sentido que sea un error. Si el mismo nombre viniera por los dos
/// caminos, **gana `ruta_<nombre>`**, que es el canal que documenta el
/// contrato.
@immutable
class RutaDelAviso {
  factory RutaDelAviso({
    required String cruda,
    Map<String, String> parametros = const <String, String>{},
  }) {
    final limpia = cruda.trim();
    return RutaDelAviso._(
      limpia,
      Map<String, String>.unmodifiable(parametros),
      _resolver(limpia, parametros),
    );
  }

  const RutaDelAviso._(this.cruda, this.parametros, this.destino);

  /// La clave de la ruta dentro de `data`.
  static const String claveDeRuta = 'ruta';

  /// El prefijo de los parámetros dentro de `data`.
  static const String prefijoDeParametro = 'ruta_';

  /// La ruta tal cual la mandó el servidor, con sus marcadores sin reemplazar.
  ///
  /// Se conserva porque es lo que hay que mostrarle a alguien cuando un aviso
  /// no abre donde debía: `destino` ya perdió la forma original y con ella la
  /// pista de qué marcador quedó sin valor.
  final String cruda;

  /// Los parámetros ya separados. Es de solo lectura: quien la reciba no puede
  /// modificar la intención que otro consumidor todavía no leyó.
  final Map<String, String> parametros;

  /// La ruta lista para entregarle al navegador de la aplicación, con los
  /// marcadores reemplazados por sus valores.
  ///
  /// Un marcador sin parámetro se queda literal —`/compras/:id`—. Es a
  /// propósito: el navegador de la aplicación no va a encontrar esa ruta y el
  /// fallo se ve. Inventarle un valor la haría navegar a otro lado, que es el
  /// mismo error pero mudo.
  final String destino;

  /// Si esta ruta alcanza para navegar a algún lado.
  ///
  /// Lo que devuelve [desde] siempre lo cumple —una ruta vacía es `null`, no
  /// una [RutaDelAviso] hueca—, así que este getter es para lo que se arma a
  /// mano y para el valor que expone [IntencionPendiente], donde el consumidor
  /// recibe algo que puede no tener a dónde ir.
  bool get tieneRuta => cruda.isNotEmpty;

  /// Saca la ruta de un aviso, si la trae.
  ///
  /// Devuelve `null` cuando el aviso no trae ruta, que es el caso **normal**:
  /// la enorme mayoría de los avisos solo informan y no llevan a ninguna
  /// pantalla. No es un error y no se registra como tal.
  static RutaDelAviso? desde(PushMessage mensaje) {
    final cruda = (mensaje.data[claveDeRuta] ?? '').trim();
    if (cruda.isEmpty) return null;

    // La consulta primero para que los parámetros explícitos la pisen: si el
    // mismo nombre llega por los dos caminos, manda el que documenta el
    // contrato.
    final parametros = <String, String>{..._consultaDe(cruda)};

    for (final par in mensaje.data.entries) {
      if (!par.key.startsWith(prefijoDeParametro)) continue;
      final nombre = par.key.substring(prefijoDeParametro.length);
      if (nombre.isEmpty) continue;
      parametros[nombre] = par.value;
    }

    return RutaDelAviso(cruda: cruda, parametros: parametros);
  }

  static Map<String, String> _consultaDe(String cruda) {
    final corte = cruda.indexOf('?');
    if (corte < 0) return const <String, String>{};
    try {
      return Uri.splitQueryString(cruda.substring(corte + 1));
    } on FormatException {
      // Una consulta mal escapada no puede costar el ruteo entero: el camino
      // sigue siendo válido y llevar a la pantalla sin un parámetro es mejor
      // que no llevar a ninguna.
      return const <String, String>{};
    }
  }

  /// Reemplaza segmento por segmento y no con una expresión regular sobre todo
  /// el texto: así un valor que contenga `:` no puede convertirse a su vez en
  /// un marcador.
  static String _resolver(String cruda, Map<String, String> parametros) {
    final corte = cruda.indexOf('?');
    final camino = corte < 0 ? cruda : cruda.substring(0, corte);
    final consulta = corte < 0 ? '' : cruda.substring(corte + 1);

    final resuelto = camino.split('/').map((segmento) {
      if (segmento.length < 2 || !segmento.startsWith(':')) return segmento;
      return parametros[segmento.substring(1)] ?? segmento;
    }).join('/');

    if (consulta.isEmpty) return resuelto;
    return '$resuelto?${_consultaAlDia(consulta, parametros)}';
  }

  /// Pisa en la consulta los valores que también llegaron por `ruta_<nombre>`.
  ///
  /// 🔴 Sin esto, la precedencia que promete el contrato valía sólo para
  /// [parametros] y no para [destino] — y [destino] es lo que se le pasa al
  /// navegador. Un aviso con `"ruta": "/compras/9912?tab=viejo"` y
  /// `"ruta_tab": "nuevo"` abría la pestaña vieja mientras `parametros` decía
  /// la nueva: dos verdades para el mismo aviso, y la que se ve en pantalla era
  /// justamente la que el contrato dice que pierde.
  ///
  /// Toca lo mínimo: sólo se reescribe el par que de verdad contradice, y con
  /// sus bytes originales si el valor ya coincidía. Reconstruir la consulta
  /// entera cambiaría el escapado de rutas que hoy funcionan, por un caso que
  /// casi nunca se da.
  static String _consultaAlDia(
    String consulta,
    Map<String, String> parametros,
  ) {
    if (parametros.isEmpty) return consulta;

    return consulta.split('&').map((par) {
      final igual = par.indexOf('=');
      if (igual <= 0) return par;
      try {
        final nombre = Uri.decodeQueryComponent(par.substring(0, igual));
        final nuevo = parametros[nombre];
        if (nuevo == null) return par;
        if (nuevo == Uri.decodeQueryComponent(par.substring(igual + 1))) {
          return par;
        }
        return '${par.substring(0, igual)}=${Uri.encodeQueryComponent(nuevo)}';
      } catch (_) {
        // Un par mal escapado se deja como vino: una consulta que no se puede
        // leer no puede costar el ruteo, igual que en `_consultaDe`. Se atrapa
        // ancho a propósito, porque decodificar tira dos cosas distintas según
        // dónde falle: `ArgumentError` si el `%` está truncado y
        // `FormatException` si los bytes no son UTF-8 válido.
        return par;
      }
    }).join('&');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RutaDelAviso &&
          other.cruda == cruda &&
          mapEquals(other.parametros, parametros);

  @override
  int get hashCode => Object.hash(cruda, parametros.length);

  @override
  String toString() => 'RutaDelAviso($destino, parametros: $parametros)';
}

/// Los atajos para preguntarle a un aviso por su ruta.
extension AvisoConRuta on PushMessage {
  /// Si este aviso trae ruta. Contesta sin construir nada, para poder filtrar
  /// un flujo de avisos sin pagar el análisis de cada uno.
  bool get tieneRuta =>
      (data[RutaDelAviso.claveDeRuta] ?? '').trim().isNotEmpty;

  /// La ruta de este aviso, o `null` si no trae.
  RutaDelAviso? get ruta => RutaDelAviso.desde(this);
}

/// El guardador de la última ruta pendiente.
///
/// ## Por qué existe
///
/// Un toque puede llegar con la aplicación **muerta**. El sistema la arranca
/// para entregarlo, y el camino hasta la pantalla que sabe navegar cruza el
/// arranque entero: `AkPush.init()`, Firebase, el primer cuadro, el árbol de
/// widgets. Cuando el toque llega, el navegador de la aplicación **todavía no
/// existe**. Una ruta entregada en ese momento no se pierde por un error: se
/// pierde porque no hay nadie del otro lado.
///
/// ## Las tres cosas que hace
///
/// 1. **Guarda** la ruta cuando llega el toque, sin importar en qué estado esté
///    la aplicación.
/// 2. **La entrega una sola vez.** [consumir] la devuelve y la limpia, porque
///    una intención que se puede leer dos veces se navega dos veces: el segundo
///    consumidor —o el mismo, después de un `hot reload` o de volver a montar
///    la pantalla— abriría de nuevo algo que la persona ya cerró.
/// 3. **Es observable.** El toque también llega con la aplicación abierta y el
///    consumidor ya montado. Leer solo al montar cubriría la llegada en frío y
///    perdería la caliente; escuchar solo un flujo cubriría la caliente y
///    perdería la fría, porque el aviso llegó antes de que hubiera quién
///    escuchara. Por eso guarda **y** avisa: [alLlegar] resuelve los dos casos
///    con una sola llamada.
///
/// ## Y por qué NO se persiste en disco
///
/// Una intención que sobrevive al proceso es una intención que nadie pidió. La
/// persona tocó un aviso, la aplicación se cerró sin llegar a la pantalla, y
/// tres días después abre la aplicación para otra cosa y aparece en el detalle
/// de una compra vieja. Eso no se lee como una función: se lee como un fantasma
/// y se reporta como un error. El toque vale para el arranque que lo recibió.
class IntencionPendiente extends ChangeNotifier
    implements ValueListenable<RutaDelAviso?> {
  IntencionPendiente();

  /// Única por proceso, como el presentador: quien guarda —el paquete— y quien
  /// consume —la aplicación— no se conocen y no tienen cómo pasarse una
  /// instancia.
  static final IntencionPendiente instancia = IntencionPendiente();

  RutaDelAviso? _pendiente;

  /// La ruta que está esperando ser consumida, sin consumirla.
  ///
  /// Sirve para mirar, no para navegar: quien navegue mirando esto y no
  /// llamando a [consumir] va a volver a navegar en el próximo cuadro.
  RutaDelAviso? get pendiente => _pendiente;

  /// Lo mismo que [pendiente]. El nombre en inglés lo exige `ValueListenable`,
  /// que es lo que permite usar esta clase con `ValueListenableBuilder` sin
  /// envolverla en nada.
  @override
  RutaDelAviso? get value => _pendiente;

  /// Si hay algo esperando.
  bool get hayPendiente => _pendiente != null;

  /// Guarda la ruta y avisa a quien esté escuchando.
  ///
  /// Guarda **la última**: si llegan dos toques antes de que alguien consuma,
  /// vale el segundo. Es lo que la persona hizo último, y encolarlos abriría
  /// una pantalla que ya no quiere ver.
  void guardar(RutaDelAviso ruta) {
    _pendiente = ruta;
    notifyListeners();
  }

  /// Guarda la ruta del aviso, si el aviso trae una.
  ///
  /// Devuelve si guardó algo. Es la línea que va en el manejador del toque: un
  /// aviso sin ruta no toca nada, y en particular **no borra** una intención
  /// anterior que todavía nadie consumió.
  bool guardarDesde(PushMessage mensaje) {
    final ruta = RutaDelAviso.desde(mensaje);
    if (ruta == null) return false;
    guardar(ruta);
    return true;
  }

  /// Devuelve la ruta pendiente **una vez** y la limpia.
  ///
  /// Devuelve `null` si no hay nada, que es lo normal en casi todos los
  /// arranques.
  RutaDelAviso? consumir() {
    final ruta = _pendiente;
    if (ruta == null) return null;
    _pendiente = null;
    // También se avisa al limpiar: un `ValueListenableBuilder` que esté
    // dibujando algo a partir de la intención tiene que enterarse de que ya no
    // está, o queda mostrando un destino que otro ya se llevó.
    notifyListeners();
    return ruta;
  }

  /// Tira la intención sin entregarla.
  ///
  /// Es lo que hay que llamar al cerrar sesión: una ruta guardada apunta a los
  /// datos de la persona que estaba usando el teléfono, y entregarla después
  /// del cierre la llevaría a la pantalla de otro.
  void limpiar() {
    if (_pendiente == null) return;
    _pendiente = null;
    notifyListeners();
  }

  /// Registra al consumidor que navega, y cubre los dos casos de una vez: le
  /// entrega la ruta que ya estaba guardada —el toque en frío, que llegó antes
  /// de que existiera esta pantalla— y todas las que lleguen después —el toque
  /// caliente, con la aplicación abierta—.
  ///
  /// La entrega es siempre diferida a la microtarea siguiente, nunca dentro del
  /// cuadro en curso: quien llame a esto lo va a hacer desde `initState`, y
  /// navegar mientras el árbol se está construyendo revienta con un error de
  /// Flutter que no tiene nada que ver con las notificaciones.
  ///
  /// Devuelve la función para dejar de escuchar. Llamarla en `dispose` no es
  /// opcional: un consumidor muerto que siga suscrito consume la intención que
  /// le tocaba al que está vivo.
  VoidCallback alLlegar(void Function(RutaDelAviso ruta) navegar) {
    // 🔴 Darse de baja tiene que alcanzar TAMBIÉN a la entrega que ya salió.
    // Entre el aviso y la microtarea que consume pasa un cuadro, y en ese
    // cuadro la pantalla se puede desmontar. Sin esta bandera, el toque que
    // llega justo mientras se cierra una pantalla se lo lleva un consumidor ya
    // muerto —navega sobre un `State` desmontado— y encima deja la intención
    // consumida, así que el que se monta después no encuentra nada: el toque no
    // va a ningún lado y no queda ningún rastro de por qué. `removeListener`
    // solo no alcanza, porque la microtarea ya estaba encolada cuando se llamó.
    var vigente = true;

    void entregar() {
      scheduleMicrotask(() {
        if (!vigente) return;
        final ruta = consumir();
        if (ruta != null) navegar(ruta);
      });
    }

    addListener(entregar);
    entregar();
    return () {
      vigente = false;
      removeListener(entregar);
    };
  }
}
