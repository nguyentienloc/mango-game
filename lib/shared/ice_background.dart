import 'package:flutter/material.dart';

import '../app/theme.dart';

class IceBackground extends StatelessWidget {
  const IceBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [IceColors.sky, IceColors.ice],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
