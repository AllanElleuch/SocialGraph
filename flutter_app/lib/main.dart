import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'models/contact.dart';
import 'services/contact_service.dart';
import 'services/contacts_import_service.dart';
import 'services/contact_repository.dart';
import 'services/contact_search.dart';
import 'services/interaction_log.dart';
import 'services/duplicate_detector.dart';
import 'services/contact_merge.dart';
import 'services/backup_service.dart';
import 'services/reach_out_service.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/notification_service.dart';
import 'services/firebase_bootstrap.dart';
import 'widgets/graph_view.dart';
import 'widgets/map_view.dart';
import 'widgets/contact_card.dart';
import 'widgets/controls.dart';
import 'widgets/contact_form.dart';
import 'widgets/timeline_view.dart';
import 'widgets/merge_review_sheet.dart';
import 'widgets/needs_attention_view.dart';
import 'widgets/sign_in_screen.dart';

/// Whether Firebase initialized successfully. When false the app runs fully
/// offline-first with no auth/cloud features (e.g. config files absent, tests).
bool firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  firebaseReady = await initFirebaseSafely();
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
  final ContactsImportService _importService = ContactsImportService();
  final ContactRepository _repository = ContactRepository();
  final AuthService _auth = AuthService();
  final CloudSyncService _cloud = CloudSyncService();
  final NotificationService _notifications = NotificationService();
  List<Contact> _contacts = [];

  bool get _cloudEnabled => firebaseReady;
  bool get _signedIn => _cloudEnabled && _auth.isSignedIn;
  PivotType _pivot = PivotType.mutual;
  Contact? _selectedContact;
  String _searchQuery = '';
  bool _loading = true;
  bool _importing = false;
  bool _showForm = false;
  Contact? _editingContact;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  /// Local-first load: render the cached list immediately, then refresh from
  /// the server in the background and reconcile + persist.
  Future<void> _loadContacts() async {
    final cached = await _repository.load();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _contacts = cached;
        _loading = false;
      });
    }
    await _refreshFromServer(local: cached);
    await _syncWithCloud();
    await _notifyOverdue();
  }

  /// Reconciles the local list with the signed-in user's cloud copy
  /// (last-write-wins by updatedAt) and persists the result. No-op when cloud
  /// is disabled or the user is not signed in.
  Future<void> _syncWithCloud() async {
    if (!_signedIn) return;
    try {
      final uid = _auth.currentUser!.uid;
      final synced = await _cloud.sync(uid, _contacts);
      if (mounted) setState(() => _contacts = synced);
      await _repository.save(_contacts);
    } catch (e) {
      debugPrint('Cloud sync failed: $e');
    }
  }

  /// Surfaces a single local notification summarizing overdue reach-outs.
  Future<void> _notifyOverdue() async {
    try {
      await _notifications.init();
      final overdue = overdueContacts(_contacts, now: DateTime.now());
      await _notifications.showOverdueSummary(overdue.length);
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }
  }

  Future<void> _refreshFromServer({List<Contact>? local}) async {
    final localList = local ?? _contacts;
    try {
      final server = await _service.fetchContacts();
      final merged = _reconcile(local: localList, server: server);
      if (mounted) {
        setState(() {
          _contacts = merged;
          _loading = false;
        });
      }
      await _repository.save(merged);
    } catch (e) {
      debugPrint('Failed to fetch contacts: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Last-write-wins reconciliation (U4.3): the server is authoritative for
  /// shared ids; locally-added contacts not yet known to the server are kept.
  List<Contact> _reconcile({
    required List<Contact> local,
    required List<Contact> server,
  }) {
    final serverIds = server.map((c) => c.id).toSet();
    final localOnly = local.where((c) => !serverIds.contains(c.id));
    return [...server, ...localOnly];
  }

  Future<void> _persist() async {
    await _repository.save(_contacts);
    if (_signedIn) {
      unawaited(_cloud.push(_auth.currentUser!.uid, _contacts).catchError(
        (Object e) => debugPrint('Cloud push failed: $e'),
      ));
    }
  }

  Future<void> _openSignIn() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreen(
          auth: _auth,
          onSignedIn: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (mounted) setState(() {});
    await _syncWithCloud();
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) {
      setState(() {});
      _showSnack('Signed out');
    }
  }

  /// Applies a logged interaction to the selected contact, persists, and
  /// best-effort syncs to the server.
  void _onLogInteraction(InteractionEvent event) {
    final c = _selectedContact;
    if (c == null) return;
    final updated = c.logInteraction(event);
    setState(() {
      final idx = _contacts.indexWhere((x) => x.id == updated.id);
      if (idx >= 0) _contacts = [..._contacts]..[idx] = updated;
      _selectedContact = updated;
    });
    unawaited(_service.updateContact(updated).catchError((_) => updated));
    unawaited(_persist());
  }

  /// Applies a merge: drops merged-away ids, upserts the merged contact, and
  /// repoints any connections that referenced the removed contacts.
  void _applyMerge(Contact merged, List<String> mergedAwayIds) {
    setState(() {
      var list =
          _contacts.where((c) => !mergedAwayIds.contains(c.id)).toList();
      final idx = list.indexWhere((c) => c.id == merged.id);
      if (idx >= 0) {
        list[idx] = merged;
      } else {
        list = [...list, merged];
      }
      _contacts = rewriteConnections(list, merged.id, mergedAwayIds.toSet());
      if (_selectedContact != null &&
          mergedAwayIds.contains(_selectedContact!.id)) {
        _selectedContact = merged;
      }
    });
    unawaited(_persist());
    unawaited(_service.updateContact(merged).catchError((_) => merged));
    for (final id in mergedAwayIds) {
      unawaited(_service.deleteContact(id).catchError((_) {}));
    }
  }

  void _reviewDuplicates() {
    final groups = findDuplicateGroups(_contacts);
    if (groups.isEmpty) {
      _showSnack('No duplicates found');
      return;
    }
    MergeReviewSheet.show(
      context,
      groups: groups,
      onMergeGroup: _applyMerge,
    );
  }

  void _openNeedsAttention() {
    NeedsAttentionView.show(
      context,
      contacts: _contacts,
      now: DateTime.now(),
      onSelect: (c) => setState(() => _selectedContact = c),
    );
  }

  void _exportBackup() {
    final json = BackupService().exportJson(_contacts);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text('Backup — copy this JSON',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: SelectableText(
            json,
            style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _importBackup() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text('Import backup',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLines: 8,
            style: const TextStyle(color: Color(0xFFe2e8f0), fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Paste backup JSON here…',
              hintStyle: TextStyle(color: Color(0xFF6b7280)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              try {
                final merged =
                    BackupService().importMerged(_contacts, controller.text);
                setState(() => _contacts = merged);
                unawaited(_persist());
                Navigator.of(ctx).pop();
                _showSnack('Imported ${merged.length} contacts');
              } catch (e) {
                _showSnack('Invalid backup: $e');
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
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
      await _refreshFromServer();
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
      unawaited(_persist());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved locally (server unavailable)')),
        );
      }
    }
    _closeForm();
  }

  Future<void> _importFromPhone() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final result = await _importService.importFromDevice();
      if (!mounted) return;

      if (result.status == ImportStatus.denied) {
        _showSnack('Contacts permission denied');
        return;
      }
      if (result.status == ImportStatus.permanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enable contacts access in Settings to import'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: _importService.openSettings,
            ),
          ),
        );
        return;
      }

      // Skip contacts already present (matched by display name).
      final existingNames =
          _contacts.map((c) => c.displayName.toLowerCase()).toSet();
      final toAdd = result.contacts
          .where((c) => !existingNames.contains(c.displayName.toLowerCase()))
          .toList();

      if (toAdd.isEmpty) {
        _showSnack('No new contacts to import');
        return;
      }

      // Persist to the backend; fall back to local state if it is unreachable.
      var serverOk = true;
      final localAdds = <Contact>[];
      var added = 0;
      for (final contact in toAdd) {
        if (serverOk) {
          try {
            await _service.addContact(contact);
            added++;
            continue;
          } catch (_) {
            serverOk = false;
          }
        }
        localAdds.add(contact);
        added++;
      }

      if (serverOk) {
        await _refreshFromServer();
      } else {
        setState(() => _contacts = [..._contacts, ...localAdds]);
        unawaited(_persist());
      }

      if (!mounted) return;
      _showSnack('Imported $added contact${added == 1 ? '' : 's'}');

      // Offer to merge any duplicates the import may have introduced.
      final groups = findDuplicateGroups(_contacts);
      if (groups.isNotEmpty && mounted) {
        MergeReviewSheet.show(
          context,
          groups: groups,
          onMergeGroup: _applyMerge,
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<Contact> get _filteredContacts {
    if (_searchQuery.trim().isEmpty) return _contacts;
    return _contacts
        .where((c) => contactMatchesQuery(c, _searchQuery))
        .toList();
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

          // Legend — annotates the active view, so it sits just above the
          // view content but BEHIND the header, controls, card, and form.
          _buildLegend(),

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
            onEdit: _selectedContact != null
                ? () => _openEditForm(_selectedContact!)
                : null,
            onLogInteraction: _onLogInteraction,
          ),

          // Contact Form — responsive width so the panel always fits the
          // screen (full-width minus margins on phones, capped at 380 on wide
          // layouts).
          if (_showForm)
            Positioned(
              top: 16,
              right: 16,
              bottom: 16,
              width: math.min(
                380.0,
                MediaQuery.of(context).size.width - 32,
              ),
              child: ContactForm(
                existingContact: _editingContact,
                allContacts: _contacts,
                onSave: _onFormSave,
                onCancel: _closeForm,
              ),
            ),
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
                  if (!kIsWeb)
                    IconButton(
                      onPressed: _importing ? null : _importFromPhone,
                      tooltip: 'Import phone contacts',
                      icon: _importing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF6366f1),
                              ),
                            )
                          : const Icon(Icons.contact_phone_outlined,
                              color: Color(0xFF6b7280), size: 20),
                    ),
                  IconButton(
                    onPressed: _showInfo,
                    tooltip: 'About this view',
                    icon: const Icon(Icons.info_outline,
                        color: Color(0xFF6b7280), size: 20),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    color: const Color(0xFF1a1a1a),
                    icon: const Icon(Icons.more_vert,
                        color: Color(0xFF6b7280), size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'attention':
                          _openNeedsAttention();
                        case 'duplicates':
                          _reviewDuplicates();
                        case 'export':
                          _exportBackup();
                        case 'import':
                          _importBackup();
                        case 'signin':
                          _openSignIn();
                        case 'signout':
                          _signOut();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'attention',
                        child: Text('Needs attention',
                            style: TextStyle(color: Color(0xFFe2e8f0))),
                      ),
                      const PopupMenuItem(
                        value: 'duplicates',
                        child: Text('Review duplicates',
                            style: TextStyle(color: Color(0xFFe2e8f0))),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Text('Export backup',
                            style: TextStyle(color: Color(0xFFe2e8f0))),
                      ),
                      const PopupMenuItem(
                        value: 'import',
                        child: Text('Import backup',
                            style: TextStyle(color: Color(0xFFe2e8f0))),
                      ),
                      if (_cloudEnabled)
                        PopupMenuItem(
                          value: _signedIn ? 'signout' : 'signin',
                          child: Text(
                            _signedIn ? 'Sign out' : 'Sign in to sync',
                            style: const TextStyle(color: Color(0xFF818cf8)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo() {
    const views = [
      (
        PivotType.mutual,
        Icons.people,
        'Mutuals',
        'Cluster contacts by their shared connections to reveal your network.',
      ),
      (
        PivotType.location,
        Icons.map_outlined,
        'Location',
        'Place contacts on a map by where you met them and where they live.',
      ),
      (
        PivotType.time,
        Icons.schedule,
        'Timeline',
        'Order contacts chronologically by the date you first met.',
      ),
    ];

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Contextual Contacts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        color: Color(0xFF9ca3af), size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Switch views from the bottom bar to explore your network in different ways.',
                style: TextStyle(color: Color(0xFF9ca3af), fontSize: 13),
              ),
              const SizedBox(height: 20),
              for (final (pivot, icon, title, desc) in views)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: _pivot == pivot
                            ? const Color(0xFF6366f1)
                            : const Color(0xFF6b7280),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: _pivot == pivot
                                    ? Colors.white
                                    : const Color(0xFFe2e8f0),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: const TextStyle(
                                color: Color(0xFF6b7280),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
