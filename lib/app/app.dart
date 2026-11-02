import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_screen.dart';
import 'providers.dart';
import 'theme.dart';

class XoaiApp extends ConsumerStatefulWidget {
  const XoaiApp({super.key});

  @override
  ConsumerState<XoaiApp> createState() => _XoaiAppState();
}

class _XoaiAppState extends ConsumerState<XoaiApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Don't keep talking from the background (home button, screen off, call).
    _lifecycle = AppLifecycleListener(onHide: () => ref.read(voiceProvider).stop());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

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
