import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'navigation/app_container.dart';

void main() {
  runApp(const TechbirdHrApp());
}

class TechbirdHrApp extends StatelessWidget {
  const TechbirdHrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: Consumer<ThemeNotifier>(
        builder: (context, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Techbird HR',
            theme: theme.lightTheme,
            darkTheme: theme.darkTheme,
            themeMode: theme.mode,
            home: const AppContainer(),
          );
        },
      ),
    );
  }
}
