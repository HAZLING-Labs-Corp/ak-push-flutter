# Ejemplo de `ak_push`

Una aplicación en blanco que sólo instala el SDK. Sirve para ver el flujo
completo y para probar contra un servicio de verdad.

```bash
flutter run \
  --dart-define=AKPUSH_KEY=pk_live_…   \
  --dart-define=AKPUSH_COMERCIO=tu_comercio \
  --dart-define=AKPUSH_URL=http://10.0.2.2:3085/api/v1
```

`10.0.2.2` es cómo un emulador de Android alcanza el localhost de la máquina que
lo hospeda. Desde un teléfono real en la misma red, la IP de la máquina.

---

## El identificador del paquete

El servicio verifica que el paquete que pide la configuración esté registrado en
tu comercio: con otro devuelve un 409 explicando el desacuerdo. Así que el
ejemplo tiene que compilarse con **el tuyo**, y se pasa al compilar:

```bash
flutter run -Ppaquete=com.tuempresa.app \
  --dart-define=AKPUSH_KEY=… --dart-define=AKPUSH_COMERCIO=…
```

**No hay ningún archivo que editar.** Lo único que falta es registrar ese paquete
en tu comercio, desde la consola.

Sin `-Ppaquete` usa `com.juanpush.android1`, que es una app de prueba nuestra y
no va a servirte.

---

## Qué se ve

La aplicación arranca **sin pedir ningún permiso** —lo decide la política— y
muestra en qué estado está: si esa persona puede recibir avisos y por qué no, si
la hay.

Entrás eligiendo una de **cien personas de prueba** (`usuario1`…`usuario100`,
buscables por nombre, cédula o usuario). Ahí se dispara el ciclo de sesión: se da
de baja a la anterior si era otra, se verifica el permiso contra el sistema
operativo, y se registra.

Si la política dice pregunta blanda, aparece **el modal con los textos del
comercio**. Un «ahora no» no gasta el diálogo del sistema; un «sí» lo dispara.

El botón del ícono de la cabecera abre el **diagnóstico**: por qué no le llega, si
no le llega.

---

## Las cien personas

`lib/personas_de_prueba.dart`. No son una lista de nombres: traen la forma exacta
del modelo de identidad, para poder probar las dos cosas que hay que poder
probar.

```dart
PersonaDePrueba(
  userId: 'u_9000',
  usuario: 'usuario1',
  cedula: '12137717',                    // alias · se DIRECCIONA por acá
  correo: 'ana.rodriguez0@ejemplo.com',  // alias
  nombre: 'Ana Rodríguez',               // atributo · se FILTRA y se muestra
  sucursal: 'CCS-01', ciudad: 'Caracas', plan: 'Bronce',
)
```

Ocho ciudades, 24 sucursales y cuatro planes de 25 cada uno — repartidas así a
propósito: un juego de prueba donde todos comparten el mismo valor no prueba el
filtro, prueba que la consulta corre.

Con atajos para no recorrer la lista a mano:

```dart
porUsuario('usuario7')      laNumero(7)
porCedula('12137717')       // el caso que motivó todo el modelo de alias:
                            // el que envía conoce la cédula y no el userId
deLaSucursal('CCS-01')      delPlan('Bronce')
buscarPorNombre('Ana')
```

> 🔴 **Todas entran con `admin123`.** Igual para las cien, a propósito, para poder
> entrar con cualquiera sin ir a buscar la clave. **Eso no sale de un ambiente de
> prueba**: cien cuentas con la misma clave conocida es exactamente lo que no se
> hace donde haya datos de alguien.
