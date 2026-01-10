import 'package:flutter/material.dart';
import 'package:meow_lang/tabs/home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Listener(
              onPointerDown: (_) => setState(() => _scale = 0.9),
              onPointerUp: (_) => setState(() => _scale = 1.0),
              onPointerCancel: (_) => setState(() => _scale = 1.0),
              child: AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/images/splash.png'),
                ),
              ),
            ),
            const SizedBox(height: 100),
            Text(
              'PROTOTYPE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
