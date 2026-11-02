import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/content/models.dart';

/// Pops up after a correct answer: the example picture and word.
class ExampleCard extends StatelessWidget {
  const ExampleCard({super.key, required this.item});

  final LetterItem item;

  @override
  Widget build(BuildContext context) {
    final image = item.exampleImage;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null)
                Image.asset('content/$image', width: 120, height: 120)
              else
                Text(item.exampleEmoji ?? '', style: const TextStyle(fontSize: 96)),
              Text(
                item.exampleWord,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: IceColors.deep),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
