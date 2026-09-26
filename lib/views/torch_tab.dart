import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/power_button.dart';
import 'home.dart';

class TorchTab extends StatelessWidget {
  const TorchTab({super.key, required this.services, required this.onOpenScreenLight});
  final AppServices services;
  final VoidCallback onOpenScreenLight;

  @override
  Widget build(BuildContext context) {
    final torch = services.torch;
    return ListenableBuilder(
      listenable: torch,
      builder: (context, _) {
        final info = torch.info;
        final lit = torch.isOn && !torch.patternRunning;
        final label = !info.hasFlash && torch.ready
            ? 'NO FLASH'
            : torch.patternRunning
            ? 'SIGNAL'
            : lit
            ? 'ON'
            : 'OFF';
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            TabHeader(
              title: 'Beam',
              subtitle: 'Torch',
              trailing: StatusPill(
                key: const Key('torch-status'),
                label: label,
                active: torch.isOn || torch.patternRunning,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: PowerButton(
                key: const Key('power'),
                on: lit,
                enabled: info.hasFlash,
                glow: info.supportsStrength ? torch.strength / info.maxStrength : 1,
                onPressed: torch.toggle,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                info.hasFlash ? (lit ? 'Tap to turn off' : 'Tap to turn on') : 'This phone has no flash',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _IntensityCard(services: services),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: ListTile(
                  key: const Key('open-screen-light'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  leading: const Icon(Icons.smartphone, color: beamAmber),
                  title: const Text('Need a softer or coloured light?'),
                  subtitle: const Text('Use the screen as a lamp'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenScreenLight,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IntensityCard extends StatelessWidget {
  const _IntensityCard({required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final torch = services.torch;
    final info = torch.info;
    final supported = info.supportsStrength;
    final pct = supported ? (torch.strength / info.maxStrength * 100).round() : 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, size: 20, color: beamAmber),
                const SizedBox(width: 10),
                const Text('Intensity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                Text(
                  supported ? '$pct%' : 'Fixed',
                  key: const Key('intensity-value'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            if (supported)
              Slider(
                key: const Key('intensity-slider'),
                value: torch.strength.toDouble(),
                min: 1,
                max: info.maxStrength.toDouble(),
                divisions: info.maxStrength - 1,
                label: '$pct%',
                onChanged: (v) => torch.setStrength(v.round()),
                onChangeEnd: (v) => services.settings.torchStrength = v.round(),
              )
            else if (info.hasFlash)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'This flash has one brightness level (dimming needs Android 13+). '
                  'For a softer light, use the screen light below.',
                  key: Key('intensity-unsupported'),
                  style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.35),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
