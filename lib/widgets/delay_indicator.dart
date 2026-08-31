/// A reusable delay indicator widget used across prediction, map, and
/// history screens. Shows a color-coded pill with the delay status text.
library;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Displays a colour-coded delay status pill.
///
/// [delayMinutes] is used to determine the colour and label:
/// * ≤ 2 min  → green, "On time"
/// * 2–10 min → amber, "Minor delay"
/// * > 10 min → red, "Major delay"
class DelayIndicator extends StatelessWidget {
  final double delayMinutes;
  final double fontSize;
  final bool hasData;

  const DelayIndicator({
    super.key,
    required this.delayMinutes,
    this.fontSize = 14,
    this.hasData = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasData) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: fontSize,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              'No Data',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      );
    }

    final color = delayColor(delayMinutes);
    final label = delayLabel(delayMinutes);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            delayMinutes <= 2
                ? Icons.check_circle
                : delayMinutes <= 10
                    ? Icons.warning_amber_rounded
                    : Icons.error,
            size: fontSize,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}
