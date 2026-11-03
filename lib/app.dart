import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/user_service.dart';

class GymNotebookApp extends StatefulWidget {
  const GymNotebookApp({super.key});

  @override
  State<GymNotebookApp> createState() => _GymNotebookAppState();
}

class _GymNotebookAppState extends State<GymNotebookApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _loadThemeMode(String value) {
    final mode = value == 'light' ? ThemeMode.light : ThemeMode.dark;
    if (_themeMode != mode) setState(() => _themeMode = mode);
  }

  Future<void> _setDarkMode(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    setState(() => _themeMode = mode);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await UserService().saveThemeMode(uid, isDark ? 'dark' : 'light');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Notebook',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return UserInitializer(
              user: snapshot.data!,
              onThemeModeLoaded: _loadThemeMode,
              onDarkModeChanged: _setDarkMode,
            );
          }

          return const AuthScreen();
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00A67D),
      brightness: brightness,
    );
    return ThemeData(
      brightness: brightness,
      colorScheme: colors,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: isLight
          ? const Color(0xFFF2F6F4)
          : const Color(0xFF101715),
      cardColor: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1A2420),
      cardTheme: CardThemeData(
        color: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1A2420),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: isLight ? 0.6 : 0.3),
          ),
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: isLight
            ? const Color(0xFFF2F6F4)
            : const Color(0xFF101715),
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isLight ? const Color(0xFFE8EFEB) : const Color(0xFF202B27),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      useMaterial3: true,
    );
  }
}

class UserInitializer extends StatefulWidget {
  final User user;
  final ValueChanged<String> onThemeModeLoaded;
  final Future<void> Function(bool isDark) onDarkModeChanged;

  const UserInitializer({
    super.key,
    required this.user,
    required this.onThemeModeLoaded,
    required this.onDarkModeChanged,
  });

  @override
  State<UserInitializer> createState() => _UserInitializerState();
}

class _UserInitializerState extends State<UserInitializer> {
  late Future<String> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<String> _initialize() async {
    await UserService().initializeUser(
      uid: widget.user.uid,
      email: widget.user.email,
    );
    final mode = await UserService().getThemeMode(widget.user.uid);
    widget.onThemeModeLoaded(mode);
    return mode;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparando tu entrenamiento...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No se han podido cargar tus datos.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _initialization = _initialize();
                        });
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return HomeScreen(onDarkModeChanged: widget.onDarkModeChanged);
      },
    );
  }
}
