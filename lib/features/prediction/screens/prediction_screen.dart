/// Delay prediction screen.
///
/// The user selects a bus stop, bus line, and time of day, then taps
/// "Predict Delay" to see the predicted delay. This screen is designed
/// to be reachable within 2 taps from the home screen for usability.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../providers/prediction_provider.dart';
import '../widgets/map_bus_stop_picker.dart';
import 'prediction_result_screen.dart';

class PredictionScreen extends ConsumerStatefulWidget {
  const PredictionScreen({super.key});

  @override
  ConsumerState<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends ConsumerState<PredictionScreen> {
  final _timeController = TextEditingController();
  final _lineController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load stops on first build
    Future.microtask(
      () => ref.read(predictionProvider.notifier).loadStops(),
    );
  }

  @override
  void dispose() {
    _timeController.dispose();
    _lineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(predictionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prediction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────
            Text(
              'Check Bus Delay',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Select your route and time to see predicted delays',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // ── Bus Stop Picker (Interactive Map) ──────────────────
            Text('Bus Stop', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            MapBusStopPicker(
              stops: state.stops,
              selectedStop: state.selectedStop,
              onStopSelected: (stop) {
                ref.read(predictionProvider.notifier).selectStop(stop);
              },
            ),
            const SizedBox(height: 20),

            // ── Bus Line (dropdown with text fallback) ──────────────
            Text('Bus Line', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return kCommonBusLines;
                }
                return kCommonBusLines.where((line) =>
                    line.contains(textEditingValue.text));
              },
              onSelected: (line) {
                _lineController.text = line;
                ref.read(predictionProvider.notifier).selectBusLine(line);
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.route),
                    hintText: 'e.g. 28, 1, 8',
                  ),
                  keyboardType: TextInputType.text,
                  onChanged: (value) {
                    ref
                        .read(predictionProvider.notifier)
                        .selectBusLine(value);
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Time Picker ─────────────────────────────────────────
            Text('Time of Day', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _timeController,
              readOnly: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.access_time),
                hintText: 'Tap to select time',
              ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(now),
                );
                if (picked != null) {
                  final timeStr =
                      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                  _timeController.text = timeStr;
                  ref
                      .read(predictionProvider.notifier)
                      .selectTime(timeStr);
                }
              },
            ),
            const SizedBox(height: 32),

            // ── Predict Button ──────────────────────────────────────
            ElevatedButton(
              onPressed: state.selectedStop != null &&
                      state.selectedBusLine != null &&
                      state.selectedTime != null &&
                      !state.isLoading
                  ? () => ref
                      .read(predictionProvider.notifier)
                      .fetchPrediction()
                  : null,
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Predict Delay'),
            ),
            const SizedBox(height: 16),

            // ── Error Display ───────────────────────────────────────
            if (state.error != null)
              Card(
                color: kDelayRed.withAlpha(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: kDelayRed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.error!.userMessage,
                          style: const TextStyle(color: kDelayRed),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Result Navigation ───────────────────────────────────
            if (state.result != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PredictionResultScreen(
                        prediction: state.result!,
                      ),
                    ),
                  );
                },
                child: const Text('View Detailed Prediction'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
