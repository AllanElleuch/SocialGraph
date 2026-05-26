import 'package:flutter/material.dart';
import 'models/contact.dart';
import 'services/contact_service.dart';
import 'widgets/graph_view.dart';
import 'widgets/map_view.dart';
import 'widgets/contact_card.dart';
import 'widgets/controls.dart';
import 'widgets/contact_form.dart';
import 'widgets/timeline_view.dart';

void main() {
  runApp(const SocialGraphApp());
}

class SocialGraphApp extends StatelessWidget {
  const SocialGraphApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contextual Contacts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0a0a0a),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ContactService _service = ContactService();
  List<Contact> _contacts = [];
  PivotType _pivot = PivotType.mutual;
  Contact? _selectedContact;
  String _searchQuery = '';
  bool _loading = true;
  bool _showForm = false;
  Contact? _editingContact;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      final contacts = await _service.fetchContacts();
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to fetch contacts: $e');
      setState(() => _loading = false);
    }
  }

  void _openAddForm() {
    setState(() {
      _showForm = true;
      _editingContact = null;
      _selectedContact = null;
    });
  }

  void _openEditForm(Contact contact) {
    setState(() {
      _showForm = true;
      _editingContact = contact;
      _selectedContact = null;
    });
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingContact = null;
    });
  }

  Future<void> _onFormSave(Contact contact) async {
    try {
      if (_editingContact != null) {
        await _service.updateContact(contact);
      } else {
        await _service.addContact(contact);
      }
      await _fetchContacts();
    } catch (e) {
      // Offline fallback: update local list directly
      setState(() {
        if (_editingContact != null) {
          final idx = _contacts.indexWhere((c) => c.id == contact.id);
          if (idx >= 0) {
            _contacts = [..._contacts]..[idx] = contact;
          }
        } else {
          _contacts = [..._contacts, contact];
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved locally (server unavailable)')),
        );
      }
    }
    _closeForm();
  }

  List<Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    final query = _searchQuery.toLowerCase();
    return _contacts.where((c) {
      return c.displayName.toLowerCase().contains(query) ||
          c.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.7,
                colors: [Color(0xFF1e293b), Color(0xFF020617)],
              ),
            ),
          ),

          // Main content area
          if (_loading)
            const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Color(0xFF6366f1),
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_pivot == PivotType.location)
            MapView(
              contacts: _filteredContacts,
              onSelectContact: (c) => setState(() => _selectedContact = c),
            )
          else if (_pivot == PivotType.time)
            TimelineView(
              contacts: _filteredContacts,
              onSelectContact: (c) => setState(() => _selectedContact = c),
            )
          else
            GraphView(
              contacts: _filteredContacts,
              pivot: _pivot,
              onSelectContact: (c) => setState(() => _selectedContact = c),
            ),

          // Header
          _buildHeader(),

          // Controls
          Controls(
            pivot: _pivot,
            onPivotChanged: (p) => setState(() => _pivot = p),
            onAddContact: _openAddForm,
          ),

          // Contact Card
          ContactCard(
            contact: _selectedContact,
            onClose: () => setState(() => _selectedContact = null),
            onEdit: _selectedContact != null ? () => _openEditForm(_selectedContact!) : null,
          ),

          // Contact Form
          if (_showForm)
            Positioned(
              top: 16,
              right: 16,
              bottom: 16,
              width: 380,
              child: ContactForm(
                existingContact: _editingContact,
                allContacts: _contacts,
                onSave: _onFormSave,
                onCancel: _closeForm,
              ),
            ),

          // Legend
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        // Offset by the status bar / notch height so the header never sits
        // under the Dynamic Island.
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: MediaQuery.of(context).padding.top + 12,
          bottom: 24,
        ),
        child: Row(
          children: [
            // Logo
            Flexible(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6366f1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'CONTEXTUAL CONTACTS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'GRAPH-BASED NETWORK EXPLORER',
                    style: TextStyle(
                      color: Color(0xFF6b7280),
                      fontSize: 10,
                      letterSpacing: 3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Search + Info
            Flexible(
              flex: 4,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a1a1a),
                        border: Border.all(color: const Color(0xFF333333)),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(
                            color: Color(0xFFe2e8f0), fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search network...',
                          hintStyle: TextStyle(color: Color(0xFF6b7280)),
                          prefixIcon: Icon(Icons.search,
                              color: Color(0xFF6b7280), size: 16),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.info_outline,
                        color: Color(0xFF6b7280), size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      // Sit above the bottom controls bar (≈52px tall at bottom: 32) so the
      // two never overlap on narrow screens.
      bottom: 104,
      left: 32,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF333333).withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ACTIVE VIEW',
                style: TextStyle(
                  color: Color(0xFF6b7280),
                  fontSize: 10,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_pivot.name[0].toUpperCase()}${_pivot.name.substring(1)} Clustering',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366f1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Contact Node',
                    style: TextStyle(color: Color(0xFF9ca3af), fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 16, height: 1, color: const Color(0xFF4b5563)),
                  const SizedBox(width: 8),
                  const Text(
                    'Relationship',
                    style: TextStyle(color: Color(0xFF9ca3af), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
