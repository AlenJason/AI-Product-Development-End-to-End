import 'package:flutter/material.dart';

import '../models/restriction_options.dart';
import '../models/profile_rules.dart';
import '../providers/onboarding_provider.dart';

class RestrictionFields extends StatelessWidget {
  const RestrictionFields({
    super.key,
    required this.form,
    required this.kind,
    required this.controller,
  });
  final OnboardingProvider form;
  final RestrictionKind kind;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    final selection = form.selection(kind);
    final error = form.restrictionError(kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: Key('restriction-${kind.name}'),
              title: Text(kind.toggleLabel),
              value: selection.enabled,
              onChanged: (value) => form.enableRestriction(kind, value),
            ),
            if (selection.enabled)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in kind.options)
                          FilterChip(
                            label: Text(option.label),
                            tooltip: option.hint,
                            selected: selection.chosen.contains(option.label),
                            onSelected: (selected) => form.chooseRestriction(
                              kind,
                              option.label,
                              selected,
                            ),
                          ),
                      ],
                    ),
                    CheckboxListTile(
                      key: Key('other-toggle-${kind.name}'),
                      title: const Text('Khác'),
                      value: form.otherEnabled(kind),
                      onChanged: (value) =>
                          form.enableOther(kind, value ?? false),
                    ),
                    if (form.otherEnabled(kind))
                      TextField(
                        key: Key('other-input-${kind.name}'),
                        controller: controller,
                        maxLines: null,
                        onChanged: (value) => form.updateOther(kind, value),
                        decoration: InputDecoration(
                          labelText: kind.title,
                          hintText: kind.otherHint,
                        ),
                      ),
                    Text(
                      '${form.restrictionText(kind).length}/$restrictionMaxLength ký tự',
                      key: Key('counter-${kind.name}'),
                    ),
                    if (error != null)
                      Text(
                        error,
                        key: Key('restriction-error-${kind.name}'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
