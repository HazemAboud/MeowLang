import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'tabs/home.dart';
import 'splash.dart';
import 'tabs/theme.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models/user.dart';
import 'package:permission_handler/permission_handler.dart';
import 'backend/tflite_service.dart';

import 'dart:async';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Use manual mode to ensure the system bars are respected on physical devices
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.black12, // Provides visibility to the nav bar area
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MaterialAppWithTheme(),
    );
  }
}

class MaterialAppWithTheme extends StatelessWidget {
  const MaterialAppWithTheme({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeProvider.value,
      home: const AuthWrapper(),
      // Fix for "Zoomed in" look: Prevents system font scaling from breaking layout
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('[AppInit] AuthWrapper initialized');
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {

    final status = await Permission.microphone.request();
    
    if (!mounted) return;
    
    if (status.isDenied) {
      print('[Auth] Microphone permission denied. Translation will not work.');
    }

    // Pre-load TFLite model to avoid lag on the first translation
    // This ensures the native interpreter is warm and ready.
    try {
      final tflite = TfliteService();
      await tflite.loadModel();
    } catch (e) {
      print('[AppInit] Failed to pre-load model: $e');
    }

    _navigateHome();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('[AppLifecycle] App state changed to: $state');
  }

  Future<void> _navigateHome() async {
    // Wait for the splash screen duration
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    const storage = FlutterSecureStorage();
    final String? userId = await storage.read(key: 'userId');
    final String? email = await storage.read(key: 'userEmail');
    final String? name = await storage.read(key: 'userName');

    if (!mounted) return;

    if (userId != null && email != null) {
      print('[Auth] Secure session found. Auto-logging in user: $userId');
      User.login(User(
        userId: userId,
        name: name ?? email,
        email: email,
        regDate: null,
      ));
    }

    if (!mounted) return;
    // Always navigate to Home; the Home widget handles whether to show 
    // the login form or the profile based on User.isLoggedIn.
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Home()));
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}