import 'package:flutter/material.dart';
import 'player_hub.dart';
import 'app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MiAppAudio());
}

class MiAppAudio extends StatelessWidget {
  const MiAppAudio({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Música Local',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF09090B),
          colorScheme: const ColorScheme.dark(
            primary: appRed,
            secondary: appPurple,
            surface: Color(0xFF1D1D20),
          ),
          sliderTheme: const SliderThemeData(
            activeTrackColor: appRed,
            thumbColor: Colors.white,
            inactiveTrackColor: Color(0xFF343438),
            trackHeight: 4,
          ),
          useMaterial3: true,
        ),
        home: const PlayerHub(),
      );
}
