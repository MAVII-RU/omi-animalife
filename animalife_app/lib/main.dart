import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/animalife_api.dart';
import 'pages/login_page.dart';
import 'pages/pet_select_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const AnimalifeDeviceApp());
}

class AnimalifeDeviceApp extends StatelessWidget {
  const AnimalifeDeviceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnimalLife Device',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _Splash(),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await AnimalifeApi.getToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => token != null ? const PetSelectPage() : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: Center(child: Text('🐾', style: TextStyle(fontSize: 64))),
    );
  }
}
