/// Recibir notificaciones push con una llave y una línea.
library;

export 'src/ak_push.dart' show AkPush, manejadorDeSegundoPlano;
export 'src/decision_de_dibujo.dart' show DecidirDibujo, DecisionDeDibujo;
export 'src/diagnostico.dart'
    show
        Diagnostico,
        Eslabon,
        EstadoDeFirebase,
        EstadoDeLaConfiguracion,
        EstadoDelRegistro,
        EstadoDelToken;
export 'src/errors.dart' show AkPushError, AkPushErrorCode;
export 'src/consentimiento.dart' show Consentimiento;
export 'src/politica.dart'
    show
        PoliticaDeNotificaciones,
        MomentoDelPermiso,
        TextosDeLaPregunta,
        AccionDePermiso,
        Disparador,
        decidirQueHacer;
export 'src/sesion.dart'
    show ResultadoDeSesion, HuellaDelRegistro, PlanDeSesion, planearInicioDeSesion, motivoDeSesion;
// `EstadoDelPermiso` es el tipo que devuelven AkPush.estadoDelPermiso() y
// AkPush.pedirPermiso(): sin este export nadie puede nombrarlo para guardarlo en
// una variable. `GestorDePermiso` queda adentro, detrás de la fachada.
export 'src/permiso.dart' show EstadoDelPermiso;
// La campanita hecha, y el estado de los avisos en castellano. Quien quiera dibujar
// su propia campana usa `EstadoDeAvisos` + `AkPush.avisos` + `AkPush.resolverAvisos()`;
// quien no quiera dibujar nada pone `AkPush.campanita()` y listo.
export 'src/campanita.dart' show CampanitaDeAvisos, EstadoDeAvisos;
export 'src/modal_de_ubicacion.dart' show ModalDeUbicacion;
export 'src/politica.dart'
    show PoliticaDeUbicacion, TextosDeUbicacion, MomentoDeUbicacion;
export 'src/push_message.dart' show AccionDePush, PushMessage;
export 'src/remote_config.dart' show AkPushConfig;
// `AvisoConRuta` va en el `show` o los atajos `mensaje.tieneRuta` y
// `mensaje.ruta` no existen para quien integra: una extensión que no se exporta
// no se aplica del otro lado.
export 'src/ruta.dart' show AvisoConRuta, IntencionPendiente, RutaDelAviso;
