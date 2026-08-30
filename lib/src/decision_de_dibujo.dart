import 'dart:async';

import 'package:flutter/foundation.dart';

import 'push_message.dart';

/// Qué hacer con un aviso que **ya llegó**, cuando la aplicación está abierta.
///
/// Existe porque el único que sabe si el aviso molesta es quien escribió la
/// pantalla. Si la persona está mirando el detalle de la compra 4821 y llega el
/// aviso «tu compra 4821 fue aprobada», dibujarlo es ruido: le tapa con una
/// tarjeta lo mismo que ya tiene delante de los ojos.
enum DecisionDeDibujo {
  /// Se dibuja como siempre: visible, con el sonido y la vibración del canal.
  mostrar,

  /// No se dibuja nada. El aviso llegó igual y se sigue midiendo igual —
  /// mirá la nota de [PorteroDeDibujo] sobre qué NO apaga esta decisión.
  noMostrar,

  /// Visible en la barra, pero sin sonido ni vibración.
  ///
  /// Es el término medio para el caso más común: la persona está en la
  /// aplicación, va a ver el aviso igual porque lo tiene en pantalla, y no hace
  /// falta sobresaltarla con un ruido para algo que está mirando.
  mostrarSilencioso;

  /// Si hay que llamar al presentador.
  bool get seDibuja => this != DecisionDeDibujo.noMostrar;

  /// Si hay que dibujarlo sin sonido ni vibración.
  bool get sinRuido => this == DecisionDeDibujo.mostrarSilencioso;
}

/// Lo que la aplicación registra para opinar sobre cada aviso.
///
/// Devuelve [FutureOr] para que el caso normal —mirar en memoria qué pantalla
/// está arriba— se resuelva sin pagar un salto asincrónico, y el caso raro
/// —tener que preguntarle algo a otra parte de la app— siga siendo posible.
typedef DecidirDibujo = FutureOr<DecisionDeDibujo> Function(PushMessage);

/// Le pregunta a la aplicación si el aviso se dibuja, y se banca que la
/// aplicación conteste mal, tarde, o no conteste.
///
/// ## Lo que esta decisión NO apaga
///
/// **La decisión afecta ÚNICAMENTE al dibujo.** El evento `delivered` que se
/// reporta al servicio y el mensaje que sale por `AkPush.onMessage` ocurren
/// igual, hasta con [DecisionDeDibujo.noMostrar].
///
/// El motivo no es técnico, es de honestidad de los números: el aviso **llegó
/// al teléfono**. Que la aplicación haya decidido no dibujarlo es una decisión
/// de la aplicación, posterior a la entrega, y no cambia el hecho de que el
/// transporte funcionó. Si no reportáramos esos, la tasa de entrega del
/// comercio bajaría cada vez que su propia app decide ser prolija — y quien
/// mira el tablero concluiría que los envíos se están perdiendo, cuando en
/// realidad llegaron todos. Peor: el comercio que MÁS cuida a su gente sería el
/// que peor mide.
///
/// Y `onMessage` sigue emitiendo porque es el canal por el que la aplicación
/// reacciona al contenido —refrescar un saldo, marcar un punto rojo en el
/// menú—. Silenciar el aviso no significa ignorar lo que traía adentro.
class PorteroDeDibujo {
  PorteroDeDibujo({this.alDecidir, this.limite = limitePorDefecto});

  /// Cuánto se espera la respuesta de la aplicación.
  ///
  /// 150 ms, y es a propósito que sea incómodamente corto. Este callback corre
  /// en el camino de llegada del aviso: mientras contesta, no hay nada en la
  /// pantalla. Lo único que tiene que hacer es leer algo que la aplicación YA
  /// tiene en memoria —qué pantalla está arriba, qué pedido está abierto—, y
  /// para eso 150 ms son unos nueve cuadros a 60 Hz: alcanza de sobra incluso
  /// con la interfaz trabada.
  ///
  /// Si a alguien no le alcanzan, no es que el límite esté corto: es que su
  /// callback está yendo a la base o a la red, y eso no se hace acá. Pasado el
  /// límite se dibuja, porque un aviso tarde igual sirve y uno que nunca
  /// aparece no.
  static const Duration limitePorDefecto = Duration(milliseconds: 150);

  /// La opinión de la aplicación. En `null` —que es lo que hay hasta que
  /// alguien la asigne— se dibuja todo, como venía siendo antes de que esto
  /// existiera.
  DecidirDibujo? alDecidir;

  final Duration limite;

  /// Resuelve qué hacer con [mensaje]. **Nunca falla y nunca cuelga**: ante
  /// cualquier duda contesta [DecisionDeDibujo.mostrar].
  ///
  /// Toda la pieza está inclinada hacia mostrar por una asimetría de daño: un
  /// aviso de más es una molestia de un segundo; uno de menos puede ser el pago
  /// que venció o el código que no llegó. Ninguna falla en el código ajeno
  /// justifica el segundo.
  Future<DecisionDeDibujo> resolver(PushMessage mensaje) async {
    final consulta = alDecidir;

    // Nadie opinó: se dibuja. Esta rama es la que hace que agregar el portero
    // no cambie el comportamiento de quien ya integró el paquete y no se enteró
    // de que ahora se puede opinar.
    if (consulta == null) return DecisionDeDibujo.mostrar;

    // La pregunta pasa por una función `async` NUESTRA en vez de ir derecho al
    // callback, y no es adorno. Hace dos cosas que hacen falta:
    //
    // 1. Una excepción tirada de forma sincrónica —lo más común, un `!` sobre
    //    algo nulo— queda adentro del future y cae en el `catch` de abajo. Si
    //    no, escapa antes del `await` y se lleva puesto el manejador de llegada
    //    entero, aviso incluido.
    // 2. El future que se le pasa a `timeout` es de tipo `Future<DecisionDeDibujo>`
    //    de verdad. `Future.sync` devolvería el que dio el callback tal cual, y
    //    un `(m) async => throw ...` es un `Future<Never>` en tiempo de
    //    ejecución: ahí `timeout` revienta porque exige un `onTimeout` que
    //    devuelva `Never`. Es decir, el atajo se rompía justo con el callback
    //    roto que veníamos a proteger.
    Future<DecisionDeDibujo> preguntar() async => consulta(mensaje);

    try {
      // Si el callback tarda de más y DESPUÉS falla, `timeout` descarta ese
      // error: ya se decidió mostrar y no hay nada que revisar ni nadie
      // esperando la respuesta.
      return await preguntar()
          .timeout(limite, onTimeout: () => DecisionDeDibujo.mostrar);
    } catch (error, traza) {
      // El callback es código del comercio, no nuestro. Que se les rompa no
      // puede costarle a la persona un aviso que sí quería ver.
      //
      // Se avisa sólo en depuración: en producción no hay a quién avisarle, y
      // un `print` por aviso ensuciaría los registros del comercio. Sin esta
      // línea, un callback roto es indistinguible de uno que no existe — se ve
      // «todo se dibuja» y nadie se entera nunca de por qué.
      assert(() {
        debugPrint('[ak_push] alDecidirDibujo falló, se muestra igual:\n'
            '$error\n$traza');
        return true;
      }());
      return DecisionDeDibujo.mostrar;
    }
  }
}
