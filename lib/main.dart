import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

void main() => runApp(const InversionesApp());

class InversionesApp extends StatelessWidget {
  const InversionesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inversiones JS',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1A237E),
      ),
      builder: (context, child) {
        final MediaQueryData data = MediaQuery.of(context);
        // Limitamos el factor de escalado de texto para que no rompa el diseño
        // en dispositivos con fuentes del sistema muy grandes.
        return MediaQuery(
          data: data.copyWith(
            textScaleFactor: data.textScaleFactor.clamp(0.8, 1.2),
          ),
          child: child!,
        );
      },
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  WebViewController? _controller;
  bool _hasError = false;
  bool _isLoading = true;
  String imei = "buscando...";
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _inicializarApp();
  }

  // --- ALERTA (DIALOG) ---
  void _showErrorDialog() {
    if (_isDialogOpen) return;
    _isDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Color(0xFF1A237E)),
              SizedBox(width: 10),
              Text('Sin Conexión'),
            ],
          ),
          content: const Text(
            'No se puede establecer comunicación con el servidor',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogOpen = false;
                _reintentar();
              },
              child: const Text('REINTENTAR', 
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reintentar() async {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    // Usamos la misma URL de producción para el reintento
    _controller?.loadRequest(Uri.parse('http://10.10.4.20/android/index.php?imei=$imei'));
  }

  Future<void> _inicializarApp() async {
    await _obtenerOgenerarIdPersistente();
    
    // Configuración estética de la barra de sistema para mayor integración
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white) 
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // Filtro de errores de red reales vs interrupciones menores
            if (error.errorCode != -999) { // -999 suele ser 'cancelled' por el usuario o redirección
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
              _showErrorDialog();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('http://10.10.4.20/android/index.php?imei=$imei'));
    
    setState(() {});
  }

  Future<void> _obtenerOgenerarIdPersistente() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? idGuardado = prefs.getString('mi_id_unico_sasma');
    if (idGuardado == null) {
      var uuid = const Uuid();
      idGuardado = uuid.v4();
      await prefs.setString('mi_id_unico_sasma', idGuardado);
    }
    imei = idGuardado;
  }

  @override
  Widget build(BuildContext context) {
    if (imei == "buscando..." || _controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1A237E))),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_controller != null && await _controller!.canGoBack()) {
          _controller!.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        // Fondo azul oscuro si hay error
        backgroundColor: _hasError ? const Color(0xFF1A237E) : Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Opacity(
                opacity: _hasError ? 0.0 : 1.0,
                child: WebViewWidget(controller: _controller!),
              ),
              
              if (_hasError) _buildErrorView(),
              
              if (_isLoading)
                Container(
                  color: Colors.white,
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A237E)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- VISTA DE ERROR AZUL ---
  Widget _buildErrorView() {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 360;

    return Container(
      color: const Color(0xFF1A237E), // Fondo Azul
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded, 
            size: isSmallScreen ? 80 : 100, 
            color: Colors.white
          ),
          SizedBox(height: isSmallScreen ? 20 : 30),
          Text(
            'Sin conexión',
            style: TextStyle(
              fontSize: isSmallScreen ? 24 : 28, 
              fontWeight: FontWeight.bold, 
              color: Colors.white,
              fontStyle: FontStyle.italic
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No se puede establecer comunicación con el servidor',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16, 
              color: Colors.white70
            ),
          ),
          SizedBox(height: isSmallScreen ? 30 : 50),
          ElevatedButton.icon(
            onPressed: _reintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('REINTENTAR CONEXIÓN', 
              style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A237E),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20 : 30, 
                vertical: isSmallScreen ? 10 : 15
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }
}