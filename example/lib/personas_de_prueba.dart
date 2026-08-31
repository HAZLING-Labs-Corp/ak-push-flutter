/// Cien personas de prueba, con la forma exacta del modelo de identidad.
///
/// No es una lista de nombres: cada una trae lo que el SDK necesita para
/// demostrar las tres cosas que hay que poder probar sin un comercio real.
///
///   **alias** — cédula y correo. Son por los que se DIRECCIONA: únicos dentro
///   del comercio, y se puede enviar a cualquiera de los dos. Es lo que permite
///   probar «mandale a la cédula 12137717» sin saber su `userId`.
///
///   **atributos** — nombre, sucursal, ciudad y plan. Son para FILTRAR y
///   MOSTRAR, no para direccionar. Es lo que permite probar el envío segmentado
///   —«a todos los de CCS-01», «a los del plan Bronce»— y la búsqueda en la
///   consola.
///
/// Los datos están repartidos a propósito: ocho ciudades, tres sucursales en
/// cada una y cuatro planes, de modo que cualquier filtro devuelva un grupo de
/// tamaño razonable y no uno ni cien. Un juego de prueba donde todos comparten
/// el mismo valor no prueba el filtro: prueba que la consulta corre.
///
/// **Todas entran con la misma clave: `admin123`**, y el usuario es `usuario1`
/// hasta `usuario100`. Es un juego de prueba: la clave es igual para las cien a
/// propósito, para poder entrar con cualquiera sin ir a buscarla.
///
/// 🔴 Y por eso mismo: esto NO se usa fuera de un ambiente de prueba. Cien
/// cuentas con la misma clave conocida es exactamente lo que no se hace en
/// ningún lado donde haya datos de alguien.
///
/// Las cédulas y los correos son inventados y no corresponden a nadie.
///
/// ## Los cuatro casos del modelo de identidad
///
/// Las cien de abajo son todas personas naturales con cédula — el caso de
/// siempre. Al final de este archivo hay CUATRO más, agregadas con el
/// rediseño de colecciones, que prueban lo que las cien no pueden: DOS
/// **empresas** (`TipoDeSujeto.juridica`, documento con `ClaseDeDocumento.rif`)
/// y DOS **empleados de un proveedor** (naturales, pero con [Organizacion] —
/// el sujeto PERTENECE a la organización, no se reemplaza por ella). Ver
/// [casosDeIdentidadDePrueba].
library;

import 'package:hz_collection_sdk/hz_collection_sdk.dart';

/// Una persona del juego de prueba.
class PersonaDePrueba {
  const PersonaDePrueba({
    required this.userId,
    required this.usuario,
    required this.cedula,
    required this.correo,
    required this.nombre,
    required this.sucursal,
    required this.ciudad,
    required this.plan,
    this.tipo = TipoDeSujeto.natural,
    this.claseDeDocumento = ClaseDeDocumento.cedula,
    this.organizacion,
  });

  /// La clave con la que el comercio la identifica. Opaca para el SDK.
  ///
  /// En estas personas de prueba se compone a propósito —`usuario1-12137717`— en vez de ser
  /// un `u_9000` cualquiera: en la consola del proveedor se ve el identificador, y uno opaco
  /// obliga a ir a buscar de quién es cada vez. En un comercio de verdad será lo que él use.
  final String userId;

  /// Con qué entra: `usuario1` … `usuario100`. La contraseña es [claveDePrueba]
  /// para todas.
  final String usuario;

  // ── alias · se direcciona por acá ──────────────────────────────────────
  //
  // 🔴 El nombre del campo quedó de cuando sólo existían personas naturales.
  // Para los cuatro casos de [casosDeIdentidadDePrueba] guarda el número de
  // documento que corresponda —un RIF para las empresas—, y [claseDeDocumento]
  // dice cuál es. No se renombró el campo para no tocar las cien de abajo.
  final String cedula;
  final String correo;

  // ── atributos · se filtra y se muestra por acá ─────────────────────────
  final String nombre;
  final String sucursal;
  final String ciudad;
  final String plan;

  /// Si es una persona natural o una empresa. Por omisión, natural: es lo que
  /// son las cien de abajo.
  final TipoDeSujeto tipo;

  /// Con qué clase de documento se identifica [cedula]. Por omisión, cédula.
  final ClaseDeDocumento claseDeDocumento;

  /// La organización a la que pertenece, si tiene una. `null` en las cien:
  /// no todo el mundo trabaja para un proveedor del comercio.
  final Organizacion? organizacion;

  /// El documento tal como lo espera `AkPush.alIniciarSesion`. Se arma desde
  /// [cedula] y [claseDeDocumento]: son las dos empresas las que cambian la
  /// clase, no el campo — así el resto del demo no se entera de la diferencia.
  Documento get documento => Documento(clase: claseDeDocumento, numero: cedula);

  /// Lo que el backend del comercio le mandaría al servicio para darla de alta.
  Map<String, dynamic> get comoAlta => {
        'userId': userId,
        'alias': {'cedula': cedula, 'correo': correo},
        'atributos': {
          'nombre': nombre,
          'sucursal': sucursal,
          'ciudad': ciudad,
          'plan': plan,
        },
      };

  @override
  String toString() => '$usuario · $nombre · $cedula · $sucursal · $plan';
}

/// Las cien.
/// La contraseña de las cien. Igual para todas, a propósito y sólo para probar.
const claveDePrueba = 'admin123';

const cienPersonas = <PersonaDePrueba>[
  PersonaDePrueba(
    userId: 'usuario1-12137717',
    usuario: 'usuario1',
    cedula: '12137717',
    correo: 'ana.rodriguez0@ejemplo.com',
    nombre: 'Ana Rodríguez',
    sucursal: 'CCS-01',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario2-12276345',
    usuario: 'usuario2',
    cedula: '12276345',
    correo: 'miguel.rivas1@ejemplo.com',
    nombre: 'Miguel Rivas',
    sucursal: 'MCB-02',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario3-12415884',
    usuario: 'usuario3',
    cedula: '12415884',
    correo: 'marisol.colmenares2@ejemplo.com',
    nombre: 'Marisol Colmenares',
    sucursal: 'VAL-03',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario4-12556334',
    usuario: 'usuario4',
    cedula: '12556334',
    correo: 'douglas.hernandez3@ejemplo.com',
    nombre: 'Douglas Hernández',
    sucursal: 'BQT-01',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario5-12697695',
    usuario: 'usuario5',
    cedula: '12697695',
    correo: 'yusmary.guerra4@ejemplo.com',
    nombre: 'Yusmary Guerra',
    sucursal: 'CBL-02',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario6-12839967',
    usuario: 'usuario6',
    cedula: '12839967',
    correo: 'nestor.quintero5@ejemplo.com',
    nombre: 'Néstor Quintero',
    sucursal: 'MCY-03',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario7-12983150',
    usuario: 'usuario7',
    cedula: '12983150',
    correo: 'aixa.lopez6@ejemplo.com',
    nombre: 'Aixa López',
    sucursal: 'MTR-01',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario8-13127244',
    usuario: 'usuario8',
    cedula: '13127244',
    correo: 'simon.rojas7@ejemplo.com',
    nombre: 'Simón Rojas',
    sucursal: 'SCR-02',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario9-13272249',
    usuario: 'usuario9',
    cedula: '13272249',
    correo: 'rosa.suarez8@ejemplo.com',
    nombre: 'Rosa Suárez',
    sucursal: 'CCS-03',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario10-13418165',
    usuario: 'usuario10',
    cedula: '13418165',
    correo: 'jesús.torres9@ejemplo.com',
    nombre: 'Jesús Torres',
    sucursal: 'MCB-01',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario11-13564992',
    usuario: 'usuario11',
    cedula: '13564992',
    correo: 'yajaira.medina10@ejemplo.com',
    nombre: 'Yajaira Medina',
    sucursal: 'VAL-02',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario12-13712730',
    usuario: 'usuario12',
    cedula: '13712730',
    correo: 'alexander.gonzalez11@ejemplo.com',
    nombre: 'Alexander González',
    sucursal: 'BQT-03',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario13-13861379',
    usuario: 'usuario13',
    cedula: '13861379',
    correo: 'katiuska.blanco12@ejemplo.com',
    nombre: 'Katiuska Blanco',
    sucursal: 'CBL-01',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario14-14010939',
    usuario: 'usuario14',
    cedula: '14010939',
    correo: 'jhonny.bastidas13@ejemplo.com',
    nombre: 'Jhonny Bastidas',
    sucursal: 'MCY-02',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario15-14161410',
    usuario: 'usuario15',
    cedula: '14161410',
    correo: 'yaritza.garcia14@ejemplo.com',
    nombre: 'Yaritza García',
    sucursal: 'MTR-03',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario16-14312792',
    usuario: 'usuario16',
    cedula: '14312792',
    correo: 'pedro.mendoza15@ejemplo.com',
    nombre: 'Pedro Mendoza',
    sucursal: 'SCR-01',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario17-14465085',
    usuario: 'usuario17',
    cedula: '14465085',
    correo: 'gladys.pacheco16@ejemplo.com',
    nombre: 'Gladys Pacheco',
    sucursal: 'CCS-02',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario18-14618289',
    usuario: 'usuario18',
    cedula: '14618289',
    correo: 'argenis.sanchez17@ejemplo.com',
    nombre: 'Argenis Sánchez',
    sucursal: 'MCB-03',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario19-14772404',
    usuario: 'usuario19',
    cedula: '14772404',
    correo: 'nairobi.castillo18@ejemplo.com',
    nombre: 'Nairobi Castillo',
    sucursal: 'VAL-01',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario20-14927430',
    usuario: 'usuario20',
    cedula: '14927430',
    correo: 'gustavo.villalobos19@ejemplo.com',
    nombre: 'Gustavo Villalobos',
    sucursal: 'BQT-02',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario21-15083367',
    usuario: 'usuario21',
    cedula: '15083367',
    correo: 'coromoto.flores20@ejemplo.com',
    nombre: 'Coromoto Flores',
    sucursal: 'CBL-03',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario22-15240215',
    usuario: 'usuario22',
    cedula: '15240215',
    correo: 'osmel.salazar21@ejemplo.com',
    nombre: 'Osmel Salazar',
    sucursal: 'MCY-01',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario23-15397974',
    usuario: 'usuario23',
    cedula: '15397974',
    correo: 'carmen.perez22@ejemplo.com',
    nombre: 'Carmen Pérez',
    sucursal: 'MTR-02',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario24-15556644',
    usuario: 'usuario24',
    cedula: '15556644',
    correo: 'rafael.moreno23@ejemplo.com',
    nombre: 'Rafael Moreno',
    sucursal: 'SCR-03',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario25-15716225',
    usuario: 'usuario25',
    cedula: '15716225',
    correo: 'nelida.marcano24@ejemplo.com',
    nombre: 'Nélida Marcano',
    sucursal: 'CCS-01',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario26-15876717',
    usuario: 'usuario26',
    cedula: '15876717',
    correo: 'orlando.martinez25@ejemplo.com',
    nombre: 'Orlando Martínez',
    sucursal: 'MCB-02',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario27-16038120',
    usuario: 'usuario27',
    cedula: '16038120',
    correo: 'solange.silva26@ejemplo.com',
    nombre: 'Solange Silva',
    sucursal: 'VAL-03',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario28-16200434',
    usuario: 'usuario28',
    cedula: '16200434',
    correo: 'edgar.zambrano27@ejemplo.com',
    nombre: 'Edgar Zambrano',
    sucursal: 'BQT-01',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario29-16363659',
    usuario: 'usuario29',
    cedula: '16363659',
    correo: 'nakary.ramirez28@ejemplo.com',
    nombre: 'Nakary Ramírez',
    sucursal: 'CBL-02',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario30-16527795',
    usuario: 'usuario30',
    cedula: '16527795',
    correo: 'jose.vargas29@ejemplo.com',
    nombre: 'José Vargas',
    sucursal: 'MCY-03',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario31-16692842',
    usuario: 'usuario31',
    cedula: '16692842',
    correo: 'yolanda.rodriguez30@ejemplo.com',
    nombre: 'Yolanda Rodríguez',
    sucursal: 'MTR-01',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario32-16858800',
    usuario: 'usuario32',
    cedula: '16858800',
    correo: 'franklin.rivas31@ejemplo.com',
    nombre: 'Franklin Rivas',
    sucursal: 'SCR-02',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario33-17025669',
    usuario: 'usuario33',
    cedula: '17025669',
    correo: 'belkis.colmenares32@ejemplo.com',
    nombre: 'Belkis Colmenares',
    sucursal: 'CCS-03',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario34-17193449',
    usuario: 'usuario34',
    cedula: '17193449',
    correo: 'freddy.hernandez33@ejemplo.com',
    nombre: 'Freddy Hernández',
    sucursal: 'MCB-01',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario35-17362140',
    usuario: 'usuario35',
    cedula: '17362140',
    correo: 'morella.guerra34@ejemplo.com',
    nombre: 'Morella Guerra',
    sucursal: 'VAL-02',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario36-17531742',
    usuario: 'usuario36',
    cedula: '17531742',
    correo: 'eleazar.quintero35@ejemplo.com',
    nombre: 'Eleazar Quintero',
    sucursal: 'BQT-03',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario37-17702255',
    usuario: 'usuario37',
    cedula: '17702255',
    correo: 'maria.lopez36@ejemplo.com',
    nombre: 'María López',
    sucursal: 'CBL-01',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario38-17873679',
    usuario: 'usuario38',
    cedula: '17873679',
    correo: 'carlos.rojas37@ejemplo.com',
    nombre: 'Carlos Rojas',
    sucursal: 'MCY-02',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario39-18046014',
    usuario: 'usuario39',
    cedula: '18046014',
    correo: 'zulay.suarez38@ejemplo.com',
    nombre: 'Zulay Suárez',
    sucursal: 'MTR-03',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario40-18219260',
    usuario: 'usuario40',
    cedula: '18219260',
    correo: 'wilmer.torres39@ejemplo.com',
    nombre: 'Wilmer Torres',
    sucursal: 'SCR-01',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario41-18393417',
    usuario: 'usuario41',
    cedula: '18393417',
    correo: 'deisy.medina40@ejemplo.com',
    nombre: 'Deisy Medina',
    sucursal: 'CCS-02',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario42-18568485',
    usuario: 'usuario42',
    cedula: '18568485',
    correo: 'anibal.gonzalez41@ejemplo.com',
    nombre: 'Aníbal González',
    sucursal: 'MCB-03',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario43-18744464',
    usuario: 'usuario43',
    cedula: '18744464',
    correo: 'rosalba.blanco42@ejemplo.com',
    nombre: 'Rosalba Blanco',
    sucursal: 'VAL-01',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario44-18921354',
    usuario: 'usuario44',
    cedula: '18921354',
    correo: 'luis.bastidas43@ejemplo.com',
    nombre: 'Luis Bastidas',
    sucursal: 'BQT-02',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario45-19099155',
    usuario: 'usuario45',
    cedula: '19099155',
    correo: 'elena.garcia44@ejemplo.com',
    nombre: 'Elena García',
    sucursal: 'CBL-03',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario46-19277867',
    usuario: 'usuario46',
    cedula: '19277867',
    correo: 'antonio.mendoza45@ejemplo.com',
    nombre: 'Antonio Mendoza',
    sucursal: 'MCY-01',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario47-19457490',
    usuario: 'usuario47',
    cedula: '19457490',
    correo: 'milagros.pacheco46@ejemplo.com',
    nombre: 'Milagros Pacheco',
    sucursal: 'MTR-02',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario48-19638024',
    usuario: 'usuario48',
    cedula: '19638024',
    correo: 'ramon.sanchez47@ejemplo.com',
    nombre: 'Ramón Sánchez',
    sucursal: 'SCR-03',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario49-19819469',
    usuario: 'usuario49',
    cedula: '19819469',
    correo: 'yenifer.castillo48@ejemplo.com',
    nombre: 'Yenifer Castillo',
    sucursal: 'CCS-01',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario50-20001825',
    usuario: 'usuario50',
    cedula: '20001825',
    correo: 'wladimir.villalobos49@ejemplo.com',
    nombre: 'Wladimir Villalobos',
    sucursal: 'MCB-02',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario51-20185092',
    usuario: 'usuario51',
    cedula: '20185092',
    correo: 'ana.flores50@ejemplo.com',
    nombre: 'Ana Flores',
    sucursal: 'VAL-03',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario52-20369270',
    usuario: 'usuario52',
    cedula: '20369270',
    correo: 'miguel.salazar51@ejemplo.com',
    nombre: 'Miguel Salazar',
    sucursal: 'BQT-01',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario53-20554359',
    usuario: 'usuario53',
    cedula: '20554359',
    correo: 'marisol.perez52@ejemplo.com',
    nombre: 'Marisol Pérez',
    sucursal: 'CBL-02',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario54-20740359',
    usuario: 'usuario54',
    cedula: '20740359',
    correo: 'douglas.moreno53@ejemplo.com',
    nombre: 'Douglas Moreno',
    sucursal: 'MCY-03',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario55-20927270',
    usuario: 'usuario55',
    cedula: '20927270',
    correo: 'yusmary.marcano54@ejemplo.com',
    nombre: 'Yusmary Marcano',
    sucursal: 'MTR-01',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario56-21115092',
    usuario: 'usuario56',
    cedula: '21115092',
    correo: 'nestor.martinez55@ejemplo.com',
    nombre: 'Néstor Martínez',
    sucursal: 'SCR-02',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario57-21303825',
    usuario: 'usuario57',
    cedula: '21303825',
    correo: 'aixa.silva56@ejemplo.com',
    nombre: 'Aixa Silva',
    sucursal: 'CCS-03',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario58-21493469',
    usuario: 'usuario58',
    cedula: '21493469',
    correo: 'simon.zambrano57@ejemplo.com',
    nombre: 'Simón Zambrano',
    sucursal: 'MCB-01',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario59-21684024',
    usuario: 'usuario59',
    cedula: '21684024',
    correo: 'rosa.ramirez58@ejemplo.com',
    nombre: 'Rosa Ramírez',
    sucursal: 'VAL-02',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario60-21875490',
    usuario: 'usuario60',
    cedula: '21875490',
    correo: 'jesús.vargas59@ejemplo.com',
    nombre: 'Jesús Vargas',
    sucursal: 'BQT-03',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario61-22067867',
    usuario: 'usuario61',
    cedula: '22067867',
    correo: 'yajaira.rodriguez60@ejemplo.com',
    nombre: 'Yajaira Rodríguez',
    sucursal: 'CBL-01',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario62-22261155',
    usuario: 'usuario62',
    cedula: '22261155',
    correo: 'alexander.rivas61@ejemplo.com',
    nombre: 'Alexander Rivas',
    sucursal: 'MCY-02',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario63-22455354',
    usuario: 'usuario63',
    cedula: '22455354',
    correo: 'katiuska.colmenares62@ejemplo.com',
    nombre: 'Katiuska Colmenares',
    sucursal: 'MTR-03',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario64-22650464',
    usuario: 'usuario64',
    cedula: '22650464',
    correo: 'jhonny.hernandez63@ejemplo.com',
    nombre: 'Jhonny Hernández',
    sucursal: 'SCR-01',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario65-22846485',
    usuario: 'usuario65',
    cedula: '22846485',
    correo: 'yaritza.guerra64@ejemplo.com',
    nombre: 'Yaritza Guerra',
    sucursal: 'CCS-02',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario66-23043417',
    usuario: 'usuario66',
    cedula: '23043417',
    correo: 'pedro.quintero65@ejemplo.com',
    nombre: 'Pedro Quintero',
    sucursal: 'MCB-03',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario67-23241260',
    usuario: 'usuario67',
    cedula: '23241260',
    correo: 'gladys.lopez66@ejemplo.com',
    nombre: 'Gladys López',
    sucursal: 'VAL-01',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario68-23440014',
    usuario: 'usuario68',
    cedula: '23440014',
    correo: 'argenis.rojas67@ejemplo.com',
    nombre: 'Argenis Rojas',
    sucursal: 'BQT-02',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario69-23639679',
    usuario: 'usuario69',
    cedula: '23639679',
    correo: 'nairobi.suarez68@ejemplo.com',
    nombre: 'Nairobi Suárez',
    sucursal: 'CBL-03',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario70-23840255',
    usuario: 'usuario70',
    cedula: '23840255',
    correo: 'gustavo.torres69@ejemplo.com',
    nombre: 'Gustavo Torres',
    sucursal: 'MCY-01',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario71-24041742',
    usuario: 'usuario71',
    cedula: '24041742',
    correo: 'coromoto.medina70@ejemplo.com',
    nombre: 'Coromoto Medina',
    sucursal: 'MTR-02',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario72-24244140',
    usuario: 'usuario72',
    cedula: '24244140',
    correo: 'osmel.gonzalez71@ejemplo.com',
    nombre: 'Osmel González',
    sucursal: 'SCR-03',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario73-24447449',
    usuario: 'usuario73',
    cedula: '24447449',
    correo: 'carmen.blanco72@ejemplo.com',
    nombre: 'Carmen Blanco',
    sucursal: 'CCS-01',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario74-24651669',
    usuario: 'usuario74',
    cedula: '24651669',
    correo: 'rafael.bastidas73@ejemplo.com',
    nombre: 'Rafael Bastidas',
    sucursal: 'MCB-02',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario75-24856800',
    usuario: 'usuario75',
    cedula: '24856800',
    correo: 'nelida.garcia74@ejemplo.com',
    nombre: 'Nélida García',
    sucursal: 'VAL-03',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario76-25062842',
    usuario: 'usuario76',
    cedula: '25062842',
    correo: 'orlando.mendoza75@ejemplo.com',
    nombre: 'Orlando Mendoza',
    sucursal: 'BQT-01',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario77-25269795',
    usuario: 'usuario77',
    cedula: '25269795',
    correo: 'solange.pacheco76@ejemplo.com',
    nombre: 'Solange Pacheco',
    sucursal: 'CBL-02',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario78-25477659',
    usuario: 'usuario78',
    cedula: '25477659',
    correo: 'edgar.sanchez77@ejemplo.com',
    nombre: 'Edgar Sánchez',
    sucursal: 'MCY-03',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario79-25686434',
    usuario: 'usuario79',
    cedula: '25686434',
    correo: 'nakary.castillo78@ejemplo.com',
    nombre: 'Nakary Castillo',
    sucursal: 'MTR-01',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario80-25896120',
    usuario: 'usuario80',
    cedula: '25896120',
    correo: 'jose.villalobos79@ejemplo.com',
    nombre: 'José Villalobos',
    sucursal: 'SCR-02',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario81-26106717',
    usuario: 'usuario81',
    cedula: '26106717',
    correo: 'yolanda.flores80@ejemplo.com',
    nombre: 'Yolanda Flores',
    sucursal: 'CCS-03',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario82-26318225',
    usuario: 'usuario82',
    cedula: '26318225',
    correo: 'franklin.salazar81@ejemplo.com',
    nombre: 'Franklin Salazar',
    sucursal: 'MCB-01',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario83-26530644',
    usuario: 'usuario83',
    cedula: '26530644',
    correo: 'belkis.perez82@ejemplo.com',
    nombre: 'Belkis Pérez',
    sucursal: 'VAL-02',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario84-26743974',
    usuario: 'usuario84',
    cedula: '26743974',
    correo: 'freddy.moreno83@ejemplo.com',
    nombre: 'Freddy Moreno',
    sucursal: 'BQT-03',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario85-26958215',
    usuario: 'usuario85',
    cedula: '26958215',
    correo: 'morella.marcano84@ejemplo.com',
    nombre: 'Morella Marcano',
    sucursal: 'CBL-01',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario86-27173367',
    usuario: 'usuario86',
    cedula: '27173367',
    correo: 'eleazar.martinez85@ejemplo.com',
    nombre: 'Eleazar Martínez',
    sucursal: 'MCY-02',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario87-27389430',
    usuario: 'usuario87',
    cedula: '27389430',
    correo: 'maria.silva86@ejemplo.com',
    nombre: 'María Silva',
    sucursal: 'MTR-03',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario88-27606404',
    usuario: 'usuario88',
    cedula: '27606404',
    correo: 'carlos.zambrano87@ejemplo.com',
    nombre: 'Carlos Zambrano',
    sucursal: 'SCR-01',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario89-27824289',
    usuario: 'usuario89',
    cedula: '27824289',
    correo: 'zulay.ramirez88@ejemplo.com',
    nombre: 'Zulay Ramírez',
    sucursal: 'CCS-02',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario90-28043085',
    usuario: 'usuario90',
    cedula: '28043085',
    correo: 'wilmer.vargas89@ejemplo.com',
    nombre: 'Wilmer Vargas',
    sucursal: 'MCB-03',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario91-28262792',
    usuario: 'usuario91',
    cedula: '28262792',
    correo: 'deisy.rodriguez90@ejemplo.com',
    nombre: 'Deisy Rodríguez',
    sucursal: 'VAL-01',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario92-28483410',
    usuario: 'usuario92',
    cedula: '28483410',
    correo: 'anibal.rivas91@ejemplo.com',
    nombre: 'Aníbal Rivas',
    sucursal: 'BQT-02',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario93-28704939',
    usuario: 'usuario93',
    cedula: '28704939',
    correo: 'rosalba.colmenares92@ejemplo.com',
    nombre: 'Rosalba Colmenares',
    sucursal: 'CBL-03',
    ciudad: 'Ciudad Bolívar',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario94-28927379',
    usuario: 'usuario94',
    cedula: '28927379',
    correo: 'luis.hernandez93@ejemplo.com',
    nombre: 'Luis Hernández',
    sucursal: 'MCY-01',
    ciudad: 'Maracay',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario95-29150730',
    usuario: 'usuario95',
    cedula: '29150730',
    correo: 'elena.guerra94@ejemplo.com',
    nombre: 'Elena Guerra',
    sucursal: 'MTR-02',
    ciudad: 'Maturín',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario96-29374992',
    usuario: 'usuario96',
    cedula: '29374992',
    correo: 'antonio.quintero95@ejemplo.com',
    nombre: 'Antonio Quintero',
    sucursal: 'SCR-03',
    ciudad: 'San Cristóbal',
    plan: 'Plata',
  ),
  PersonaDePrueba(
    userId: 'usuario97-29600165',
    usuario: 'usuario97',
    cedula: '29600165',
    correo: 'milagros.lopez96@ejemplo.com',
    nombre: 'Milagros López',
    sucursal: 'CCS-01',
    ciudad: 'Caracas',
    plan: 'Bronce',
  ),
  PersonaDePrueba(
    userId: 'usuario98-29826249',
    usuario: 'usuario98',
    cedula: '29826249',
    correo: 'ramon.rojas97@ejemplo.com',
    nombre: 'Ramón Rojas',
    sucursal: 'MCB-02',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
  ),
  PersonaDePrueba(
    userId: 'usuario99-30053244',
    usuario: 'usuario99',
    cedula: '30053244',
    correo: 'yenifer.suarez98@ejemplo.com',
    nombre: 'Yenifer Suárez',
    sucursal: 'VAL-03',
    ciudad: 'Valencia',
    plan: 'Oro',
  ),
  PersonaDePrueba(
    userId: 'usuario100-30281150',
    usuario: 'usuario100',
    cedula: '30281150',
    correo: 'wladimir.torres99@ejemplo.com',
    nombre: 'Wladimir Torres',
    sucursal: 'BQT-01',
    ciudad: 'Barquisimeto',
    plan: 'Plata',
  ),
];

// ── Atajos para armar pruebas sin recorrer la lista a mano ────────────────

/// Las sucursales que existen en el juego de prueba, ordenadas.
List<String> get sucursalesDePrueba =>
    (cienPersonas.map((p) => p.sucursal).toSet().toList()..sort());

/// Los planes que existen.
List<String> get planesDePrueba =>
    (cienPersonas.map((p) => p.plan).toSet().toList()..sort());

/// Las de una sucursal. Para probar el envío segmentado.
List<PersonaDePrueba> deLaSucursal(String sucursal) =>
    cienPersonas.where((p) => p.sucursal == sucursal).toList();

/// Las de un plan.
List<PersonaDePrueba> delPlan(String plan) =>
    cienPersonas.where((p) => p.plan == plan).toList();

/// Buscar por cédula, que es el caso de uso que motivó todo el modelo de alias:
/// el emisor conoce la cédula y no el `userId`.
PersonaDePrueba? porCedula(String cedula) {
  for (final p in cienPersonas) {
    if (p.cedula == cedula) return p;
  }
  return null;
}

/// Entrar como la enésima. `porUsuario('usuario7')` o `laNumero(7)` — lo mismo.
PersonaDePrueba? porUsuario(String usuario) {
  for (final p in cienPersonas) {
    if (p.usuario == usuario) return p;
  }
  return null;
}

/// La enésima, de 1 a 100.
PersonaDePrueba? laNumero(int n) =>
    (n < 1 || n > cienPersonas.length) ? null : cienPersonas[n - 1];

/// Buscar por parecido en el nombre, que es lo que hace la consola.
List<PersonaDePrueba> buscarPorNombre(String texto) {
  final t = texto.trim().toLowerCase();
  if (t.isEmpty) return const [];
  return cienPersonas
      .where((p) => p.nombre.toLowerCase().contains(t))
      .toList();
}

// ── Los cuatro casos del modelo de identidad ───────────────────────────────
//
// Van APARTE de las cien, no mezclados adentro: [cienPersonas] promete cien
// personas naturales con cédula desde su propio nombre y su comentario, y
// agregar acá cuatro entradas de otra forma lo volvería falso para quien lo
// lea sin mirar el final del archivo. `main.dart` junta las dos listas para
// que las cuatro sean seleccionables en la pantalla del demo.

/// Dos empresas — `TipoDeSujeto.juridica`, con RIF.
const empresasDePrueba = <PersonaDePrueba>[
  PersonaDePrueba(
    userId: 'empresa1-J304521679',
    usuario: 'empresa1',
    cedula: 'J-304521679',
    correo: 'compras@distribuidoraelfaro.com.ve',
    nombre: 'Distribuidora El Faro, C.A.',
    sucursal: 'CCS-01',
    ciudad: 'Caracas',
    plan: 'Empresas',
    tipo: TipoDeSujeto.juridica,
    claseDeDocumento: ClaseDeDocumento.rif,
  ),
  PersonaDePrueba(
    userId: 'empresa2-J403187745',
    usuario: 'empresa2',
    cedula: 'J-403187745',
    correo: 'administracion@construval.com.ve',
    nombre: 'Construval Ingeniería, C.A.',
    sucursal: 'VAL-02',
    ciudad: 'Valencia',
    plan: 'Empresas',
    tipo: TipoDeSujeto.juridica,
    claseDeDocumento: ClaseDeDocumento.rif,
  ),
];

/// Dos empleados de un proveedor — naturales, con [Organizacion]. El sujeto
/// PERTENECE a la organización, no se reemplaza por ella: sigue teniendo su
/// propia cédula y su propio `userId`.
const empleadosDeProveedorDePrueba = <PersonaDePrueba>[
  PersonaDePrueba(
    userId: 'empleado1-19988341',
    usuario: 'empleado1',
    cedula: '19988341',
    correo: 'jgimenez@logisticasur.com.ve',
    nombre: 'Julio Giménez',
    sucursal: 'MCB-02',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
    organizacion: Organizacion(
      codigo: 'prov-logisticasur',
      nombre: 'Logística Sur, C.A.',
      rol: 'repartidor',
    ),
  ),
  PersonaDePrueba(
    userId: 'empleado2-20214477',
    usuario: 'empleado2',
    cedula: '20214477',
    correo: 'mtovar@logisticasur.com.ve',
    nombre: 'Mariana Tovar',
    sucursal: 'MCB-02',
    ciudad: 'Maracaibo',
    plan: 'Empleados',
    organizacion: Organizacion(
      codigo: 'prov-logisticasur',
      nombre: 'Logística Sur, C.A.',
      rol: 'supervisora',
    ),
  ),
];

/// Las cuatro juntas, para ofrecerlas en la pantalla del demo junto con las
/// cien. Ver la nota de arriba sobre por qué no van adentro de [cienPersonas].
const casosDeIdentidadDePrueba = <PersonaDePrueba>[
  ...empresasDePrueba,
  ...empleadosDeProveedorDePrueba,
];
