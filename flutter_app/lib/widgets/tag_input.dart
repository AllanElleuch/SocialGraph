import 'package:flutter/material.dart';

/// A tag input widget that creates colored badges.
/// - User types text, presses comma or Enter to create a tag badge
/// - Each badge has a deterministic color from a palette and an X to remove
/// - Duplicates and empty strings are skipped
class TagInput extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onTagsChanged;

  /// Usage count per existing tag across all contacts, used to power
  /// autocomplete suggestions (matches shown with their reference count).
  final Map<String, int> tagCounts;

  const TagInput({
    super.key,
    this.initialTags = const [],
    required this.onTagsChanged,
    this.tagCounts = const {},
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  static const List<Color> _palette = [
    Color(0xFF6366f1), // indigo
    Color(0xFF10b981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFF43F5E), // rose
    Color(0xFF06B6D4), // cyan
    Color(0xFF8B5CF6), // violet
    Color(0xFFF97316), // orange
    Color(0xFF14B8A6), // teal
  ];

  late final List<String> _tags;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _tags = List<String>.from(widget.initialTags);
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorForTag(String tag) {
    return _palette[tag.hashCode.abs() % _palette.length];
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || _tags.contains(tag)) {
      return;
    }
    setState(() {
      _tags.add(tag);
    });
    widget.onTagsChanged(List<String>.unmodifiable(_tags));
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
    widget.onTagsChanged(List<String>.unmodifiable(_tags));
  }

  void _onSubmitted(String value) {
    _addTag(value);
    _controller.clear();
    setState(() {}); // refresh suggestions
  }

  void _onChanged(String value) {
    if (value.contains(',')) {
      final parts = value.split(',');
      for (final part in parts) {
        _addTag(part);
      }
      _controller.clear();
    }
    // Rebuild so the suggestion list reflects the current query.
    setState(() {});
  }

  /// Up to [_maxSuggestions] existing tags matching the current query (case
  /// insensitive), excluding ones already added, ordered by usage desc then
  /// alphabetically. Empty when the field is empty.
  static const int _maxSuggestions = 6;

  List<MapEntry<String, int>> _suggestions() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final matches = widget.tagCounts.entries
        .where((e) =>
            e.key.toLowerCase().contains(query) && !_tags.contains(e.key))
        .toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0
            ? byCount
            : a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    return matches.take(_maxSuggestions).toList();
  }

  void _onSuggestionTap(String tag) {
    _addTag(tag);
    _controller.clear();
    setState(() {}); // collapse the suggestion list
  }

  Widget _buildBadge(String tag) {
    final color = _colorForTag(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: TextStyle(color: color, fontSize: 13),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _removeTag(tag),
            child: Icon(Icons.close, size: 14, color: color.withValues(alpha: 0.60)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(List<MapEntry<String, int>> suggestions) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < suggestions.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: Color(0xFF222222)),
            InkWell(
              onTap: () => _onSuggestionTap(suggestions[i].key),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.label_outline,
                        size: 14, color: Color(0xFF6b7280)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestions[i].key,
                        style: const TextStyle(
                            color: Color(0xFFe2e8f0), fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${suggestions[i].value}',
                      style: const TextStyle(
                          color: Color(0xFF6b7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map(_buildBadge).toList(),
            ),
          ),
        TextField(
          controller: _controller,
          onSubmitted: _onSubmitted,
          onChanged: _onChanged,
          style: const TextStyle(color: Color(0xFFe2e8f0)),
          decoration: InputDecoration(
            hintText: 'Add tag...',
            hintStyle: const TextStyle(color: Color(0xFF6b7280)),
            filled: true,
            fillColor: const Color(0xFF111111),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
          ),
        ),
        if (suggestions.isNotEmpty) _buildSuggestions(suggestions),
      ],
    );
  }
}
