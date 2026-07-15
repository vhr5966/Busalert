/// A confirmation dialog shown when the app detects a potential bus boarding.
///
/// The user can confirm the detected bus line, correct it, or dismiss the
/// detection if it was a false positive (e.g. they were walking near a stop).
///
/// This dialog is the fallback when WiFi SSID scanning doesn't provide
/// a definitive bus line match.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Shows the boarding confirmation dialog and returns the user's choice.
///
/// Returns a [BoardingConfirmation] with the confirmed bus line, or null
/// if the user dismissed the dialog.
Future<BoardingConfirmation?> showJourneyConfirmationDialog(
  BuildContext context, {
  required String stopName,
  String? detectedLine,
}) {
  final lineController = TextEditingController(text: detectedLine ?? '');

  return showDialog<BoardingConfirmation>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.directions_bus, color: kCardiffBlue),
            const SizedBox(width: 8),
            const Text('Bus Detected!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'It looks like you just boarded a bus near $stopName.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please confirm or enter the bus line number:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lineController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Bus line (e.g. 28, 1, 8)',
                hintText: 'Enter bus number',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text("Not on a bus"),
          ),
          FilledButton(
            onPressed: () {
              final line = lineController.text.trim();
              if (line.isEmpty) return;
              Navigator.of(context).pop(
                BoardingConfirmation(busLine: line),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      );
    },
  );
}

/// The result from the boarding confirmation dialog.
class BoardingConfirmation {
  final String busLine;
  BoardingConfirmation({required this.busLine});
}
