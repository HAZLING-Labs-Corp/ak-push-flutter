/// EL CATÁLOGO DE PERMISOS — la única fuente de verdad de lo que este SDK puede
/// llegar a aportarle al manifiesto de una aplicación anfitriona.
///
/// 🔴 ESTO NO ES UNA LISTA BLANCA. Es un registro con justificación.
///
/// La diferencia importa y es la razón de que este archivo exista. Una lista blanca
/// —«estos seis permisos y ninguno más»— se rompe el día que hace falta el séptimo, y
/// un muro que se desactiva para avanzar no es un muro. Acá un permiso no se
/// «permite»: se DECLARA, y la declaración obliga a escribir para qué sirve, quién lo
/// aporta, cuánto asusta, qué se guarda y con qué base legal.
///
/// Pedir el permiso número veinte no rompe nada. Obliga a escribir su ficha. Que es
/// exactamente la fricción que queremos que exista.
///
/// **Y una ficha alimenta cuatro cosas a la vez**, que antes se escribían por separado
/// y se contradecían entre sí:
///
///   1. la comprobación que falla si aparece un permiso sin declarar (`bin/muro.dart`)
///   2. el manual que lee el integrador
///   3. la declaración de Data Safety de Google Play
///   4. el texto que ve la persona cuando se le pide
///
/// 🔴 EL MOTIVO REAL DE TODO ESTO, medido el 2026-08-31 sobre CredoLab en una app de
/// producción: sus paquetes declaran `READ_CONTACTS`, `READ_CALENDAR`, `GET_ACCOUNTS`
/// y `READ_PHONE_STATE` en sus propios manifiestos, y el fusionador se los inyecta a
/// TODA aplicación que los instale — la use o no. La ficha de Play de esa app asusta
/// por datos que nunca va a obtener. Este archivo existe para que eso no nos pase, y
/// `bin/muro.dart` existe para que no dependa de que alguien se acuerde.
library;

/// En qué sistema aplica un permiso. La distinción no es cosmética: hay permisos que
/// en iOS ni siquiera existen como concepto, y decir «ambas» cuando no es cierto hace
/// que el manual mienta.
enum Plataforma { android, ios, ambas }

/// Cuánta fricción le pone a la gente del comercio, no cuánto cuesta programarlo.
///
/// Es el mismo nivel que usa el catálogo de módulos del servicio, a propósito: si los
/// dos lados numeraran distinto, nadie podría cruzar una cosa con la otra.
enum Nivel {
  /// No se le muestra ningún diálogo a nadie. Se tiene en el 100% de las instalaciones.
  ninguno,

  /// Un diálogo común, que la mayoría acepta. Notificaciones, ubicación aproximada.
  comun,

  /// Aparece destacado en la ficha de la tienda y baja las instalaciones.
  asusta,

  /// Google o Apple lo revisan a mano y hay que justificarlo con un formulario.
  revisionManual,
}

/// Por qué es lícito recolectar este dato. No es un adorno legal: decide qué pasa
/// cuando alguien revoca.
///
/// Con `consentimiento`, revocar obliga a dejar de recolectar Y a borrar lo recolectado.
/// Con `contrato`, el dato hace falta para prestar el servicio y no se puede revocar sin
/// dejar de usar la aplicación. Confundirlos es lo que hace que una revocación no
/// signifique nada.
enum BaseLegal {
  /// La persona dijo que sí, y puede decir que no después.
  consentimiento,

  /// Sin este dato no se puede prestar el servicio que la persona pidió.
  contrato,
}

/// Cuánto tiempo se guarda lo que se recolecta con este permiso.
///
/// 🔴 VA EN LA FICHA DEL PERMISO Y NO EN UNA POLÍTICA APARTE, porque una política de
/// retención que vive lejos del dato se desactualiza y nadie se entera. Acá, agregar un
/// permiso obliga a contestar cuánto se guarda lo que trae.
class Retencion {
  /// En castellano llano, para el manual y para la persona.
  final String enPalabras;

  /// Días, cuando hay un número. `null` = mientras exista la instalación.
  final int? dias;

  const Retencion(this.enPalabras, {this.dias});

  /// Mientras el aparato siga dado de alta. Al borrarse la instalación, se va con ella.
  static const mientrasExista = Retencion('mientras el aparato siga dado de alta');
}

/// La ficha de un permiso. Todos los campos son obligatorios menos `razonApple`, que
/// sólo aplica a las APIs que Apple exige justificar.
class PermisoDeclarado {
  /// El nombre exacto como aparece en el manifiesto. Es la clave contra la que compara
  /// `bin/muro.dart`, así que un error de tipeo acá hace fallar la comprobación — que
  /// es preferible a que la deje pasar.
  final String nombre;

  final Plataforma plataforma;

  /// 🔴 QUÉ MÓDULO LO NECESITA. Sin módulo no entra, y esa regla es el corazón del
  /// muro: un permiso que no le sirve a ningún módulo es un permiso que alguien
  /// arrastró sin querer, que es exactamente el caso de CredoLab.
  final String modulo;

  /// Para qué sirve, en una frase y en castellano. Este texto se muestra tal cual en el
  /// manual del integrador y alimenta el modal — así que se escribe pensando en quien
  /// lo va a leer en el teléfono, no en quien programa.
  final String paraQue;

  final Nivel nivel;

  /// Quién lo mete en el manifiesto: una dependencia nuestra, o la propia aplicación.
  ///
  /// 🔴 La distinción decide de quién es la responsabilidad. Los que aporta la
  /// aplicación son decisión del comercio y nosotros no los podemos quitar; los que
  /// aporta una dependencia son nuestros, y si aparece uno que no está acá es un
  /// problema nuestro que hay que resolver antes de publicar.
  final String loAporta;

  /// La casilla exacta del formulario de Data Safety de Google Play. Se escribe con las
  /// palabras del formulario, no con las nuestras: quien lo llena tiene que poder
  /// buscarla literalmente.
  final String dataSafety;

  /// La razón requerida por Apple, cuando la API está en su lista. `null` si no aplica.
  final String? razonApple;

  final Retencion retencion;
  final BaseLegal base;

  const PermisoDeclarado({
    required this.nombre,
    required this.plataforma,
    required this.modulo,
    required this.paraQue,
    required this.nivel,
    required this.loAporta,
    required this.dataSafety,
    required this.retencion,
    required this.base,
    this.razonApple,
  });

  /// ¿Lo aporta el paquete, o lo declara la aplicación anfitriona?
  ///
  /// Lo usa el muro para separar «esto es responsabilidad nuestra» de «esto lo decidió
  /// el comercio», que es la única forma de que el informe sirva para algo.
  bool get esNuestro => loAporta != 'la aplicación anfitriona';
}

/// ─────────────────────────────────────────────────────────────────────────────────
/// EL CATÁLOGO
/// ─────────────────────────────────────────────────────────────────────────────────
///
/// Medido el 2026-08-31 sobre la aplicación de demostración compilada en release: una
/// app que instala este SDK termina con seis permisos, y **sólo dos los declaró ella**.
/// Los otros cuatro los aportan las dependencias, y son los cuatro primeros de acá.
///
/// Ninguno de los cuatro es peligroso ni aparece destacado en la ficha de Play. Eso no
/// es casualidad: es la razón por la que se eligieron esas dependencias y no otras.
const List<PermisoDeclarado> catalogoDePermisos = [
  // ── Lo que aportan las dependencias ──────────────────────────────────────────────
  PermisoDeclarado(
    nombre: 'android.permission.INTERNET',
    plataforma: Plataforma.android,
    modulo: 'avisos',
    paraQue: 'Hablar con el servicio. Sin esto no llega ningún aviso.',
    nivel: Nivel.ninguno,
    loAporta: 'firebase_messaging',
    dataSafety: 'no se declara: no es acceso a datos del usuario',
    retencion: Retencion.mientrasExista,
    base: BaseLegal.contrato,
  ),
  PermisoDeclarado(
    nombre: 'android.permission.ACCESS_NETWORK_STATE',
    plataforma: Plataforma.android,
    modulo: 'avisos',
    paraQue:
        'Saber si hay conexión, para no reintentar un envío contra un teléfono sin red.',
    nivel: Nivel.ninguno,
    loAporta: 'firebase_messaging',
    dataSafety: 'no se declara: no identifica a nadie',
    retencion: Retencion.mientrasExista,
    base: BaseLegal.contrato,
  ),
  PermisoDeclarado(
    nombre: 'android.permission.WAKE_LOCK',
    plataforma: Plataforma.android,
    modulo: 'avisos',
    paraQue:
        'Despertar el teléfono lo justo para mostrar un aviso que llegó con la pantalla apagada.',
    nivel: Nivel.ninguno,
    loAporta: 'firebase_messaging',
    dataSafety: 'no se declara',
    retencion: Retencion.mientrasExista,
    base: BaseLegal.contrato,
  ),
  PermisoDeclarado(
    nombre: 'android.permission.VIBRATE',
    plataforma: Plataforma.android,
    modulo: 'avisos',
    paraQue: 'Vibrar al mostrar un aviso, si el canal lo tiene configurado.',
    nivel: Nivel.ninguno,
    loAporta: 'flutter_local_notifications',
    dataSafety: 'no se declara',
    retencion: Retencion.mientrasExista,
    base: BaseLegal.contrato,
  ),

  PermisoDeclarado(
    nombre: 'com.google.android.c2dm.permission.RECEIVE',
    plataforma: Plataforma.android,
    modulo: 'avisos',
    paraQue: 'Recibir el aviso que manda Google. Es el canal por donde llega el push.',
    nivel: Nivel.ninguno,
    loAporta: 'firebase_messaging',
    // No es un permiso del sistema: lo define Google y sólo sirve para que otra
    // aplicación no pueda hacerse pasar por el repartidor de avisos. No se le muestra
    // a nadie ni aparece en la ficha de Play.
    dataSafety: 'no se declara: no es acceso a datos del usuario',
    retencion: Retencion.mientrasExista,
    base: BaseLegal.contrato,
  ),

  // ── Lo que declara la aplicación anfitriona ──────────────────────────────────────
  //
  // 🔴 Estos DOS no los aporta el paquete, y es deliberado. Un permiso declarado por
  // una dependencia se le aparece en la ficha de Play a toda aplicación que la instale,
  // la use o no. Declararlos del lado de la aplicación deja la decisión donde
  // corresponde: en el producto que la va a publicar.
  PermisoDeclarado(
    nombre: 'android.permission.POST_NOTIFICATIONS',
    plataforma: Plataforma.android,
    modulo: 'avisos',
    paraQue: 'Mostrarte avisos. Android 13 en adelante lo pide explícitamente.',
    nivel: Nivel.comun,
    loAporta: 'la aplicación anfitriona',
    dataSafety: 'no se declara como dato; el token sí, como «ID de dispositivo»',
    retencion: Retencion('mientras la dirección del teléfono siga sirviendo'),
    base: BaseLegal.consentimiento,
  ),
  PermisoDeclarado(
    nombre: 'android.permission.ACCESS_COARSE_LOCATION',
    plataforma: Plataforma.ambas,
    modulo: 'ubicacion',
    paraQue: 'Saber tu zona —no tu dirección— mientras usás la aplicación.',
    nivel: Nivel.comun,
    loAporta: 'la aplicación anfitriona',
    dataSafety: 'Ubicación → Ubicación aproximada',
    razonApple: 'NSLocationWhenInUseUsageDescription',
    // Cinco lecturas por aparato y 90 días, que es lo que hace hoy el servicio.
    retencion: Retencion('las últimas 5 lecturas por aparato, y 90 días', dias: 90),
    base: BaseLegal.consentimiento,
  ),
];

/// Los nombres, para comparar rápido. Lo usa `bin/muro.dart`.
Set<String> get permisosDeclarados =>
    catalogoDePermisos.map((p) => p.nombre).toSet();

/// Busca la ficha de un permiso. `null` si no está declarado — y eso es justamente lo
/// que hace fallar al muro.
PermisoDeclarado? fichaDe(String nombre) {
  for (final p in catalogoDePermisos) {
    if (p.nombre == nombre) return p;
  }
  return null;
}

/// 🔴 LOS QUE NO SE PIDEN NUNCA, y por qué.
///
/// Esta lista no es defensiva ni es un gesto: es la que hace que el muro pueda dar un
/// mensaje útil en vez de «permiso desconocido». Si alguien agrega una dependencia que
/// arrastra uno de estos, el error dice exactamente qué política se estaría violando y
/// a quién le sacan la app de la tienda.
///
/// Todos salen de la política de Servicios Financieros de Google Play para préstamos
/// personales y adelanto de sueldo, vigente desde el 31 de mayo de 2023, que los
/// prohíbe expresamente.
const Map<String, String> permisosProhibidos = {
  'android.permission.READ_CONTACTS':
      'Prohibido por la política de préstamos personales de Google Play. Es además la '
          'señal que más reguladores atrajo: India lo prohibió por ley en 2022.',
  'android.permission.READ_SMS':
      'Restringido desde 2019. Y aun con la excepción bancaria, la política antispyware '
          'prohíbe sacar del teléfono el historial de mensajes no financieros.',
  'android.permission.RECEIVE_SMS':
      'Mismo caso que READ_SMS: restringido desde 2019 y reservado a la aplicación de '
          'mensajes por omisión. Si aparece, lo arrastró una dependencia — buscá cuál '
          'y sacala, porque le va a costar la publicación a quien instale el paquete.',
  'android.permission.READ_CALL_LOG':
      'Restringido a la aplicación de teléfono por omisión. En iOS no existe la API.',
  'android.permission.READ_EXTERNAL_STORAGE':
      'En la lista explícita de permisos vetados de la política de préstamos personales.',
  'android.permission.READ_MEDIA_IMAGES':
      'En la lista explícita de permisos vetados de la política de préstamos personales.',
  'android.permission.READ_MEDIA_VIDEO':
      'En la lista explícita de permisos vetados de la política de préstamos personales.',
  'android.permission.READ_PHONE_NUMBERS':
      'En la lista explícita de permisos vetados de la política de préstamos personales.',
  'android.permission.ACCESS_FINE_LOCATION':
      'En la lista explícita de permisos vetados. COARSE alcanza para lo que hacemos, y '
          'además lo acepta bastante más gente.',
  'android.permission.QUERY_ALL_PACKAGES':
      'Google sólo lo admite si inventariar las aplicaciones es el propósito CENTRAL de '
          'la app —antivirus, lanzador, gestor de archivos—. Un SDK de datos no califica.',
  'android.permission.MANAGE_EXTERNAL_STORAGE':
      'Acceso a todo el almacenamiento. Es el que inyectaba permission_handler y por el '
          'que se lo sacó del paquete el 2026-08-30.',
  'android.permission.ACCESS_BACKGROUND_LOCATION':
      'Exige una pantalla de aviso aparte, un formulario y un video para Google. El '
          'módulo de rastreo está declarado en el catálogo pero NO construido.',
  'android.permission.RECORD_AUDIO':
      'Ningún módulo del SDK lo necesita, así que si aparece lo trajo otra cosa. El '
          'micrófono en una aplicación financiera es de los permisos que más rechazo '
          'generan en la revisión y en la ficha de la tienda.',
  'android.permission.CAMERA':
      'Ningún módulo del SDK lo necesita. Si la aplicación lo usa para tomar una selfie '
          'de verificación, lo declara ella y está bien — pero entonces no tiene que '
          'llegar por una dependencia nuestra.',
  'android.permission.READ_CALENDAR':
      'No hay ningún módulo que lo necesite. CredoLab lo usa; nosotros decidimos que no.',
  'android.permission.GET_ACCOUNTS':
      'Muy restringido desde Android 8 y prácticamente inútil hoy. CredoLab lo declara y '
          'lo que obtiene es la cantidad de cuentas y nada más.',
  'android.permission.PACKAGE_USAGE_STATS':
      'Exige que la persona lo active a mano en Ajustes. Fricción altísima para lo que da.',
};
