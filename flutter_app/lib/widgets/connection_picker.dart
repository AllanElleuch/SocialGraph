import 'package:flutter/material.dart';

import '../models/contact.dart';

/// Picks connections by typing a name instead of rendering one chip per
/// contact. Scales to thousands of contacts: the candidate list is only ever
/// materialized as a short, filtered dropdown, and the body shows just the
/// handful of currently-selected connections as removable chips.
class ConnectionPicker extends StatefulWidget {
  /// Candidate contacts to connect to (caller should already exclude self).
  final List<Contact> candidates;

  /// Ids selected when the picker opens.
  final Set<String> initialSelectedIds;

  /// Fired whenever the selection changes, with the full set of selected ids.
  final ValueChanged<Set<String>> onChanged;

  /// Cap on the number of dropdown suggestions shown at once.
  final int maxSuggestions;

  const ConnectionPicker({
    super.key,
    required this.candidates,
    required this.initialSelectedIds,
    required this.onChanged,
    this.maxSuggestions = 30,
  });

  @override
  State<ConnectionPicker> createState() => _ConnectionPickerState();
}

class _ConnectionPickerState extends State<ConnectionPicker> {
  late final Set<String> _selected;
  late final Map<String, Contact> _byId;
  TextEditingController? _fieldController;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelectedIds);
    _byId = {for (final c in widget.candidates) c.id: c};
  }

  void _add(Contact c) {
    if (_selected.add(c.id)) {
      widget.onChanged(_selected);
    }
    _fieldController?.clear();
    setState(() {});
  }

  void _remove(String id) {
    if (_selected.remove(id)) {
      widget.onChanged(_selected);
      setState(() {});
    }
  }

  Iterable<Contact> _suggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const Iterable<Contact>.empty();
    final matches = <Contact>[];
    for (final c in widget.candidates) {
      if (_selected.contains(c.id)) continue;
      if (c.displayName.toLowerCase().contains(q) ||
          c.workplace.toLowerCase().contains(q)) {
        matches.add(c);
        if (matches.length >= widget.maxSuggestions) break;
      }
    }
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    // The selected connections that we can resolve to a contact. Unknown ids
    // (e.g. a since-deleted contact) are kept in [_selected] but not shown.
    final selectedContacts = _selected
        .map((id) => _byId[id])
        .whereType<Contact>()
        .toList()
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<Contact>(
              displayStringForOption: (c) => c.displayName,
              optionsBuilder: (value) => _suggestions(value.text),
              onSelected: _add,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                _fieldController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(color: Color(0xFFe2e8f0)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF111111),
                    hintText: 'Search contacts by name…',
                    hintStyle: const TextStyle(color: Color(0xFF6b7280)),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF6b7280), size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    border: _border(),
                    enabledBorder: _border(),
                    focusedBorder: _border(),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: const Color(0xFF111111),
                    elevation: 6,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 240,
                        maxWidth: fieldWidth,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final c = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(c),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.displayName,
                                    style: const TextStyle(
                                        color: Color(0xFFe2e8f0), fontSize: 14),
                                  ),
                                  if (c.workplace.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        c.workplace,
                                        style: const TextStyle(
                                            color: Color(0xFF6b7280),
                                            fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            if (selectedContacts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No connections yet — search above to add some.',
                  style: TextStyle(color: Color(0xFF4b5563), fontSize: 12),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in selectedContacts) _selectedChip(c),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _selectedChip(Contact c) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6366f1).withValues(alpha: 0.15),
        border: Border.all(color: const Color(0xFF6366f1).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              c.displayName,
              style: const TextStyle(color: Color(0xFF818cf8), fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _remove(c.id),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, color: Color(0xFF818cf8), size: 14),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      );
}
