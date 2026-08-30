# ak_push

Recibir notificaciones push con una llave y una línea.

```yaml
dependencies:
  ak_push: ^0.1.0
```

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AkPush.init(
    llave:    'pk_live_…',              // la llave con alcance devices:write
    comercio: 'acme',                   // tu identificador de comercio
    url:      'https://…/api/v1',
  );
  runApp(const MiApp());
}
```

Los tres valores son los mismos que te muestra la consola. **La llave es lo único
secreto de los tres** — el comercio no da acceso: sirve para que una llave mal
pegada falle en el arranque en vez de mandarle avisos a los clientes de otro.

⚠️ Así como está, `init()` le pide el permiso de notificaciones a la persona en
el arranque. **Casi siempre conviene lo contrario.** Antes de publicar, leé
[El permiso](#el-permiso): es la decisión que más plata cuesta equivocar.

Cuando la persona inicia sesión:

```dart
final r = await AkPush.alIniciarSesion(userId: 'u_123');

if (!r.puedeRecibir) {
  // r.motivo dice por qué, y r.accionSugerida qué hacer al respecto
}
```

⚠️ `init()` es asíncrono. No ofrezcas el botón de inicio de sesión hasta que
resuelva, o vas a recibir `notInitialized`.

Cuando cierra sesión:

```dart
await AkPush.alCerrarSesion();
```

Eso es todo. **No pegás ningún archivo de configuración en el proyecto.** La cuenta
de Google la sirve nuestro servidor en cada arranque.

---

## Iniciar sesión hace más que registrar

`alIniciarSesion()` es la puerta por la que el teléfono queda en orden para esa
persona. Adentro, en este orden:

1. **Si había otra persona en este teléfono, la da de baja.** Antes de tocar nada
   más: si el registro nuevo falla a mitad, el teléfono queda sin dueño y no con
   el anterior, que seguiría recibiendo lo suyo.
2. **Le pregunta al sistema operativo por el permiso.** No confía en lo que tenía
   guardado: la persona pudo haberlo apagado desde los Ajustes hace seis meses y
   nada te avisó.
3. **Decide qué hacer** según lo que configuró tu comercio.
4. **Registra sólo si algo cambió.**

Y te devuelve el resumen:

```dart
r.puedeRecibir        // ¿le va a llegar o no? — casi siempre alcanza con esto
r.estadoDelPermiso    // los cinco estados
r.accionSugerida      // qué te toca hacer AHORA
r.huboCambioDePersona // había otra y se le dio de baja
r.motivo              // la frase que explica por qué no puede recibir
```

`r.motivo` es para tu registro o para un ticket. **No para mostrárselo a la
persona**: eso lo escribís vos, con tu voz.

---

## Lo que configura tu comercio, sin que publiques nada

Cuándo pedir el permiso no lo decide tu código: lo decide tu comercio desde la
consola, y viaja con la configuración.

```dart
AkPush.politica.momento             // arranque · login · laAppDecide
AkPush.politica.obligatorio         // lo considera indispensable
AkPush.politica.preguntaBlanda      // si mostrás tu pantalla antes
AkPush.politica.reintentarCadaDias
AkPush.politica.textos              // titulo · cuerpo · aceptar · ahoraNo
```

Los textos son de tu comercio y hablan con su voz — por eso viajan, en vez de
estar escritos en el paquete.

> **«Obligatorio» no puede significar lo que suena.** Ningún SDK puede forzar a
> nadie a aceptar notificaciones: el diálogo es del sistema operativo y la
> respuesta es de la persona. Significa que tu comercio lo considera
> indispensable, para que tu app insista. Qué hacés con esa señal es tuyo.

Mientras el servicio no sirva la política, podés declararla vos:

```dart
await AkPush.init(
  llave: '…', comercio: '…',
  politicaPorDefecto: const PoliticaDeNotificaciones(
    momento: MomentoDelPermiso.login,
    preguntaBlanda: true,
  ),
);
```

Cuando el servicio la mande, gana la del servidor.

---

## Marcá lo que contestó en tu modal

Si mostrás la pregunta blanda, avisale al SDK qué contestó — **en los dos casos,
no sólo cuando acepta**:

```dart
final si = await mostrarMiPantalla();
await AkPush.reportarModal(acepto: si);
if (si) await AkPush.pedirPermiso();
```

Un «ahora no» también es un dato, y es el que distingue a quien se puede
recuperar de quien ya dijo que no de verdad.

### Por qué importa: son dos preguntas, no una

| | quién la levanta | si dice que no |
|---|---|---|
| tu modal | **tu app** | no cuesta nada · se le vuelve a preguntar |
| el diálogo | **el sistema operativo** | en iPhone, definitivo |

Alguien puede decir **que sí al tuyo y que no al del sistema**. Sin marcarlo, esa
persona queda igual que quien nunca vio nada — siendo situaciones opuestas.

```dart
AkPush.consentimiento.punto
// sin_preguntar · dijo_ahora_no · esperando_al_sistema
// acepto · denego_en_el_sistema
```

---

## Lo único que tenés que darnos

**El identificador de tu aplicación** — `com.tuempresa.app` en Android, el *bundle
id* en iOS. Lo necesitamos para registrarla y para verificar que la configuración
que te entregamos sirve para tu aplicación y no para otra.

Es lo único. No hay más.

---

## Lo que sí queda en tu compilación

Dos cosas no se pueden mover a tiempo de ejecución, y las tenés resueltas si tu
app ya está publicada:

| | |
|---|---|
| El identificador del paquete | Se fija al compilar. Si la app ya está publicada, no se puede cambiar |
| Recibir notificaciones en iPhone | Es una capacidad que se activa al compilar, con tu perfil de Apple |

### Android

**1 · Habilitar *core library desugaring*.** Lo exige la librería que dibuja el
aviso cuando tu app está abierta. Sin esto la compilación falla con
`requires core library desugaring to be enabled`.

En `android/app/build.gradle.kts`:

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

**2 · El canal por defecto.** En `AndroidManifest.xml`, dentro de `<application>`:

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="default" />
```

Sin eso, los avisos que llegan con la app cerrada caen en un canal que no existe.

**3 · El permiso**, en Android 13 y superiores:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### iOS

Activar *Push Notifications* en las capacidades del proyecto en Xcode.

---

## El permiso

Un push no llega si la persona no dijo que sí. El que pregunta es el sistema
operativo, con un diálogo suyo. Tu aplicación no lo dibuja, no lo cambia y no lo
puede repetir.

**Ese diálogo se gasta.** Se muestra una vez y no vuelve.

### Por defecto se pide en el arranque, y eso casi nunca conviene

`init()` viene con `pedirPermisoAlIniciar: true`, porque es lo que este paquete
hacía desde la primera versión. Así, el diálogo salta apenas la persona abre la
aplicación por primera vez.

Es el peor momento posible. Todavía no sabe qué hace tu aplicación. No tiene con
qué contestar. Y el «no» que se lleva ahí no se recupera nunca más.

### Cuánto dura un «no»

| | |
|---|---|
| iPhone | El diálogo se muestra **una sola vez en la vida de la instalación**. Después, solo los Ajustes del teléfono |
| Android 13 y superiores | Alcanzan **dos descartes** para que el sistema lo dé por denegado y no lo muestre más |
| Android 12 y anteriores | No hay diálogo. Los avisos vienen encendidos de fábrica; si la persona los apaga, solo los Ajustes los vuelven a encender |

A los Ajustes no va casi nadie. En los hechos, un «no» es para siempre.

### La pregunta blanda

Primero mostrás **una pantalla tuya**. Tu marca, tus palabras, en el momento en
que el aviso ya se entiende: después de la primera compra, cuando queda un pago
por vencer, al terminar el alta.

Y solo si ahí la persona dice que sí, disparás el diálogo del sistema.

Eso convierte un «no» irreversible en un «ahora no». Quien dice que no en tu
pantalla se lo podés volver a ofrecer la semana que viene: el diálogo del sistema
sigue entero. Quien dice que no en el diálogo del sistema no vuelve.

**Esa pantalla la escribís vos.** El paquete no la trae, y no debería: es tuya.

### El camino recomendado

Al arrancar, no pidas nada. `init()` solo lee lo que ya haya:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AkPush.init(
    llave: 'pk_live_…', comercio: 'acme',
    pedirPermisoAlIniciar: false,
  );
  runApp(const MiApp());
}
```

Y cuando el aviso ya tiene sentido para la persona, ofrecelo:

```dart
Future<void> ofrecerAvisos(BuildContext context) async {
  final estado = await AkPush.estadoDelPermiso();

  // Ya recibe. No hay nada que ofrecer.
  if (estado.permiteRecibir) return;

  // El diálogo del sistema ya no existe. Solo quedan los Ajustes.
  if (estado.soloQuedanLosAjustes) {
    if (await miPantallaQueMandaALosAjustes(context)) {
      await AkPush.abrirAjustesDeNotificaciones();
    }
    return;
  }

  // Queda diálogo: primero tu pantalla, y el diálogo solo si dice que sí.
  if (estado.puedeVolverAPreguntarse) {
    if (await miPantallaQueExplica(context)) {
      await AkPush.pedirPermiso();
    }
  }
}

// Las dos son tuyas. Devuelven `true` si la persona apretó el botón de aceptar.
Future<bool> miPantallaQueExplica(BuildContext context) async => ...;
Future<bool> miPantallaQueMandaALosAjustes(BuildContext context) async => ...;
```

`estadoDelPermiso()` **no dispara ningún diálogo**: se puede llamar todas las
veces que haga falta. `pedirPermiso()` sí — es la línea que gasta el diálogo, y
por eso es la única que va detrás de un «sí» de la persona.

Las dos se llaman después de `init()`.

### Los cinco estados

| `EstadoDelPermiso` | qué pasó | qué hacer |
|---|---|---|
| `sinPreguntar` | Nadie preguntó todavía. El diálogo está entero | La pregunta blanda |
| `concedido` | Hay permiso. Los avisos llegan y se ven | Nada |
| `denegado` | Dijo que no, pero queda un diálogo más. En los hechos, solo en Android 13+ | La pregunta blanda. Es la última |
| `denegadoParaSiempre` | Dijo que no y el diálogo no se muestra más | Los Ajustes |
| `provisional` | iOS: los avisos entran al centro de notificaciones en silencio, sin interrumpir | Se puede ofrecer pasar a avisos que sí interrumpen |

Y tres preguntas, para no ramificar sobre los cinco:

| | |
|---|---|
| `permiteRecibir` | Si con este estado el teléfono recibe avisos. `provisional` cuenta |
| `puedeVolverAPreguntarse` | Si mostrar tu pantalla sirve de algo, o termina en un botón que no puede hacer nada |
| `soloQuedanLosAjustes` | Si la única puerta que queda es la del teléfono |

No son opuestas. `concedido` recibe y no admite diálogo; `denegadoParaSiempre` no
recibe y tampoco lo admite.

### Volvé a leer el estado cuando la app vuelve del segundo plano

El permiso se cambia desde los Ajustes del teléfono, y **nada le avisa a tu
aplicación** cuando eso pasa.

Releerlo no es solo mirar: si la persona activó los avisos, esa misma llamada
consigue la dirección del teléfono y lo vuelve a dar de alta sola. Sin eso, hay
permiso y no llega nada.

```dart
class _MiAppState extends State<MiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) AkPush.estadoDelPermiso();
  }
}
```

### Cuando ya está denegado para siempre

Queda una sola puerta:

```dart
final abrio = await AkPush.abrirAjustesDeNotificaciones();
```

Devuelve si se pudo abrir la pantalla. **No** si la persona activó algo — eso no
se puede saber desde la app. Se sabe al volver, releyendo el estado.

Abre la ficha de tu aplicación y no la pantalla exacta de notificaciones: no hay
forma de llegar directo en las dos plataformas. Desde la ficha están a un toque.

⚠️ No muestres acá una pantalla que prometa activar los avisos con un botón. El
botón no puede hacer nada: `pedirPermiso()` en este estado no muestra ningún
diálogo y devuelve lo mismo que había.

### Sin permiso no hay dirección

Sin permiso el teléfono no tiene dirección a la cual enviarle. En iPhone es
literal: el sistema no la emite hasta que la persona dice que sí.

`identify()` funciona igual — guarda a la persona y no falla. El alta al servidor
sale sola en cuanto haya permiso. No hace falta acordarse de llamarlo de nuevo.

---

## Escuchar lo que llega

```dart
AkPush.onMessage.listen((m) {
  // Llegó con la app abierta. Ya lo dibujamos nosotros:
  // FCM no dibuja nada en primer plano.
});

AkPush.onNotificationTap.listen((m) {
  // La persona lo tocó. Venga de donde venga:
  // app abierta, en segundo plano o cerrada.
  final codigo = m.codeEvent;
});
```

`PushMessage` trae `title`, `body` y `data`, más tres atajos: `pushLogId`
(el envío), `codeEvent` (el aviso) y `signal` (los avisos que solo te dicen «andá
a revisar algo»).

La entrega y la apertura las contamos nosotros. Las otras tres acciones dependen
de cómo esté hecha tu app, así que las reportás vos:

```dart
await AkPush.reportar(mensaje, AccionDePush.viewed);      // lo vio sin abrirlo
await AkPush.reportar(mensaje, AccionDePush.dismissed);   // lo descartó
await AkPush.reportar(mensaje, AccionDePush.expired);     // caducó
```

---

## Cuándo dibujar el aviso, y cuándo no

Con la app abierta, el aviso lo dibujamos nosotros. Vos podés opinar sobre cada
uno, porque el único que sabe si molesta es quien escribió la pantalla.

El caso típico: la persona está mirando el detalle de la compra 9912 y llega
«tu compra 9912 fue aprobada». Dibujarlo le tapa con una tarjeta lo mismo que
tiene delante de los ojos.

```dart
AkPush.alDecidirDibujo = (m) {
  if (_pantallaActual == '/compras/${m.data['ruta_id']}') {
    return DecisionDeDibujo.noMostrar;
  }
  return DecisionDeDibujo.mostrarSilencioso;
};
```

| `DecisionDeDibujo` | |
|---|---|
| `mostrar` | Como siempre: visible, con sonido y vibración |
| `mostrarSilencioso` | Visible, sin sonido ni vibración. Para cuando la persona está en la app y lo va a ver igual |
| `noMostrar` | No se dibuja nada |

### La medición ocurre igual

**La decisión afecta únicamente al dibujo.** El aviso se sigue contando como
entregado y `onMessage` se sigue emitiendo, incluso con `noMostrar`.

Es a propósito: el aviso **llegó al teléfono**. Que tu app haya decidido no
dibujarlo es una decisión tuya, posterior a la entrega. Si no lo contáramos, tu
tasa de entrega bajaría cada vez que tu app decide ser prolija — y quien mire el
tablero va a concluir que se están perdiendo envíos que en realidad llegaron
todos. Peor: el comercio que más cuida a su gente sería el que peor mide.

Y `onMessage` sigue emitiendo porque es por donde reaccionás al contenido —
refrescar un saldo, poner un punto rojo en el menú. Silenciar el aviso no es
ignorar lo que traía adentro.

### Tres detalles

- Se puede asignar **antes de `init()`**. No hay nada que lo pise.
- Tenés **150 ms** para contestar. Es corto a propósito: mientras contestás no
  hay nada en la pantalla. Lo único que tiene que hacer es leer algo que tu app
  ya tiene en memoria. Si no te alcanzan, es que estás yendo a la base o a la
  red, y eso acá no va.
- Si tardás de más, o si tu código falla, **se dibuja**. Un aviso de más es una
  molestia de un segundo; uno de menos puede ser el pago que venció.

---

## Llevar el toque a la pantalla correcta

Quién sabe a dónde tiene que ir un aviso es el que lo manda, el día que lo manda.
Por eso el destino viaja en el envío. Cambiar a dónde lleva una campaña deja de
exigir una versión nueva en las tiendas.

### Lo que tiene que mandar tu backend

Dentro del `data` del envío, dos claves y nada más:

```json
{
  "data": {
    "ruta": "/compras/:id",
    "ruta_id": "9912",
    "ruta_tab": "pagos"
  }
}
```

| clave | ¿obligatoria? | |
|---|---|---|
| `ruta` | **sí** | Un camino absoluto, empezando con `/`. Con marcadores `:nombre` o ya resuelto |
| `ruta_<nombre>` | no | El valor del marcador `:nombre`. Texto plano, uno por clave |

Con eso, la app recibe `destino == '/compras/9912'` y
`parametros == {'id': '9912', 'tab': 'pagos'}`.

Cuatro cosas más que conviene saber:

- Mandar la ruta ya resuelta —`"ruta": "/compras/9912"`— es igual de válido y no
  necesita ningún parámetro.
- La ruta puede traer su propia consulta: `"/compras/9912?tab=pagos"` funciona.
  Si el mismo nombre viene por los dos caminos, gana `ruta_<nombre>`.
- **El prefijo `ruta_` no es decorativo.** `data` ya tiene dueño: `pushLogId`,
  `code_event`, `type` y `channelId` los usamos nosotros. Un parámetro tuyo
  llamado `type` rompería la detección de señales sin que nadie se entere.
- Un aviso **sin** `ruta` es lo normal, no un error: la mayoría solo informa.

### Lo que escribís en la app

```dart
class _RaizState extends State<Raiz> {
  late final VoidCallback _cortar;

  @override
  void initState() {
    super.initState();
    _cortar = AkPush.alRutear((ruta) => _navegador.go(ruta.destino));
  }

  @override
  void dispose() {
    _cortar();
    super.dispose();
  }
}
```

Una línea cubre los dos casos, que son distintos y los dos existen:

- **El toque en frío**, con la app muerta. El sistema la arranca para entregarlo
  y el toque llega antes de que exista tu navegador. La ruta queda guardada y se
  entrega cuando aparecés.
- **El toque en caliente**, con la app abierta. Llega y se entrega.

La ruta se entrega **una sola vez**. Una intención que se puede leer dos veces se
navega dos veces, y la persona termina viendo cómo se le vuelve a abrir algo que
ya cerró.

⚠️ Llamar a la función que devuelve `alRutear()` en `dispose()` no es opcional.
Un consumidor muerto que siga suscrito se lleva la ruta que le tocaba al vivo.

Si preferís manejarlo a mano, `AkPush.consumirRuta()` la devuelve y la limpia, y
`AkPush.rutaPendiente` es un `ValueListenable` para mirar sin consumir —sirve
directo con `ValueListenableBuilder`—. También podés preguntarle a cualquier
mensaje: `m.tieneRuta` y `m.ruta`.

### Dos cosas que la ruta no hace

- **No sobrevive al cierre de la app.** Si la persona tocó el aviso y la app se
  cerró antes de llegar a la pantalla, eso se perdió. Entregarla tres días
  después, cuando abre la app para otra cosa, no se lee como una función: se lee
  como un fantasma y se reporta como un error.
- **No sobrevive a `logout()`.** Una ruta guardada apunta a los datos de quien
  estaba usando el teléfono.

---

## Cuando no llegan los push

Es la primera pregunta de toda integración, y tiene respuesta:

```dart
final d = await AkPush.diagnostico();
print(d);
```

```
AkPush — diagnóstico
Qué pasa: Todavía no se le preguntó a la persona si acepta notificaciones, y hasta que diga que sí el sistema no emite ningún token. Pedile el permiso desde una pantalla donde ya se entienda para qué sirve: el diálogo del sistema se muestra una sola vez.
Eslabón roto: permiso

  configuración ok    versión v3 · del servidor · comercio cmr_8812
  firebase      ok    tienda-nube-prod · 1:9912:android:aa11
  permiso       ROTO  sinPreguntar
  token         ROTO  no hay
  registro      ROTO  sin identify()
  último error        ninguno
```

Para que un push llegue tienen que estar bien cinco cosas, en este orden:
configuración, Firebase, permiso, dirección del teléfono y alta en el servidor.
**Desde afuera los cinco fallos se ven igual: no pasa nada.** El diagnóstico dice
cuál de los cinco está cortado y qué hacer, en castellano.

Ponelo detrás de un botón escondido de soporte y pedile la captura al que
reporta. El ticket llega con la respuesta adentro en vez de con una foto de una
pantalla vacía.

| | |
|---|---|
| `d.quePasa` | La frase: qué está roto y qué hacer |
| `d.eslabonRoto` | `configuracion`, `firebase`, `permiso`, `token`, `registro` o `ninguno` |
| `d.todoBien` | Si la cadena está entera |
| `d.toJson()` | Lo mismo, para mandar por telemetría y poder agrupar |

### Por qué es lo primero que hay que mirar

- **Se puede llamar aunque `init()` haya fallado**, que es justo cuando más
  sirve. No tira `notInitialized`.
- **Compara con qué cuenta de Google quedó conectada tu app de verdad** contra la
  que el servidor le asignó al comercio. Ese fallo es el más caro y el más mudo:
  la app arranca, pide su dirección y la consigue, pero es la dirección de otro
  proyecto y ningún envío del comercio la va a alcanzar jamás.
- **Saca a la luz el error que nos tragamos** para no romperte el arranque.
- **Avisa si estás trabajando con la configuración guardada** porque hoy no se
  pudo pedir la del servidor.
- **No toca nada.** No pide permiso, no registra, no envía. Un diagnóstico que
  arregla es un diagnóstico que miente — y pedir el permiso desde un botón de
  «diagnosticar» te quema el diálogo que estabas tratando de medir.

Del token muestra el principio y el fin, no el token entero: alcanza para
comparar dos teléfonos, que es lo único para lo que se mira, y no queda pegado
para siempre en un chat.

Si dice que la cadena está entera y aun así no llegan, el problema no está en el
teléfono: está en el envío. Revisá en el panel si salió y qué contestó el
proveedor.

---

## Errores

Todos son `AkPushError`, con un `code` para ramificar y `retryable` para saber si
esperar sirve.

| `code` | qué pasó | ¿reintentar? |
|---|---|---|
| `unauthorized` | la llave falta o es inválida | no |
| `appMismatch` | el identificador de tu app no es el que registramos | no |
| `firebaseInit` | tu app ya inicializó Firebase con otra cuenta — ver abajo | no |
| `permissionDenied` | la persona no dio permiso. **No es un fallo, es una respuesta** — el permiso se consulta con `estadoDelPermiso()`, no se atrapa como error | no |
| `notInitialized` | llamaste a `identify()` o `logout()` antes de que `init()` terminara | no |
| `unknown` | algo falló y no se pudo clasificar. El detalle está en `details`, y aparece en el diagnóstico como «último error» | no |
| `network` · `serviceUnavailable` | no hubo respuesta, o el servicio no está | **sí** |

### Sobre `firebaseInit`

Este paquete **es dueño de la app de Firebase por defecto**, porque el transporte
de notificaciones solo trabaja con esa. Si tu aplicación llama a
`Firebase.initializeApp()` por su cuenta con otra configuración, sacá esa llamada
y dejá que `AkPush.init()` la haga.

---

## Lo que hace solo, sin que le pidas nada

- **Guarda la última configuración.** Solo la primerísima instalación necesita
  señal; de ahí en adelante arranca aunque el teléfono esté sin conexión.
- **Se da cuenta si cambiamos tu cuenta de Google.** Un token de notificaciones
  solo vale dentro de la cuenta que lo emitió: si cambiara y el teléfono no se
  enterara, quedaría mudo para siempre y sin ningún error. El paquete lo detecta,
  descarta la dirección vieja y consigue una nueva.
- **Se vuelve a registrar cuando el sistema rota la dirección del teléfono**, que
  pasa solo.
- **Vuelve a dar de alta el teléfono en cuanto aparece el permiso.** Apenas lee
  que hay permiso —al pedirlo, o al releer el estado— consigue la dirección y
  registra. Es lo que hace que pedir el permiso tarde no cueste nada.
- **Dibuja el aviso cuando tu app está abierta**, que es lo que el transporte no
  hace, y crea los canales de Android.
- **No abre el mismo aviso dos veces.** Con la app cerrada, el sistema reporta el
  toque por dos caminos distintos.
- **Guarda la ruta del último toque** hasta que exista alguien capaz de navegar,
  y la tira al cerrar sesión.

---

## Estado

Versión `0.1.0`, en prueba de concepto. Android probado de punta a punta contra
un servicio real; iOS todavía no.

**Lo que hace hoy:** configuración servida por el servidor, permiso diferido con
pregunta blanda, el ciclo de sesión completo, el rastro del consentimiento, los
tres caminos de llegada, el control del dibujo, el ruteo del toque, el
diagnóstico, y la baja al cerrar sesión.

**Lo que todavía no:**

| | |
|---|---|
| **La entrega en segundo plano no se cuenta** | Los avisos que llegan con tu app cerrada se ven y se pueden tocar, pero su *entrega* no entra en las estadísticas. Sólo la apertura. Medirla exige credenciales propias dentro del aislado de segundo plano |
| **Preferencias por categoría** | Que la persona elija recibir unos avisos y otros no. Espera al servicio |
| **La bandeja** | Ver dentro de la app lo que llegó. Espera al servicio |
| **iOS** | Necesita Mac, teléfono físico y la clave de APNs del comercio |
| **Idempotencia** | El paquete de envío manda la clave; el servicio todavía no la hace cumplir |
