import 'package:flutter/material.dart';
import '../models/card_template.dart';

bool isDesignerHex(String text) =>
    RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(text);
String _hex(Color color, bool alpha) {
  final value = color
      .toARGB32()
      .toRadixString(16)
      .padLeft(8, '0')
      .toUpperCase();
  return '#${alpha ? value : value.substring(2)}';
}

class DesignerColourField extends StatefulWidget {
  const DesignerColourField({
    super.key,
    required this.fieldKey,
    required this.ownerId,
    required this.value,
    required this.decoration,
    required this.onChanged,
    required this.recentColours,
  });
  final Key fieldKey;
  final String? ownerId;
  final String value;
  final InputDecoration decoration;
  final ValueChanged<String> onChanged;
  final List<String> recentColours;
  @override
  State<DesignerColourField> createState() => _DesignerColourFieldState();
}

class _DesignerColourFieldState extends State<DesignerColourField> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant DesignerColourField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value ||
        old.ownerId != widget.ownerId ||
        old.fieldKey != widget.fieldKey) {
      if (_controller.text != widget.value) {
        _controller.value = TextEditingValue(
          text: widget.value,
          selection: TextSelection.collapsed(offset: widget.value.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _ColourDialog(
        value: widget.value,
        recent: List.of(widget.recentColours),
      ),
    );
    if (!mounted || value == null) return;
    _controller.text = value;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    controller: _controller,
    decoration: widget.decoration.copyWith(
      suffixIcon: IconButton(
        key: ValueKey('choose-${(widget.fieldKey as ValueKey).value}'),
        tooltip: 'Choose ${widget.decoration.labelText}',
        onPressed: _choose,
        icon: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: colorFromHex(widget.value, Colors.black),
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    ),
    onChanged: (value) {
      if (isDesignerHex(value)) widget.onChanged(value.toUpperCase());
    },
  );
}

class _ColourDialog extends StatefulWidget {
  const _ColourDialog({required this.value, required this.recent});
  final String value;
  final List<String> recent;
  @override
  State<_ColourDialog> createState() => _ColourDialogState();
}

class _ColourDialogState extends State<_ColourDialog> {
  late HSVColor _hsv;
  late bool _alpha;
  late final TextEditingController _hexInput;
  bool _valid = true;
  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(colorFromHex(widget.value, Colors.black));
    _alpha = widget.value.length == 9;
    _hexInput = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _hexInput.dispose();
    super.dispose();
  }

  void _select(Color color) => _setHsv(HSVColor.fromColor(color));
  void _setHsv(HSVColor value) => setState(() {
    _hsv = value;
    _valid = true;
    _hexInput.text = _hex(value.toColor(), _alpha);
  });
  Widget _swatch(String hex, String prefix) => IconButton(
    key: ValueKey('$prefix-$hex'),
    tooltip: hex,
    onPressed: () {
      _alpha = _alpha || hex.length == 9;
      _select(colorFromHex(hex, Colors.black));
    },
    icon: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: colorFromHex(hex, Colors.black),
        border: Border.all(
          color: _hexInput.text == hex ? Colors.black : Colors.grey,
          width: _hexInput.text == hex ? 3 : 1,
        ),
      ),
    ),
  );
  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> change,
  ) => Row(
    children: [
      SizedBox(width: 85, child: Text(label)),
      Expanded(
        child: Slider(
          key: ValueKey('colour-$label'),
          value: value,
          max: max,
          onChanged: change,
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose colour'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const Key('colour-current'),
              height: 32,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _hsv.toColor(),
                border: Border.all(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.recent.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Recent colours'),
              ),
              Wrap(
                children: [
                  for (final hex in widget.recent) _swatch(hex, 'recent'),
                ],
              ),
            ],
            Wrap(
              children: [
                for (final hex in [
                  '#000000',
                  '#FFFFFF',
                  '#424242',
                  '#9E9E9E',
                  '#EEEEEE',
                ])
                  _swatch(hex, 'palette'),
                for (final hue in [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.cyan,
                  Colors.blue,
                  Colors.indigo,
                  Colors.purple,
                  Colors.pink,
                ])
                  for (final shade in [200, 500, 800])
                    _swatch(_hex(hue[shade]!, false), 'palette'),
              ],
            ),
            _slider('Hue', _hsv.hue, 360, (v) => _setHsv(_hsv.withHue(v))),
            _slider(
              'Saturation',
              _hsv.saturation,
              1,
              (v) => _setHsv(_hsv.withSaturation(v)),
            ),
            _slider(
              'Brightness',
              _hsv.value,
              1,
              (v) => _setHsv(_hsv.withValue(v)),
            ),
            _slider('Opacity', _hsv.alpha, 1, (v) {
              _alpha = true;
              _setHsv(_hsv.withAlpha(v));
            }),
            TextField(
              key: const Key('colour-custom-hex'),
              controller: _hexInput,
              decoration: InputDecoration(
                labelText: 'HEX',
                helperText: 'Use #RRGGBB or #AARRGGBB',
                errorText: _valid ? null : 'Enter a valid HEX colour',
              ),
              onChanged: (value) => setState(() {
                _valid = isDesignerHex(value);
                if (_valid) {
                  _hsv = HSVColor.fromColor(colorFromHex(value, Colors.black));
                  _alpha = value.length == 9;
                }
              }),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('colour-apply'),
        onPressed: _valid
            ? () => Navigator.pop(context, _hexInput.text.toUpperCase())
            : null,
        child: const Text('Apply'),
      ),
    ],
  );
}
