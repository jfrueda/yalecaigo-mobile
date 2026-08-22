import 'package:flutter/material.dart';

class ModeSwitchButton extends StatelessWidget {
  const ModeSwitchButton({
    super.key,
    required this.currentMode,
    required this.targetMode,
    required this.onSwitch,
  });

  final String currentMode;
  final String targetMode;
  final VoidCallback onSwitch;

  bool get _providerMode => currentMode.toLowerCase() == 'acompañar';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Cambiar modo de uso',
      onSelected: (_) => onSwitch(),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              Icon(
                _providerMode
                    ? Icons.volunteer_activism_outlined
                    : Icons.person_search_outlined,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Modo actual: $currentMode')),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'switch',
          child: Row(
            children: [
              Icon(
                _providerMode
                    ? Icons.person_search_outlined
                    : Icons.volunteer_activism_outlined,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Cambiar a $targetMode')),
            ],
          ),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _providerMode
                  ? Icons.volunteer_activism_outlined
                  : Icons.person_search_outlined,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              currentMode,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}
