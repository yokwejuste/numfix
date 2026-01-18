import 'package:flutter/material.dart';
import '../widgets/cards.dart';

class CountrySelector extends StatelessWidget {
  final String selectedRegion;
  final Map<String, String> countries;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const CountrySelector({
    super.key,
    required this.selectedRegion,
    required this.countries,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CardContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.public,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Region',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedRegion,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: countries.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            '${entry.value} (${entry.key})',
                            style: TextStyle(color: theme.colorScheme.primary),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: enabled ? onChanged : null,
                  dropdownColor: theme.cardColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
