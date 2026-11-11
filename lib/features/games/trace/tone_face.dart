import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/content/content_validator.dart' show toneIds;
import 'pop_in_card.dart';
import 'tone_trace.dart';

/// The traced mark on the done card.
const kToneMarkColor = Color(0xFFE08A00);

/// The "+" and "=" on the done card.
const kToneSignColor = Color(0xFF7FA6D6);

/// Shown once a mark is traced: "A + ´ = Á", and "dấu sắc" under it.
class ToneFace extends StatelessWidget {
  const ToneFace(this.item, {super.key});

  final ToneTraceItem item;

  @override
  Widget build(BuildContext context) {
    const letter = TextStyle(fontSize: 88, height: 1.1, fontWeight: FontWeight.bold, color: IceColors.deep);
    const sign = TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: kToneSignColor);
    // Scaled down rather than clipped when the pad is small (a phone of 360 dp wide).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: PopInCard(
        key: const Key('tone-face'),
        glow: true,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(item.baseUpper, style: letter),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('+', style: sign)),
                Text(item.tone.mark, style: letter.copyWith(color: kToneMarkColor)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('=', style: sign)),
                Text(item.combinedUpper, style: letter),
              ],
            ),
            Text(
              'dấu ${item.tone.name}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: IceColors.deep),
            ),
          ],
        ),
      ),
    );
  }
}

/// The five marks in a row above the pad, the one being traced ([current], a tone id) filled in.
class ToneRow extends StatelessWidget {
  const ToneRow({super.key, required this.current});

  final String current;

  static const double tileSize = 50;
  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, id) in toneIds.indexed)
          Padding(
            padding: EdgeInsets.only(left: i > 0 ? gap : 0),
            child: Container(
              key: Key('tone-tile-$id'),
              width: tileSize,
              height: tileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: id == current ? IceColors.deep : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                toneTileGlyphs[id] ?? '',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: id == current ? Colors.white : IceColors.deep,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
