import 'dart:async';

import '../api_client.dart';
import '../remote_config.dart';

/// CADA CUÁNTO MIDE UN MÓDULO.
///
/// No es un detalle de implementación: es la mitad de lo que el comercio compra. Un
/// prestamista quiere una foto al dar de alta; una operadora quiere la calidad de red en el
/// tiempo; un reparto quiere saber dónde está el repartidor *ahora*. No es más dato ni menos
/// — es otro reloj, y cada uno cuesta distinto en batería y en tráfico.
enum Cadencia {
  /// Una sola vez, cuando la persona se da de alta. Un perfil del aparato para un puntaje.
  episodica,

  /// Al abrir la aplicación, con un freno para no repetir. La ubicación aproximada.
  periodica,

  /// Cuando pasa algo. Los avisos: llegó, se abrió, se descartó.
  evento,

  /// En segundo plano, continuo. 🔴 Nivel 3: Google lo revisa a mano y puede rechazarlo.
  continua,
}

/// CUÁNTA FRICCIÓN LE PONE A LA PERSONA — y por eso, cuánto cuesta.
///
/// 🔴 El nivel no es una etiqueta: es el techo de cuánta gente va a aceptar. Y hay un límite
/// que ninguna configuración salta — los permisos de Android se declaran al COMPILAR, dentro
/// del manifest. La consola puede apagar cualquier módulo, pero **sólo puede prender los que
/// el APK ya declaró**.
class Nivel {
  /// Sin permiso. Marca, modelo, batería, espacio libre, tipo de red. Se tiene siempre.
  static const sinPermiso = 0;

  /// Permiso simple: un diálogo que se acepta o no. Avisos, ubicación aproximada.
  static const permisoSimple = 1;

  /// Permiso caro: aparece en la ficha de la tienda y baja las instalaciones.
  /// Contactos, calendario, ubicación precisa.
  static const permisoCaro = 2;

  /// Revisión manual de Google, con video justificando el uso. Ubicación en segundo plano.
  static const revisionDeGoogle = 3;
}

/// LO QUE UN MÓDULO NECESITA DEL NÚCLEO — y nada más.
///
/// 🔴 Es a propósito que sea tan poco. Un módulo que recibe la fachada entera puede llamar a
/// cualquier cosa, y a la tercera versión ya nadie sabe quién llama a quién. Esto es el
/// contrato completo: quién es la persona, cómo hablarle al servidor, y qué dijo el servidor
/// de este módulo.
class Contexto {
  const Contexto({
    required this.api,
    required this.instalacionId,
    required this.sujetoId,
    required this.config,
  });

  /// Para hablarle al servicio. Ya trae la llave y el comercio resueltos.
  final AkPushApi api;

  /// El aparato. Existe desde que arranca la aplicación, aun sin persona.
  final String instalacionId;

  /// Quién entró. **Nulo si todavía no entró nadie** — y eso es normal: la instalación
  /// nace antes que el sujeto.
  final String? sujetoId;

  /// Lo que el servidor dijo de este comercio, incluido qué módulos activó.
  final AkPushConfig? config;
}

/// CÓMO ESTÁ UN MÓDULO — para el diagnóstico, en castellano.
///
/// Existe porque los módulos se tragan sus fallos a propósito: perder una medición cuesta un
/// dato, que falle el arranque cuesta que esa persona no reciba nada. Pero ese silencio dejó
/// sin pistas a quien integra más de una vez. Acá el silencio queda registrado.
class EstadoDeModulo {
  const EstadoDeModulo({
    required this.andando,
    this.detalle,
    this.ultimoMotivo,
    this.ultimaVez,
  });

  /// Si el módulo está haciendo lo suyo hoy.
  final bool andando;

  /// Una línea que se pueda leer. «última hace 3 min», «sin permiso».
  final String? detalle;

  /// Por qué NO está andando. `null` si anda bien.
  final String? ultimoMotivo;

  /// Cuándo hizo lo suyo por última vez.
  final DateTime? ultimaVez;

  static const bien = EstadoDeModulo(andando: true);
}

/// UN MÓDULO DE COLLECTION.
///
/// ══ POR QUÉ EXISTE ESTE CONTRATO ══
///
/// Antes cada módulo se enchufaba a mano en la fachada: la ubicación le agregó siete métodos
/// estáticos, un campo, una política, tres líneas en el diagnóstico y dos en el inicio de
/// sesión. Medido el 2026-08-31, la fachada quedó en **1.498 líneas nombrando a cada módulo
/// una por una, 23 veces**. Agregar «batería» significaba volver a editar ese archivo. Cada
/// vez, y con el riesgo de romper los avisos, que viven ahí al lado.
///
/// Con esto, agregar un módulo es **escribir un archivo y sumarlo al registro**. La fachada
/// no lo nombra nunca.
///
/// ══ LO QUE UN MÓDULO PROMETE ══
///
/// 🔴 **Nunca tumba nada.** Todos los ganchos se llaman dentro de un try/catch del registro,
/// pero un módulo que se cuelga para siempre bloquea a los que siguen: cada gancho tiene que
/// terminar, con su propio tope de tiempo si hace algo que puede esperar.
///
/// 🔴 **No pide permisos por su cuenta en el arranque.** Pedirlos es una decisión de producto
/// —cuándo, con qué palabras, después de qué— y la toma el comercio desde la consola. El
/// módulo expone qué necesita y espera a que lo manden.
///
/// 🔴 **No sabe de los otros módulos.** Si dos se necesitan, se hablan por el servidor, no
/// por adentro.
abstract class Modulo {
  /// Cómo se llama en el catálogo y en la configuración del servidor. En minúsculas y sin
  /// espacios: `avisos`, `ubicacion`, `aparato`.
  String get nombre;

  /// Cuánta fricción cuesta. Ver [Nivel].
  int get nivel;

  /// Cada cuánto mide.
  Cadencia get cadencia;

  /// Los permisos de Android que necesita, con su nombre completo. Vacío para el nivel 0.
  ///
  /// Se declara acá **para poder decirlo**, no para pedirlo: sirve para que la consola
  /// muestre en gris lo que el APK no trae, y para armar el manual del comercio.
  List<String> get permisos => const [];

  /// Cuando arranca la aplicación. Todavía puede no haber nadie logueado.
  Future<void> alIniciar(Contexto c) async {}

  /// Cuando alguien inicia sesión. Es donde miden los de cadencia episódica.
  Future<void> alEntrar(Contexto c) async {}

  /// Cuando la persona sale. Lo que sea de ella se olvida; lo del aparato se queda.
  Future<void> alSalir(Contexto c) async {}

  /// Cómo está. Sale en el diagnóstico.
  Future<EstadoDeModulo> estado(Contexto c) async => EstadoDeModulo.bien;
}
