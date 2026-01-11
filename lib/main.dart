import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/channel_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/user_selection_screen.dart';

import 'package:media_kit/media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Force landscape orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChannelProvider()),
      ],
      child: const IptvSmartCastApp(),
    ),
  );
}

class IptvSmartCastApp extends StatelessWidget {
  const IptvSmartCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Smart Cast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 0,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          // Show splash/loading while AuthProvider initializes
          if (!auth.isInitialized) {
            return const Scaffold(
              backgroundColor: Color(0xFF121212),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
              ),
            );
          }

          // Once Initialized:
          if (auth.currentUser != null) {
            return const HomeScreen();
          }

          if (auth.users.isNotEmpty) {
            return const UserSelectionScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
