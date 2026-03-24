import 'package:flutter/material.dart';
import 'models/contact.dart';
import 'services/contact_service.dart';
import 'widgets/graph_view.dart';
import 'widgets/map_view.dart';
import 'widgets/contact_card.dart';
import 'widgets/controls.dart';

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

  List<Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    final query = _searchQuery.toLowerCase();
    return _contacts.where((c) {
      return c.name.toLowerCase().contains(query) ||
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
            onAddContact: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Add contact functionality coming soon!')),
              );
            },
          ),

          // Contact Card
          ContactCard(
            contact: _selectedContact,
            onClose: () => setState(() => _selectedContact = null),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo
            Column(
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
                    const Text(
                      'CONTEXTUAL CONTACTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
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
                ),
              ],
            ),

            // Search + Info
            Row(
              children: [
                Container(
                  width: 256,
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
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.info_outline,
                      color: Color(0xFF6b7280), size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      bottom: 32,
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
