/// LAS SEÑALES DE NIVEL 0 — todo lo que se lee del teléfono sin pedir un permiso.
///
/// Son ~90 campos, y **no salen todos del mismo lado**. Fueron cuatro investigaciones en
/// paralelo el 2026-08-31, no una:
///
///   · Los seis primeros grupos —configuración, accesibilidad, batería, sensores, perfil y
///     red— salen del **bytecode del núcleo de CredoLab**, descompilado del SDK instalado en
///     la aplicación de Credit CX. Son las claves que leen de verdad, verificadas contra el
///     binario. De sus ~150 campos, éstos son los que **no cuestan fricción**.
///
///   · El séptimo —`hd_`, la huella digital— **CredoLab no lo tiene**, y es el único grupo con
///     respaldo independiente: del estudio de Berg, Burg, Gombovic y Puri para **NBER sobre
///     270.000 compras**, donde un modelo hecho *sólo* con huella digital —tipo de aparato,
///     sistema, hora de la compra, canal— alcanzó **AUC 69,6% contra 68,3% del FICO**. Y de la
///     revisión del mercado antifraude, donde la coherencia entre idioma, zona horaria y país
///     de la SIM es la señal más barata que existe.
///
/// 🔴 Ninguna cifra publicada por un proveedor de este sector está auditada por terceros. Las
/// de NBER sí. Y **Kreditech publicitaba 20.000 puntos de datos y quebró**: más campos no es
/// mejor puntaje. Estos se eligieron por lo que aportan, no por llenar una lista.
///
/// 🔴 NINGUNO PIDE PERMISO Y NINGUNO DICE QUIÉN ES LA PERSONA. Dicen cómo está configurado
/// el aparato y si se comporta como un teléfono de verdad. Esa distinción es la que permite
/// que este módulo nazca prendido mientras ubicación y avisos nacen apagados.
///
/// **Lo que deliberadamente NO se trae**, aunque CredoLab sí:
///
///   · La lista de sensores con vendedor y resolución. Es una huella de dispositivo bastante
///     única, y Apple prohíbe la huella combinada tenga o no consentimiento. Se manda cuántos
///     hay y cuáles de los básicos existen, que es lo que separa un teléfono de un emulador.
///   · El nombre de la aplicación marcada como depurable si no es la nuestra. Es un dato de
///     terceros que no nos corresponde y no aporta al puntaje.
///   · El BSSID y el nombre de la red WiFi. Exigen permiso de ubicación desde Android 8 y
///     además dicen dónde está la persona.
///   · La lista de paquetes de accesibilidad. Se manda cuántos hay y qué pueden hacer, que es
///     lo único que importa para decir «hay una herramienta de control remoto activa».
library;

import 'dart:io';

import 'package:flutter/services.dart';

import '../permisologia/transformar.dart';
import 'modulo.dart';

class ModuloDeSenales extends Modulo {
  ModuloDeSenales();

  static const _canal = MethodChannel('hz_collection_sdk/senales');

  DateTime? _ultimaVez;
  String? _ultimoMotivo;

  @override
  String get nombre => 'senales';

  @override
  int get nivel => Nivel.sinPermiso;

  /// Una foto al dar de alta. La configuración de un teléfono no cambia entre sesiones lo
  /// suficiente como para justificar medirla seguido.
  @override
  Cadencia get cadencia => Cadencia.episodica;

  @override
  List<String> get permisos => const [];

  @override
  Future<void> alEntrar(Contexto c) async {
    final id = c.sujetoId;
    if (id == null) return;
    try {
      final medido = await medir();
      if (medido.isEmpty) {
        _ultimoMotivo = 'el sistema no devolvió ninguna medición';
        return;
      }
      await c.api.reportarSenales(
        sujetoId: id,
        instalacionId: c.instalacionId,
        modulo: nombre,
        senales: medido,
      );
      _ultimaVez = DateTime.now();
      _ultimoMotivo = null;
    } catch (e) {
      // Nunca tumba nada. Perder estas señales cuesta poder de un puntaje; que falle el
      // inicio de sesión cuesta que esa persona no reciba nada.
      _ultimoMotivo = 'falló al medir o al enviar: $e';
    }
  }

  @override
  Future<EstadoDeModulo> estado(Contexto c) async => EstadoDeModulo(
        andando: _ultimoMotivo == null,
        detalle: _ultimaVez == null
            ? 'todavía no midió'
            : 'midió hace ${DateTime.now().difference(_ultimaVez!).inMinutes} min',
        ultimoMotivo: _ultimoMotivo,
        ultimaVez: _ultimaVez,
      );

  /// Mide. Público para poder probarlo sin montar toda la fachada.
  ///
  /// 🔴 Sólo Android por ahora, y se dice en vez de devolver ceros: en iOS ni la
  /// configuración del sistema ni los servicios de accesibilidad tienen una API pública
  /// equivalente. Devolver un mapa vacío es honesto; devolverlo lleno de ceros haría que un
  /// puntaje tratara a todos los iPhone como si fueran el mismo teléfono raro.
  Future<Map<String, Object?>> medir() async {
    if (!Platform.isAndroid) return const {};
    final crudo = await _canal.invokeMapMethod<String, Object?>('medir');
    if (crudo == null || crudo.isEmpty) return const {};

    // Todo pasa por la capa de transformación, igual que el resto. Acá casi todo es
    // `taICual` porque son propiedades del aparato y no texto que haya escrito nadie — pero
    // pasa por el mismo camino para que la regla no tenga excepciones.
    return armarPaquete(camposDeSenales, Map<String, Object?>.from(crudo));
  }
}

/// Las fichas. Cada una dice QUÉ MANDA, en castellano: es el texto que se le puede mostrar a
/// una persona que pregunte qué se sabe de ella, y a un comercio que quiera saber qué está
/// recolectando. Un campo cuyo «qué manda» no se puede escribir en una frase es un campo que
/// nadie entiende, incluidos nosotros.
const List<CampoRecolectado> camposDeSenales = [
  // ── Configuración del sistema ─────────────────────────────────────────────────────────
  CampoRecolectado('cfg_adb_enabled', Transformacion.taICual,
      queManda: 'si la depuración por USB está activa. No es normal en un teléfono de uso diario'),
  CampoRecolectado('cfg_development_settings_enabled', Transformacion.taICual,
      queManda: 'si las opciones de desarrollador están activas'),
  CampoRecolectado('cfg_debug_app_es_la_nuestra', Transformacion.taICual,
      queManda: 'si la aplicación marcada como depurable es la nuestra. El nombre de otra no se manda'),
  CampoRecolectado('cfg_install_non_market_apps', Transformacion.taICual,
      queManda: 'si permite instalar aplicaciones de fuera de la tienda'),
  CampoRecolectado('cfg_device_provisioned', Transformacion.taICual,
      queManda: 'si el teléfono terminó su configuración inicial'),
  CampoRecolectado('cfg_airplane_mode_on', Transformacion.taICual,
      queManda: 'si el modo avión está prendido en este momento'),
  CampoRecolectado('cfg_boot_count', Transformacion.tramo, tramoDe: 50,
      queManda: 'cuántas veces se encendió el teléfono, por tramos de cincuenta'),
  CampoRecolectado('cfg_usb_mass_storage_enabled', Transformacion.taICual,
      queManda: 'si el almacenamiento por USB está habilitado'),
  CampoRecolectado('cfg_window_animation_scale', Transformacion.taICual,
      queManda: 'la velocidad de las animaciones de ventana. En cero suele ser un emulador'),
  CampoRecolectado('cfg_transition_animation_scale', Transformacion.taICual,
      queManda: 'la velocidad de las transiciones. En cero suele ser un emulador'),
  CampoRecolectado('cfg_animator_duration_scale', Transformacion.taICual,
      queManda: 'la duración de las animaciones. En cero suele ser un emulador'),
  CampoRecolectado('cfg_stay_on_while_plugged_in', Transformacion.taICual,
      queManda: 'si la pantalla queda encendida al enchufarlo. Típico de un aparato de granja'),
  CampoRecolectado('cfg_screen_off_timeout', Transformacion.taICual,
      queManda: 'a los cuántos milisegundos se apaga la pantalla sola'),
  CampoRecolectado('cfg_screen_brightness_mode', Transformacion.taICual,
      queManda: 'si el brillo es automático o manual'),
  CampoRecolectado('cfg_font_scale', Transformacion.taICual,
      queManda: 'el tamaño de letra elegido en el sistema'),
  CampoRecolectado('cfg_sound_effects_enabled', Transformacion.taICual,
      queManda: 'si los sonidos del sistema están activos'),
  CampoRecolectado('cfg_time_12_24', Transformacion.taICual,
      queManda: 'si usa reloj de 12 o de 24 horas'),
  CampoRecolectado('cfg_accelerometer_rotation', Transformacion.taICual,
      queManda: 'si la pantalla rota sola con el acelerómetro'),
  CampoRecolectado('cfg_haptic_feedback_enabled', Transformacion.taICual,
      queManda: 'si la vibración al tocar está activa'),
  CampoRecolectado('cfg_default_input_method', Transformacion.presencia,
      queManda: 'si tiene teclado configurado. No se manda cuál: sería un dato de terceros'),
  CampoRecolectado('cfg_wifi_watchdog_on', Transformacion.taICual,
      queManda: 'un ajuste de red que en los emuladores suele estar en su valor de fábrica'),
  CampoRecolectado('cfg_wifi_num_open_networks_kept', Transformacion.taICual,
      queManda: 'cuántas redes abiertas recuerda el sistema'),
  CampoRecolectado('cfg_wifi_max_dhcp_retry_count', Transformacion.taICual,
      queManda: 'cuántos reintentos de red permite el sistema'),
  CampoRecolectado('cfg_end_button_behavior', Transformacion.taICual,
      queManda: 'qué hace el botón de colgar'),
  CampoRecolectado('cfg_dtmf_tone', Transformacion.taICual,
      queManda: 'si suenan los tonos al marcar'),
  CampoRecolectado('cfg_accessibility_enabled', Transformacion.taICual,
      queManda: 'si la accesibilidad del sistema está activa'),
  CampoRecolectado('cfg_contact_metadata_sync_enabled', Transformacion.taICual,
      queManda: 'si sincroniza datos de contactos. NO se leen los contactos'),

  // ── Accesibilidad ─────────────────────────────────────────────────────────────────────
  CampoRecolectado('acc_prendida', Transformacion.taICual,
      queManda: 'si hay accesibilidad activa en el teléfono'),
  CampoRecolectado('acc_exploracion_tactil', Transformacion.taICual,
      queManda: 'si la exploración táctil está activa'),
  CampoRecolectado('acc_activos', Transformacion.taICual,
      queManda: 'cuántos servicios de accesibilidad están activos ahora'),
  CampoRecolectado('acc_instalados', Transformacion.taICual,
      queManda: 'cuántos hay instalados. No se manda cuáles'),
  CampoRecolectado('acc_puede_leer_la_pantalla', Transformacion.taICual,
      queManda: 'si algún servicio activo puede leer lo que hay en pantalla'),
  CampoRecolectado('acc_puede_tocar_por_vos', Transformacion.taICual,
      queManda: 'si algún servicio activo puede tocar la pantalla por la persona'),
  CampoRecolectado('acc_activos_sin_declararse_herramienta', Transformacion.taICual,
      queManda: 'cuántos usan la accesibilidad sin declararse herramienta de accesibilidad'),

  // ── Batería ───────────────────────────────────────────────────────────────────────────
  CampoRecolectado('bat_voltaje_mv', Transformacion.tramo, tramoDe: 100,
      queManda: 'el voltaje de la batería, por tramos. Los emuladores dan valores redondos'),
  CampoRecolectado('bat_temperatura_decimas_c', Transformacion.tramo, tramoDe: 50,
      queManda: 'la temperatura de la batería, por tramos'),
  CampoRecolectado('bat_tecnologia', Transformacion.taICual,
      queManda: 'de qué tipo es la batería, por ejemplo Li-ion'),
  CampoRecolectado('bat_salud', Transformacion.taICual,
      queManda: 'el estado de salud que reporta la batería'),
  CampoRecolectado('bat_enchufado_a', Transformacion.taICual,
      queManda: 'a qué está enchufado: cargador, USB o inalámbrico'),
  CampoRecolectado('bat_escala', Transformacion.taICual,
      queManda: 'la escala con la que el sistema informa la carga'),
  CampoRecolectado('bat_presente', Transformacion.taICual,
      queManda: 'si el sistema dice que hay una batería puesta'),

  // ── Sensores ──────────────────────────────────────────────────────────────────────────
  CampoRecolectado('sen_cantidad', Transformacion.taICual,
      queManda: 'cuántos sensores tiene. Un teléfono real tiene entre quince y treinta'),
  CampoRecolectado('sen_hay_acelerometro', Transformacion.taICual, queManda: 'si tiene acelerómetro'),
  CampoRecolectado('sen_hay_giroscopio', Transformacion.taICual, queManda: 'si tiene giroscopio'),
  CampoRecolectado('sen_hay_magnetometro', Transformacion.taICual, queManda: 'si tiene brújula'),
  CampoRecolectado('sen_hay_proximidad', Transformacion.taICual, queManda: 'si tiene sensor de proximidad'),
  CampoRecolectado('sen_hay_luz', Transformacion.taICual, queManda: 'si tiene sensor de luz'),
  CampoRecolectado('sen_hay_barometro', Transformacion.taICual, queManda: 'si tiene barómetro'),
  CampoRecolectado('sen_hay_paso', Transformacion.taICual, queManda: 'si tiene contador de pasos'),
  CampoRecolectado('sen_genericos', Transformacion.taICual,
      queManda: 'cuántos sensores dicen ser del fabricante genérico. En un emulador, todos'),

  // ── Perfil de usuario ─────────────────────────────────────────────────────────────────
  CampoRecolectado('usr_es_el_principal', Transformacion.taICual,
      queManda: 'si la aplicación corre en el usuario principal del teléfono'),
  CampoRecolectado('usr_es_demo', Transformacion.taICual,
      queManda: 'si el teléfono está en modo demostración, como los de vidriera'),
  CampoRecolectado('usr_en_primer_plano', Transformacion.taICual,
      queManda: 'si el usuario del sistema está en primer plano'),

  // ── Red ───────────────────────────────────────────────────────────────────────────────
  CampoRecolectado('red_es_wifi', Transformacion.taICual, queManda: 'si está conectado por WiFi'),
  CampoRecolectado('red_es_celular', Transformacion.taICual, queManda: 'si está conectado por datos'),
  CampoRecolectado('red_hay_vpn', Transformacion.taICual,
      queManda: 'si hay una VPN activa. No dice cuál ni a dónde'),
  CampoRecolectado('red_sin_limite_de_datos', Transformacion.taICual,
      queManda: 'si la conexión no tiene límite de datos'),
  CampoRecolectado('red_sin_roaming', Transformacion.taICual, queManda: 'si NO está en roaming'),
  CampoRecolectado('red_bajada_kbps', Transformacion.tramo, tramoDe: 1000,
      queManda: 'la velocidad de bajada estimada, por tramos'),
  CampoRecolectado('red_subida_kbps', Transformacion.tramo, tramoDe: 1000,
      queManda: 'la velocidad de subida estimada, por tramos'),

  // ── La huella digital ─────────────────────────────────────────────────────────────────
  // El grupo de NBER, el único con respaldo auditado. No es de CredoLab: ellos no lo tienen.
  CampoRecolectado('hd_hora_local', Transformacion.taICual,
      queManda: 'a qué hora del día se midió. Es el campo más citado del estudio de NBER'),
  CampoRecolectado('hd_dia_de_semana', Transformacion.taICual,
      queManda: 'qué día de la semana se midió'),
  CampoRecolectado('hd_zona_horaria', Transformacion.taICual,
      queManda: 'qué zona horaria tiene puesta el teléfono. No dice dónde está: dice qué declara'),
  CampoRecolectado('hd_minutos_de_desfase_utc', Transformacion.taICual,
      queManda: 'cuántos minutos de diferencia con la hora universal'),
  CampoRecolectado('hd_hora_automatica', Transformacion.taICual,
      queManda: 'si la hora la pone la red o la puso alguien a mano'),
  CampoRecolectado('hd_zona_automatica', Transformacion.taICual,
      queManda: 'si la zona horaria la pone la red o la puso alguien a mano'),
  CampoRecolectado('hd_idioma', Transformacion.taICual,
      queManda: 'en qué idioma está el teléfono'),
  CampoRecolectado('hd_pais_del_sistema', Transformacion.taICual,
      queManda: 'qué país declara la configuración del teléfono'),
  CampoRecolectado('hd_idiomas_configurados', Transformacion.taICual,
      queManda: 'cuántos idiomas tiene configurados'),
  CampoRecolectado('hd_pais_de_la_sim', Transformacion.taICual,
      queManda: 'de qué país es la SIM. NO se lee el número de teléfono ni el IMEI'),
  CampoRecolectado('hd_pais_de_la_red', Transformacion.taICual,
      queManda: 'de qué país es la red a la que está conectado'),
  CampoRecolectado('hd_operadora', Transformacion.taICual,
      queManda: 'el nombre de la operadora de telefonía'),
  CampoRecolectado('hd_estado_de_la_sim', Transformacion.taICual,
      queManda: 'si hay SIM y en qué estado está'),
  CampoRecolectado('hd_pais_coherente', Transformacion.taICual,
      queManda: 'si el país de la configuración y el de la SIM coinciden'),
  CampoRecolectado('hd_sim_y_red_coinciden', Transformacion.taICual,
      queManda: 'si el país de la SIM y el de la red coinciden. Distinto es no probar nada solo'),
  CampoRecolectado('hd_marca', Transformacion.taICual, queManda: 'la marca del teléfono'),
  CampoRecolectado('hd_modelo', Transformacion.taICual, queManda: 'el modelo del teléfono'),
  CampoRecolectado('hd_version_del_sistema', Transformacion.taICual,
      queManda: 'qué versión de Android tiene'),
  CampoRecolectado('hd_api', Transformacion.taICual,
      queManda: 'el número interno de esa versión de Android'),
  CampoRecolectado('hd_arquitectura', Transformacion.taICual,
      queManda: 'qué tipo de procesador tiene'),
  CampoRecolectado('hd_nucleos', Transformacion.taICual,
      queManda: 'cuántos núcleos tiene el procesador'),
  CampoRecolectado('hd_meses_sin_parche', Transformacion.taICual,
      queManda: 'hace cuántos meses que el fabricante no le manda una actualización de seguridad'),
  CampoRecolectado('hd_ram_total_mb', Transformacion.tramo, tramoDe: 512,
      queManda: 'cuánta memoria tiene, por tramos'),
  CampoRecolectado('hd_ram_libre_mb', Transformacion.tramo, tramoDe: 256,
      queManda: 'cuánta memoria tenía libre al medir, por tramos'),
  CampoRecolectado('hd_ram_en_las_ultimas', Transformacion.taICual,
      queManda: 'si el sistema estaba quedándose sin memoria al medir'),
  CampoRecolectado('hd_ram_poca', Transformacion.taICual,
      queManda: 'si el fabricante lo declara aparato de poca memoria'),
  CampoRecolectado('hd_densidad_dpi', Transformacion.taICual,
      queManda: 'la densidad de la pantalla'),
  CampoRecolectado('hd_pulgadas_x10', Transformacion.tramo, tramoDe: 5,
      queManda: 'el tamaño de la pantalla en décimas de pulgada, por tramos. La resolución exacta no se manda'),
  CampoRecolectado('hd_dias_desde_la_instalacion', Transformacion.tramo, tramoDe: 7,
      queManda: 'hace cuántos días se instaló nuestra aplicación, por semanas'),
  CampoRecolectado('hd_dias_desde_la_actualizacion', Transformacion.tramo, tramoDe: 7,
      queManda: 'hace cuántos días se actualizó nuestra aplicación, por semanas'),
  CampoRecolectado('hd_reinstalada', Transformacion.taICual,
      queManda: 'si nuestra aplicación se actualizó alguna vez desde que se instaló'),
  CampoRecolectado('hd_vino_de_la_tienda', Transformacion.taICual,
      queManda: 'si nuestra aplicación se instaló desde Google Play'),
  CampoRecolectado('hd_instalada_de_lado', Transformacion.taICual,
      queManda: 'si se instaló con un archivo suelto, sin tienda de por medio'),
  CampoRecolectado('hd_horas_desde_el_arranque', Transformacion.tramo, tramoDe: 24,
      queManda: 'hace cuántas horas se encendió el teléfono, por días'),
  CampoRecolectado('hd_teclados', Transformacion.taICual,
      queManda: 'cuántos teclados tiene configurados. No se manda cuáles'),
];
