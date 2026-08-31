import 'dart:convert';

import 'package:ak_push/ak_push.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'personas_de_prueba.dart';

/// El `10.0.2.2` es cómo un emulador de Android alcanza el localhost de la
/// máquina que lo hospeda.
const _llave = String.fromEnvironment('AKPUSH_KEY', defaultValue: 'pk_demo.local');
const _url = String.fromEnvironment('AKPUSH_URL', defaultValue: 'http://10.0.2.2:3096');

/// 🔴 ESTO NO VA EN UNA APLICACIÓN DE VERDAD. NUNCA.
///
/// El secreto con el que se firma el `userId` vive en el **backend** del
/// comercio, y la aplicación recibe la firma ya calculada junto con la sesión.
/// Ponerlo acá lo hace tan legible como la llave para cualquiera que descomprima
/// el APK — y entonces la firma deja de probar nada, que es exactamente el
/// agujero que la verificación de identidad viene a cerrar.
///
/// Está sólo para poder probar los modos AVISA y EXIGIDA de punta a punta sin
/// levantar un backend de mentira. Se pasa por `--dart-define` y si no viene, no
/// se firma nada.
const _secretoDePrueba = String.fromEnvironment('AKPUSH_SECRETO_DE_PRUEBA');

/// Lo que haría el backend del comercio: HMAC-SHA256 del userId, en hexadecimal.
String? _firmarComoLoHariaElBackend(String userId) {
  if (_secretoDePrueba.isEmpty) return null;
  return Hmac(sha256, utf8.encode(_secretoDePrueba))
      .convert(utf8.encode(userId))
      .toString();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ak_push',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D5F8A)),
          useMaterial3: true,
        ),
        home: const Pantalla(),
      );
}

class Pantalla extends StatefulWidget {
  const Pantalla({super.key});
  @override
  State<Pantalla> createState() => _PantallaState();
}

class _PantallaState extends State<Pantalla> {
  final List<String> _bitacora = [];
  String _estado = 'iniciando…';
  String? _token;
  PersonaDePrueba? _dentro;
  ResultadoDeSesion? _sesion;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  void _anotar(String l) {
    if (!mounted) return;
    setState(() => _bitacora.insert(0, '${TimeOfDay.now().format(context)}  $l'));
  }

  Future<void> _arrancar() async {
    try {
      // El permiso NO se pide acá: lo decide la política del comercio cuando la
      // persona inicia sesión. Es el momento en que ya sabe qué es la app.
      await AkPush.init(
        llave: _llave,
        url: _url,
        pedirPermisoAlIniciar: false,
      );
      setState(() {
        _estado = 'listo';
        _token = AkPush.token;
      });
      // El comercio no se configura: la configuración lo dice.
      _anotar('configuración de ${AkPush.comercio} · política: '
          '${AkPush.politica.momento.name}');

      AkPush.onMessage.listen((m) => _anotar('llegó: ${m.title ?? "(sin título)"}'));
      AkPush.onNotificationTap.listen((m) => _anotar('tocado: ${m.title ?? m.codeEvent ?? "?"}'));
    } on AkPushError catch (e) {
      setState(() => _estado = 'falló: ${e.code.name}');
      _anotar('${e.message}${e.details != null ? " — ${e.details}" : ""}');
    }
  }

  Future<void> _entrar(PersonaDePrueba p) async {
    _anotar('entrando como ${p.usuario} (${p.nombre})');
    try {
      final r = await AkPush.alIniciarSesion(
        userId: p.userId,
        identityHash: _firmarComoLoHariaElBackend(p.userId),
      );
      setState(() {
        _dentro = p;
        _sesion = r;
        _token = AkPush.token;
      });
      _anotar('${r.motivo}  ·  ${AkPush.consentimiento.punto}');

      // La pregunta blanda es de la app, no del SDK: el SDK sólo avisa cuándo.
      if (r.accionSugerida == AccionDePermiso.mostrarPreguntaBlanda) {
        await _preguntaBlanda();
      } else if (r.accionSugerida == AccionDePermiso.ofrecerAjustes) {
        _anotar('sólo quedan los Ajustes del teléfono');
      }
    } on AkPushError catch (e) {
      _anotar('no se pudo entrar: ${e.code.name}');
      if (e.code == AkPushErrorCode.firmaDeIdentidad) {
        _anotar('el comercio exige el userId firmado — pasá '
            '--dart-define=AKPUSH_SECRETO_DE_PRUEBA=…');
      }
    }
  }

  Future<void> _preguntaBlanda() async {
    final t = AkPush.politica.textos;
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.titulo),
        content: Text(t.cuerpo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.ahoraNo)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t.aceptar)),
        ],
      ),
    );
    // Se marca en los DOS casos, no sólo cuando acepta: un «ahora no» es el dato
    // que distingue a quien se puede recuperar de quien ya dijo que no de verdad.
    await AkPush.reportarModal(acepto: si == true);

    if (si != true) {
      _anotar('dijo «ahora no» — el diálogo del sistema no se gastó');
      return;
    }
    final e = await AkPush.pedirPermiso();
    _anotar('permiso: ${e.name}');
    if (_dentro != null) await _entrar(_dentro!);
  }

  Future<void> _salir() async {
    await AkPush.alCerrarSesion();
    setState(() { _dentro = null; _sesion = null; });
    _anotar('sesión cerrada · el teléfono quedó sin dueño');
  }

  Future<void> _elegirPersona() async {
    final p = await showModalBottomSheet<PersonaDePrueba>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _Selector(),
    );
    if (p != null) await _entrar(p);
  }

  Future<void> _verDiagnostico() async {
    final d = await AkPush.diagnostico();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Diagnóstico'),
        content: SingleChildScrollView(child: Text(d.toString())),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = _sesion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ak_push'),
        backgroundColor: t.colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _verDiagnostico,
            icon: const Icon(Icons.medical_information_outlined),
            tooltip: 'Diagnóstico',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estado', style: t.textTheme.labelMedium),
                  Text(_estado, style: t.textTheme.headlineSmall),
                  if (_dentro != null) ...[
                    const SizedBox(height: 10),
                    Text('${_dentro!.usuario} · ${_dentro!.nombre}',
                        style: t.textTheme.titleMedium),
                    Text('${_dentro!.cedula} · ${_dentro!.sucursal} · ${_dentro!.plan}',
                        style: t.textTheme.bodySmall),
                  ],
                  if (r != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(r.puedeRecibir ? Icons.check_circle : Icons.cancel,
                          size: 18,
                          color: r.puedeRecibir ? Colors.green.shade700 : Colors.orange.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(r.puedeRecibir ? 'Puede recibir' : 'No puede recibir',
                            style: t.textTheme.titleSmall),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(r.motivo, style: t.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 12),
                  Text('Dirección de este teléfono', style: t.textTheme.labelMedium),
                  Text(_token == null ? '—' : '${_token!.substring(0, 22)}…',
                      style: t.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _elegirPersona,
                icon: const Icon(Icons.person_search),
                label: Text(_dentro == null ? 'Entrar' : 'Cambiar de persona'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _dentro == null ? null : _salir,
                child: const Text('Salir'),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Text('Bitácora', style: t.textTheme.labelMedium),
          const Divider(),
          if (_bitacora.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Todavía no pasó nada', style: t.textTheme.bodySmall)),
            ),
          for (final l in _bitacora)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(l, style: t.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// Las cien, con búsqueda. Es lo que demuestra el modelo de identidad: se busca
/// por nombre —un atributo— y se entra por `userId`.
class _Selector extends StatefulWidget {
  @override
  State<_Selector> createState() => _SelectorState();
}

class _SelectorState extends State<_Selector> {
  String _texto = '';

  @override
  Widget build(BuildContext context) {
    // Se busca por las tres vías a la vez y se juntan sin repetir: por nombre
    // —que es un atributo—, por cédula —que es un alias— y por usuario.
    final lista = _texto.isEmpty
        ? cienPersonas
        : <PersonaDePrueba>{
            ...buscarPorNombre(_texto),
            if (porCedula(_texto) != null) porCedula(_texto)!,
            ...cienPersonas.where((p) => p.usuario.contains(_texto)),
          }.toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (c, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre, cédula o usuario',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _texto = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: lista.length,
              itemBuilder: (c, i) {
                final p = lista[i];
                return ListTile(
                  dense: true,
                  title: Text('${p.usuario} · ${p.nombre}'),
                  subtitle: Text('${p.cedula} · ${p.sucursal} · ${p.plan}'),
                  onTap: () => Navigator.pop(c, p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
