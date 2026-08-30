# ak_push

Recibir notificaciones push con una llave y una línea.

```yaml
dependencies:
  ak_push: ^0.1.0
```

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AkPush.init(apiKey: 'akp_...');   // la llave que te dimos
  runApp(const MiApp());
}
```

Cuando la persona inicia sesión:

```dart
await AkPush.identify(userId: 'u_123');
```

⚠️ `init()` es asíncrono. No ofrezcas el botón de inicio de sesión hasta que
resuelva, o `identify()` va a fallar con `notInitialized`.

Cuando cierra sesión:

```dart
await AkPush.logout();
```

Eso es todo. **No pegás ningún archivo de configuración en el proyecto.** La cuenta
de Google la sirve nuestro servidor en cada arranque.

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

---

## Errores

Todos son `AkPushError`, con un `code` para ramificar y `retryable` para saber si
esperar sirve.

| `code` | qué pasó | ¿reintentar? |
|---|---|---|
| `unauthorized` | la llave falta o es inválida | no |
| `appMismatch` | el identificador de tu app no es el que registramos | no |
| `firebaseInit` | tu app ya inicializó Firebase con otra cuenta — ver abajo | no |
| `permissionDenied` | la persona no dio permiso. **No es un fallo, es una respuesta** | no |
| `notInitialized` | llamaste a `identify()` o `logout()` antes de que `init()` terminara | no |
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
- **Dibuja el aviso cuando tu app está abierta**, que es lo que el transporte no
  hace, y crea los canales de Android.
- **No abre el mismo aviso dos veces.** Con la app cerrada, el sistema reporta el
  toque por dos caminos distintos.

---

## Estado

Versión `0.1.0`, en prueba de concepto. Android probado; iOS necesita todavía la
verificación en un teléfono real.

**Un límite conocido:** los avisos que llegan con la app en **segundo plano** se
ven y se pueden tocar, pero su *entrega* no se cuenta en las estadísticas. Solo se
cuenta la apertura. Medirlo exigiría credenciales propias dentro del aislado de
segundo plano; queda pendiente.
