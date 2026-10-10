import 'package:flutter/material.dart';

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  double _bass = 0.5;
  double _mid = 0.5;
  double _treble = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ecualizador de Audio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Ajustes de Ecualización',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            _buildSlider('Graves (Bass)', _bass, (val) => setState(() => _bass = val)),
            const SizedBox(height: 20),
            _buildSlider('Medios (Mids)', _mid, (val) => setState(() => _mid = val)),
            const SizedBox(height: 20),
            _buildSlider('Agudos (Treble)', _treble, (val) => setState(() => _treble = val)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
