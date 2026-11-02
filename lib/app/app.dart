import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import 'theme.dart';

class XoaiApp extends StatelessWidget {
  const XoaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lâu đài Xoài',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
