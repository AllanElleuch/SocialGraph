import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contact.dart';
import 'tag_input.dart';
import 'address_field.dart';

class ContactForm extends StatefulWidget {
  final Contact? existingContact;
  final List<Contact> allContacts;
  final ValueChanged<Contact> onSave;
  final VoidCallback onCancel;

  const ContactForm({
    super.key,
    this.existingContact,
    required this.allContacts,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _workplaceController;

  late List<String> _tags;
  String? _locationMet;
  double? _locationLat;
  double? _locationLng;
  String? _homeAddress;
  late DateTime _dateMet;
  late Set<String> _selectedConnections;

  bool get _isEditMode => widget.existingContact != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingContact;
    _firstNameController = TextEditingController(text: c?.firstName ?? '');
    _lastNameController = TextEditingController(text: c?.lastName ?? '');
    _workplaceController = TextEditingController(text: c?.workplace ?? '');
    _tags = List<String>.from(c?.tags ?? []);
    _locationMet = c?.locationMet;
    _locationLat = c?.lat;
    _locationLng = c?.lng;
    _homeAddress = c?.homeAddress;
    _dateMet = c?.dateMet ?? DateTime.now();
    _selectedConnections = Set<String>.from(c?.connections ?? []);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _workplaceController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final contact = Contact(
      id: widget.existingContact?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      tags: _tags,
      locationMet: _locationMet ?? '',
      lat: _locationLat,
      lng: _locationLng,
      dateMet: _dateMet,
      connections: _selectedConnections.toList(),
      lastInteraction: widget.existingContact?.lastInteraction,
      workplace: _workplaceController.text.trim(),
      homeAddress: _homeAddress ?? '',
    );
    widget.onSave(contact);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateMet,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme:
              const ColorScheme.dark(primary: Color(0xFF6366f1)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateMet = picked);
    }
  }

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF111111),
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF6b7280)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF43F5E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF43F5E)),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6b7280),
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 380,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a1a),
          border: Border.all(color: const Color(0xFF333333)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditMode ? 'EDIT CONTACT' : 'ADD CONTACT',
                      style: const TextStyle(
                        color: Color(0xFF6b7280),
                        fontSize: 10,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    InkWell(
                      onTap: widget.onCancel,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.close,
                            color: Color(0xFF9ca3af), size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // First Name
                _fieldLabel('First Name'),
                TextFormField(
                  controller: _firstNameController,
                  style: const TextStyle(color: Color(0xFFe2e8f0)),
                  decoration: _fieldDecoration(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'First name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Last Name
                _fieldLabel('Last Name'),
                TextFormField(
                  controller: _lastNameController,
                  style: const TextStyle(color: Color(0xFFe2e8f0)),
                  decoration: _fieldDecoration(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Last name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Tags
                _fieldLabel('Tags'),
                TagInput(
                  initialTags: widget.existingContact?.tags ?? [],
                  onTagsChanged: (tags) => _tags = tags,
                ),
                const SizedBox(height: 16),

                // Location Met
                AddressField(
                  label: 'Location Met',
                  showCurrentLocationButton: true,
                  initialValue: widget.existingContact?.locationMet,
                  onChanged: (result) {
                    _locationMet = result.address;
                    _locationLat = result.lat;
                    _locationLng = result.lng;
                  },
                ),
                const SizedBox(height: 16),

                // Workplace
                _fieldLabel('Workplace'),
                TextFormField(
                  controller: _workplaceController,
                  style: const TextStyle(color: Color(0xFFe2e8f0)),
                  decoration: _fieldDecoration(),
                ),
                const SizedBox(height: 16),

                // Home Address
                AddressField(
                  label: 'Home Address',
                  showCurrentLocationButton: false,
                  initialValue: widget.existingContact?.homeAddress,
                  onChanged: (result) {
                    _homeAddress = result.address;
                  },
                ),
                const SizedBox(height: 16),

                // Date Met
                _fieldLabel('Date Met'),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      border:
                          Border.all(color: const Color(0xFF333333)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat.yMMMd().format(_dateMet),
                      style:
                          const TextStyle(color: Color(0xFFe2e8f0)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Connections
                _fieldLabel('Connections'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.allContacts
                      .where((c) =>
                          !_isEditMode ||
                          c.id != widget.existingContact!.id)
                      .map((c) {
                    final isSelected =
                        _selectedConnections.contains(c.id);
                    return FilterChip(
                      label: Text(c.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedConnections.add(c.id);
                          } else {
                            _selectedConnections.remove(c.id);
                          }
                        });
                      },
                      backgroundColor: const Color(0xFF111111),
                      selectedColor: const Color(0xFF6366f1)
                          .withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF6366f1),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFF6366f1)
                            : const Color(0xFF9ca3af),
                      ),
                      side: const BorderSide(
                          color: Color(0xFF333333)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Footer buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF333333)),
                          foregroundColor: const Color(0xFF9ca3af),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4f46e5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
