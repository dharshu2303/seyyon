import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/backend_service.dart';
import 'screens/setup_screen.dart';
import 'screens/main_screen.dart';
import 'screens/consent_screen.dart';
import 'widgets/vel_icon.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendService.initialize();
  runApp(const SosApp());
}

class SosApp extends StatelessWidget {
  const SosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seyyon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Zoom-in animation over 2 seconds
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _zoomAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _zoomController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _zoomController.forward();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    // Wait for the 2-second animation to finish
    await Future.delayed(const Duration(seconds: 2));

    final isConsentGiven = await StorageService.isConsentGiven();
    final isSetupComplete = await StorageService.isSetupComplete();

    Widget destination;
    if (!isConsentGiven) {
      destination = const ConsentScreen();
    } else if (!isSetupComplete) {
      destination = const SetupScreen();
    } else {
      destination = const MainScreen();
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(opacity: anim, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF10B981),
              Color(0xFF065F46),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _zoomController,
            builder: (context, child) {
              return Transform.scale(
                scale: _zoomAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const VelIcon(size: 110, color: Colors.white),
                      const SizedBox(height: 24),
                      const Text(
                        'Seyyon',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'The Saviour',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white.withValues(alpha: 0.8),
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
