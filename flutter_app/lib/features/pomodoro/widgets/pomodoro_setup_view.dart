import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Minimalist schematic-style setup view with three vertically aligned configuration
/// modules (Work Duration, Break Time, Cycles) laid out symmetrically. Implements
/// the precise layout + spacing spec: input/label ordering creates an inverted arch
/// with the middle (Break) module label on top and input at bottom.
class PomodoroSetupView extends StatelessWidget {
  final TextEditingController focusController;
  final TextEditingController breakController;
  final TextEditingController cyclesController;
  final Function(String) onFocusChanged;
  final Function(String) onBreakChanged;

  const PomodoroSetupView({
    required this.focusController,
    required this.breakController,
    required this.cyclesController,
    required this.onFocusChanged,
    required this.onBreakChanged,
    super.key,
  });

  static const double _moduleWidth = 88.0;
  static const double _connectorHeight =
      130.0; // Further increased from 80.0 for better vertical fill
  static const double _gap = 16.0; // Increased from 12.0

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ConfigModule(
          label: 'Work Duration',
          controller: focusController,
          onChanged: onFocusChanged,
          placeInputOnTop: true,
          width: _moduleWidth,
          connectorHeight: _connectorHeight,
          gap: _gap,
        ),
        _ConfigModule(
          label: 'Break Time',
          controller: breakController,
          onChanged: onBreakChanged,
          placeInputOnTop: false, // inverted middle module
          width: _moduleWidth,
          connectorHeight: _connectorHeight,
          gap: _gap,
        ),
        _ConfigModule(
          label: 'Cycles',
          controller: cyclesController,
          onChanged: null, // derived value, read-only
          readOnly: true,
          placeInputOnTop: true,
          width: _moduleWidth,
          connectorHeight: _connectorHeight,
          gap: _gap,
        ),
      ],
    );
  }
}

class _ConfigModule extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Function(String)? onChanged;
  final bool readOnly;
  final bool placeInputOnTop;
  final double width;
  final double connectorHeight;
  final double gap;

  const _ConfigModule({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.placeInputOnTop,
    required this.width,
    required this.connectorHeight,
    required this.gap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> topSequence = [
      _NumberInput(
        controller: controller,
        readOnly: readOnly,
        onChanged: onChanged,
        width: width,
      ),
      SizedBox(height: gap),
      _ConnectorLine(height: connectorHeight),
      SizedBox(height: gap),
      _Label(text: label),
    ];
    final List<Widget> bottomSequence = [
      _Label(text: label),
      SizedBox(height: gap),
      _ConnectorLine(height: connectorHeight),
      SizedBox(height: gap),
      _NumberInput(
        controller: controller,
        readOnly: readOnly,
        onChanged: onChanged,
        width: width,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: placeInputOnTop ? topSequence : bottomSequence,
    );
  }
}

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final Function(String)? onChanged;
  final double width;

  const _NumberInput({
    required this.controller,
    required this.readOnly,
    required this.onChanged,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.grey.shade700, width: 1.0),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 18.0, color: Colors.white),
        decoration: const InputDecoration(border: InputBorder.none),
        readOnly: readOnly,
        onChanged: onChanged,
      ),
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  final double height;
  const _ConnectorLine({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(width: 2, height: height, color: AppColors.brightYellow);
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.0,
        color: AppColors.brightYellow,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
