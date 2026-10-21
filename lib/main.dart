import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/music_home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SolenzMusicApp());
}

class SolenzMusicApp extends StatelessWidget {
  const SolenzMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Müzik Uygulaması',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MusicHomeScreen(),
    );
  }
}
