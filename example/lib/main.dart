import 'package:ak_push/ak_push.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// App en blanco que solo instala el SDK. No importa nada más.
///
/// El `10.0.2.2` es cómo un emulador de Android alcanza el localhost de la
/// máquina que lo hospeda.
const _llave = String.fromEnvironment('AKPUSH_KEY', defaultValue: 'akp_pub_demo_local');
const _servidor = String.fromEnvironment('AKPUSH_URL', defaultValue: 'http://10.0.2.2:3095');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ak_push demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5F63)),
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
  String _estado = 'sin iniciar';
  String? _token;
  bool _identificado = false;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  void _anotar(String linea) {
    if (!mounted) return;
    setState(() => _bitacora.insert(0, '${TimeOfDay.now().format(context)}  $linea'));
  }

  Future<void> _arrancar() async {
    setState(() => _estado = 'pidiendo configuración…');
    try {
      await AkPush.init(apiKey: _llave, baseUrl: _servidor);
      setState(() {
        _estado = AkPush.tienePermiso ? 'listo' : 'listo, sin permiso';
        _token = AkPush.token;
      });
      _anotar(_token == null ? 'sin token (¿permiso denegado?)' : 'token obtenido');

      AkPush.onMessage.listen((m) => _anotar('llegó: ${m.title ?? "(sin título)"}'));
      AkPush.onNotificationTap.listen((m) => _anotar('tocado: ${m.title ?? m.codeEvent ?? "?"}'));
    } on AkPushError catch (e) {
      setState(() => _estado = 'falló: ${e.code.name}');
      _anotar('${e.message}${e.details != null ? " — ${e.details}" : ""}');
    }
  }

  Future<void> _identificar() async {
    try {
      await AkPush.identify(userId: 'demo-1');
      setState(() => _identificado = true);
      _anotar('registrado como demo-1');
    } on AkPushError catch (e) {
      _anotar('no se pudo registrar: ${e.code.name}');
    }
  }

  Future<void> _salir() async {
    await AkPush.logout();
    setState(() => _identificado = false);
    _anotar('dado de baja');
  }

  /// Solo para probar: fuerza a FCM a emitir una dirección nueva, que es lo que
  /// pasa solo cuando alguien reinstala o limpia los datos. El SDK tiene que
  /// re-registrarla sin que nadie se lo pida.
  Future<void> _forzarRotacion() async {
    _anotar('forzando rotación…');
    await FirebaseMessaging.instance.deleteToken();
    final nuevo = await FirebaseMessaging.instance.getToken();
    if (!mounted) return;
    setState(() => _token = nuevo);
    _anotar('token nuevo emitido');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ak_push'),
        backgroundColor: t.colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estado', style: t.textTheme.labelMedium),
                    Text(_estado, style: t.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text('Dirección de este teléfono', style: t.textTheme.labelMedium),
                    SelectableText(
                      _token == null ? '—' : '${_token!.substring(0, 24)}…',
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _identificado ? null : _identificar,
                    child: const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _identificado ? _salir : null,
                    child: const Text('Cerrar sesión'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _forzarRotacion,
              child: const Text('Forzar rotación de la dirección'),
            ),
            const SizedBox(height: 12),
            Text('Bitácora', style: t.textTheme.labelMedium),
            const Divider(),
            Expanded(
              child: _bitacora.isEmpty
                  ? Center(
                      child: Text('Todavía no pasó nada',
                          style: t.textTheme.bodySmall))
                  : ListView.builder(
                      itemCount: _bitacora.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(_bitacora[i], style: t.textTheme.bodySmall),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
