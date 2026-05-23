import 'package:flutter/material.dart';
import 'core/app_session.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main/main_shell.dart';
import 'widgets/call_watcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSession.loadSession();
  runApp(const CircleUpApp());
}

class CircleUpApp extends StatelessWidget {
  const CircleUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CircleUp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff5546f2),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff7f8fc),
      ),
      home: AppSession.isLoggedIn
          ? const CallWatcher(child: MainShell())
          : const AuthScreen(),
    );
  }
}
