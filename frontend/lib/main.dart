import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_nav_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const IdleCashApp(),
    ),
  );
}

class IdleCashApp extends StatelessWidget {
  const IdleCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IdleCash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: Consumer<AppState>(
        builder: (context, state, _) {
          if (!state.isSessionLoaded) {
            return const Scaffold(backgroundColor: Colors.black);
          }
          // If connected within 30-day session -> Go directly to Homepage (MainNavScreen)
          // Otherwise -> Go directly to Onboarding Carousel
          return state.isConnected
              ? const MainNavScreen()
              : const OnboardingScreen();
        },
      ),
    );
  }
}
