import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/font_scale_provider.dart';
import '../widgets/desk_page.dart';
import '../theme/desk_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(fontScaleProvider);

    return DeskPage(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
              'Adjust the application display settings',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: DeskColors.muted),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.format_size, size: 20),
                        const SizedBox(width: 10),
                        Text('Font size',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: DeskColors.primaryTint,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${(scale * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: DeskColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('A', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: scale,
                            min: FontScaleNotifier.min,
                            max: FontScaleNotifier.max,
                            divisions: 6,
                            label: '${(scale * 100).round()}%',
                            onChanged: (val) => ref
                                .read(fontScaleProvider.notifier)
                                .setScale(val),
                          ),
                        ),
                        const Text('A', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adjust the text size across the application. Changes apply immediately.',
                      style: TextStyle(color: DeskColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(fontScaleProvider.notifier)
                          .setScale(1.0),
                      child: const Text('Reset to default'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
