import 'dart:async';

import 'package:flutter/material.dart';

import '../models/address_suggestion.dart';
import '../services/location_service.dart';

class AddressResult {
  final String address;
  final double? lat;
  final double? lng;

  const AddressResult({required this.address, this.lat, this.lng});
}

class AddressField extends StatefulWidget {
  final String label;
  final String? initialValue;
  final ValueChanged<AddressResult> onChanged;
  final bool showCurrentLocationButton;

  const AddressField({
    super.key,
    required this.label,
    this.initialValue,
    required this.onChanged,
    this.showCurrentLocationButton = true,
  });

  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  late final TextEditingController _controller;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final LocationService _locationService = LocationService();

  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  List<AddressSuggestion> _suggestions = [];
  bool _isLoadingLocation = false;
  bool _suppressSearch = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
      final text = _controller.text.trim();
      if (text.isNotEmpty) {
        widget.onChanged(AddressResult(address: text));
      }
    }
  }

  void _onTextChanged(String value) {
    if (_suppressSearch) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchAddress(value);
    });
  }

  Future<void> _searchAddress(String query) async {
    if (query.length < 3) {
      _removeOverlay();
      setState(() => _suggestions = []);
      return;
    }

    final results = await _locationService.searchAddress(query);
    if (!mounted) return;

    setState(() => _suggestions = results);
    if (results.isNotEmpty) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    _suppressSearch = true;
    _controller.text = suggestion.displayName;
    _suppressSearch = false;
    _removeOverlay();
    setState(() => _suggestions = []);
    widget.onChanged(AddressResult(
      address: suggestion.displayName,
      lat: suggestion.lat,
      lng: suggestion.lng,
    ));
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      final address =
          await _locationService.reverseGeocode(position.lat, position.lng);
      if (!mounted) return;

      _suppressSearch = true;
      _controller.text = address;
      _suppressSearch = false;

      widget.onChanged(AddressResult(
        address: address,
        lat: position.lat,
        lng: position.lng,
      ));
    } catch (_) {
      if (!mounted) return;
      _controller.clear();
      _controller.value = _controller.value.copyWith(
        composing: TextRange.empty,
      );
      // Show hint by rebuilding with error state handled via decoration
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location unavailable'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  OverlayEntry _buildOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final width = renderBox.size.width;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, renderBox.size.height + 4),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a1a),
                border: Border.all(color: const Color(0xFF333333)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount:
                    _suggestions.length > 5 ? 5 : _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return _SuggestionTile(
                    suggestion: suggestion,
                    onTap: () => _selectSuggestion(suggestion),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (!widget.showCurrentLocationButton) return null;

    if (_isLoadingLocation) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF6366f1),
          ),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.my_location, color: Color(0xFF6366f1)),
      onPressed: _useCurrentLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF6b7280),
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onTextChanged,
            style: const TextStyle(color: Color(0xFFe2e8f0)),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF111111),
              hintText: 'Start typing an address...',
              hintStyle: const TextStyle(color: Color(0xFF6b7280)),
              suffixIcon: _buildSuffixIcon(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF6366f1)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatefulWidget {
  final AddressSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.suggestion,
    required this.onTap,
  });

  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: _isHovered ? const Color(0xFF222222) : Colors.transparent,
          child: Text(
            widget.suggestion.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9ca3af),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
