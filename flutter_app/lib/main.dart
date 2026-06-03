import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'models/contact.dart';
import 'services/contacts_import_service.dart';
import 'services/import_dedup.dart';
import 'services/tag_usage.dart';
import 'services/tag_membership.dart';
import 'services/relatives.dart';
import 'services/contact_repository.dart';
import 'services/contact_search.dart';
import 'services/contact_filter.dart';
import 'services/interaction_log.dart';
import 'services/duplicate_detector.dart';
import 'services/contact_merge.dart';
import 'services/backup_service.dart';
import 'services/reach_out_service.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/cloud_backup_service.dart';
import 'services/app_preferences.dart';
import 'painters/star_style.dart';
import 'services/call_log_sync_service.dart';
import 'services/calendar_sync_service.dart';
import 'services/outbound_prompt.dart';
import 'services/notification_service.dart';
import 'services/firebase_bootstrap.dart';
import 'widgets/graph_view.dart';
import 'widgets/map_view.dart';
import 'widgets/contact_card.dart';
import 'widgets/controls.dart';
import 'widgets/contact_form.dart';
import 'widgets/timeline_view.dart';
import 'widgets/stats_view.dart';
import 'widgets/merge_review_sheet.dart';
import 'widgets/needs_attention_view.dart';
import 'widgets/sign_in_screen.dart';
import 'widgets/backup_view.dart';
import 'widgets/settings_view.dart';
import 'widgets/tag_detail_view.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/contacts_list_view.dart';

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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final ContactsImportService _importService = ContactsImportService();
  final ContactRepository _repository = ContactRepository();
  final AuthService _auth = AuthService();
  final CloudSyncService _cloud = CloudSyncService();
  final CloudBackupService _cloudBackup = CloudBackupService();
  final NotificationService _notifications = NotificationService();
  final CallLogSyncService _callLog = CallLogSyncService();
  final CalendarSyncService _calendar = CalendarSyncService();
  final AppPreferences _prefs = AppPreferences();
  List<Contact> _contacts = [];

  /// How contact stars are tinted in the mutuals constellation; loaded from
  /// prefs on startup and changeable in Settings.
  StarColorMode _starColorMode = StarColorMode.temperature;

  bool get _cloudEnabled => firebaseReady;
  bool get _signedIn => _cloudEnabled && _auth.isSignedIn;
  PivotType _pivot = PivotType.mutual;
  Contact? _selectedContact;
  String _searchQuery = '';

  /// Active structured filter (tags / family / quick criteria) applied on top
  /// of the text search. Surfaced via the Mutuals filter button.
  ContactFilter _filter = ContactFilter.none;
  bool _loading = true;
  bool _importing = false;
  bool _showForm = false;
  Contact? _editingContact;

  /// An outbound call/text/email the user just launched from a card, awaiting
  /// confirmation when they return to the app. Null when nothing is pending.
  PendingOutbound? _pendingOutbound;

  /// Whether the app has been backgrounded since [_pendingOutbound] was set —
  /// distinguishes "left for the dialer and came back" from staying in-app.
  bool _wentBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStarColorMode();
    _loadContacts();
  }

  Future<void> _loadStarColorMode() async {
    final mode = await _prefs.loadStarColorMode();
    if (mounted) setState(() => _starColorMode = mode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_pendingOutbound != null) _wentBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      _maybeConfirmOutbound();
    }
  }

  /// On return from an external app (dialer/Mail/Messages), confirm the
  /// optimistically-logged interaction and offer a one-tap "Remove" if it
  /// didn't actually happen.
  void _maybeConfirmOutbound() {
    final pending = _pendingOutbound;
    if (pending == null) return;
    final shouldPrompt = shouldConfirmOnResume(
      pending,
      wentBackground: _wentBackground,
      now: DateTime.now(),
    );
    _pendingOutbound = null;
    _wentBackground = false;
    if (!shouldPrompt || !mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(confirmLabel(pending)),
        action: SnackBarAction(
          label: 'Remove',
          onPressed: () =>
              _removeInteraction(pending.contactId, pending.eventId),
        ),
      ));
  }

  /// Removes a single logged interaction (used to undo an outbound action that
  /// didn't connect). Recomputes [Contact.lastInteraction] from what remains.
  void _removeInteraction(String contactId, String eventId) {
    final idx = _contacts.indexWhere((c) => c.id == contactId);
    if (idx < 0) return;
    final c = _contacts[idx];
    final remaining =
        c.interactions.where((e) => e.id != eventId).toList(growable: false);
    if (remaining.length == c.interactions.length) return; // nothing removed
    DateTime? newLast;
    for (final e in remaining) {
      if (newLast == null || e.date.isAfter(newLast)) newLast = e.date;
    }
    final updated =
        c.copyWith(interactions: remaining, lastInteraction: newLast);
    setState(() {
      _contacts = [..._contacts]..[idx] = updated;
      if (_selectedContact?.id == contactId) _selectedContact = updated;
    });
    unawaited(_persist());
  }

  /// Local-first load: render the cached list immediately, then reconcile with
  /// the signed-in user's cloud copy and persist.
  Future<void> _loadContacts() async {
    final cached = await _repository.load();
    if (mounted) {
      setState(() {
        _contacts = cached;
        _loading = false;
      });
    }
    await _syncCallLog();
    await _syncCalendar();
    await _syncWithCloud();
    await _notifyOverdue();
  }

  /// Folds calls made/received on the device (Android only) into the contact
  /// list as `call` interactions. No-op on platforms without a readable call
  /// log (iOS, macOS, web). Persists locally so the new interactions sync to
  /// the cloud on the subsequent [_syncWithCloud].
  Future<void> _syncCallLog() async {
    if (!_callLog.isSupported) return;
    final updated = await _callLog.sync(_contacts);
    if (!identical(updated, _contacts)) {
      if (mounted) setState(() => _contacts = updated);
      await _repository.save(_contacts);
    }
  }

  /// Folds attended device-calendar meetings (iOS/Android) into the contact
  /// list as `meeting` interactions. No-op on web/macOS. The signed-in user's
  /// own address is excluded so we never log a meeting "with yourself".
  Future<void> _syncCalendar() async {
    if (!_calendar.isSupported) return;
    final selfEmail = _signedIn ? _auth.currentUser?.email : null;
    final updated = await _calendar.sync(
      _contacts,
      selfEmails: {if (selfEmail != null) selfEmail},
    );
    if (!identical(updated, _contacts)) {
      if (mounted) setState(() => _contacts = updated);
      await _repository.save(_contacts);
    }
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

  /// Applies a logged interaction to the selected contact and persists locally
  /// (and to the cloud when signed in).
  void _onLogInteraction(InteractionEvent event) {
    final c = _selectedContact;
    if (c == null) return;
    final updated = c.logInteraction(event);
    setState(() {
      final idx = _contacts.indexWhere((x) => x.id == updated.id);
      if (idx >= 0) _contacts = [..._contacts]..[idx] = updated;
      _selectedContact = updated;
    });
    // Outbound actions open an external app; arm a confirm/undo prompt for when
    // the user returns. Manual notes/meetings stay silent.
    if (isOutboundType(event.type)) {
      _pendingOutbound = PendingOutbound(
        contactId: updated.id,
        contactName: updated.displayName,
        eventId: event.id,
        type: event.type,
        launchedAt: event.date,
      );
      _wentBackground = false;
    }
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

  void _openSettings() {
    SettingsView.show(
      context,
      onExportBackup: _exportBackup,
      onImportBackup: _importBackup,
      onCloudBackups: _cloudEnabled ? () => _openCloudBackups() : null,
      onSignIn: _cloudEnabled ? () => _openSignIn() : null,
      onSignOut: _cloudEnabled ? () => _signOut() : null,
      isSignedIn: _signedIn,
      onDeleteAllContacts: () => _deleteAllContacts(),
      onDeleteAccount: _signedIn ? () => _deleteAccount() : null,
      onLinkRelatives: () => _linkAllRelatives(),
      starColorMode: _starColorMode,
      onStarColorModeChanged: _setStarColorMode,
    );
  }

  /// Retroactively cross-links every same-last-name group as mutual
  /// connections in one pass, then persists. Reports how many contacts gained
  /// connections. The confirmation prompt lives in [SettingsView].
  Future<void> _linkAllRelatives() async {
    final before = _contacts;
    final linked = linkAllRelatives(before, now: DateTime.now());
    var changed = 0;
    for (var i = 0; i < linked.length; i++) {
      if (!identical(linked[i], before[i])) changed++;
    }
    if (changed == 0) {
      if (mounted) _showSnack('No same-last-name contacts to link');
      return;
    }
    setState(() => _contacts = linked);
    await _persist();
    if (mounted) {
      _showSnack('Linked $changed contact${changed == 1 ? '' : 's'} by last name');
    }
  }

  /// Updates the constellation star-color mode and persists the choice so the
  /// mutuals view honors it on next launch.
  void _setStarColorMode(StarColorMode mode) {
    setState(() => _starColorMode = mode);
    unawaited(_prefs.saveStarColorMode(mode));
  }

  /// Removes every contact from the device, and from the cloud sync copy when
  /// signed in (an empty push overwrites the remote `contacts` array). The
  /// confirmation prompt lives in [SettingsView]; this runs only post-confirm.
  Future<void> _deleteAllContacts() async {
    setState(() {
      _contacts = [];
      _selectedContact = null;
    });
    await _persist();
    if (mounted) _showSnack('All contacts deleted');
  }

  /// Permanently deletes the signed-in user's account along with their cloud
  /// data (backups + sync document) and the local cache. Cloud data is removed
  /// before the auth account, since once the account is gone the user is no
  /// longer authorized to delete their Firestore documents.
  Future<void> _deleteAccount() async {
    final uid = _auth.currentUser?.uid;
    try {
      if (uid != null) {
        await _cloudBackup.deleteAllBackups(uid);
        await _cloud.deleteUserData(uid);
      }
      await _auth.deleteAccount();
      await _repository.clear();
      if (mounted) {
        setState(() {
          _contacts = [];
          _selectedContact = null;
        });
        _showSnack('Account deleted');
      }
    } on AuthException catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (e) {
      if (mounted) _showSnack('Could not delete account: $e');
    }
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

  /// Opens the cloud backup manager. Requires a signed-in user; prompts the
  /// user to sign in first when cloud is enabled but they are signed out.
  Future<void> _openCloudBackups() async {
    if (!_signedIn) {
      _showSnack('Sign in to sync to use cloud backups');
      if (_cloudEnabled) await _openSignIn();
      if (!_signedIn) return;
    }
    if (!mounted) return;
    await BackupView.show(
      context,
      uid: _auth.currentUser!.uid,
      contacts: _contacts,
      service: _cloudBackup,
      onRestore: (restored) {
        setState(() {
          _contacts = restored;
          _selectedContact = null;
        });
        unawaited(_persist());
      },
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

  /// Upserts [contact] into the local list and persists locally (and to the
  /// cloud when signed in).
  /// Opens the tag-detail view for bulk add/remove of people to [tag].
  void _openTagDetail(String tag) {
    TagDetailView.show(
      context,
      tag: tag,
      contacts: _contacts,
      onApply: (memberIds) => _applyTagMembership(tag, memberIds),
    );
  }

  /// Sets [tag] on exactly the contacts in [memberIds] (adding/removing as
  /// needed), then persists. Reports how many contacts changed.
  Future<void> _applyTagMembership(String tag, Set<String> memberIds) async {
    final before = _contacts;
    final updated = applyTagMembership(before, tag, memberIds, now: DateTime.now());
    var changed = 0;
    for (var i = 0; i < updated.length; i++) {
      if (!identical(updated[i], before[i])) changed++;
    }
    if (changed == 0) return;
    setState(() {
      _contacts = updated;
      final selectedId = _selectedContact?.id;
      if (selectedId != null) {
        _selectedContact =
            updated.firstWhere((c) => c.id == selectedId, orElse: () => _selectedContact!);
      }
    });
    await _persist();
    if (mounted) {
      _showSnack('Updated "$tag" on $changed '
          'contact${changed == 1 ? '' : 's'}');
    }
  }

  Future<void> _onFormSave(Contact contact) async {
    setState(() {
      if (_editingContact != null) {
        final idx = _contacts.indexWhere((c) => c.id == contact.id);
        if (idx >= 0) {
          _contacts = [..._contacts]..[idx] = contact;
        }
      } else {
        _contacts = [..._contacts, contact];
      }
      // Auto-link this contact to anyone sharing its last name as mutual
      // connections (additive; only this surname group is touched).
      _contacts = linkRelativesOf(contact, _contacts, now: DateTime.now());
    });
    unawaited(_persist());
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

      // Drop contacts already present and collapse same-person repeats within
      // the batch (e.g. one person split across several numbered entries, or a
      // re-import), matching on device id / phone / email / name.
      final toAdd = dedupeImportedContacts(_contacts, result.contacts);

      if (toAdd.isEmpty) {
        _showSnack('No new contacts to import');
        return;
      }

      // Add to the local list and persist (cloud push happens when signed in).
      setState(() => _contacts = [..._contacts, ...toAdd]);
      unawaited(_persist());

      if (!mounted) return;
      _showSnack('Imported ${toAdd.length} '
          'contact${toAdd.length == 1 ? '' : 's'}');

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
    final filtered = _filter.isActive
        ? applyContactFilter(_contacts, _filter, now: DateTime.now())
        : _contacts;
    final q = _searchQuery.trim();
    if (q.isEmpty) return filtered;
    return filtered.where((c) => contactMatchesQuery(c, q)).toList();
  }

  /// Selects the contact [delta] positions away from the current selection in
  /// the filtered list (e.g. +1 = next, -1 = previous). No-op when there is no
  /// selection or the target falls outside the list — callers pass null to the
  /// card at the ends so the corresponding swipe is disabled.
  void _selectAdjacentContact(int delta) {
    final current = _selectedContact;
    if (current == null) return;
    final list = _filteredContacts;
    final index = list.indexWhere((c) => c.id == current.id);
    if (index == -1) return;
    final target = index + delta;
    if (target < 0 || target >= list.length) return;
    setState(() => _selectedContact = list[target]);
  }

  /// Index of the selected contact within the filtered list, or -1 if none.
  int get _selectedIndex {
    final current = _selectedContact;
    if (current == null) return -1;
    return _filteredContacts.indexWhere((c) => c.id == current.id);
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
          else if (_pivot == PivotType.stats)
            StatsView(
              contacts: _contacts,
              now: DateTime.now(),
              onSelectContact: (c) => setState(() => _selectedContact = c),
            )
          else if (_pivot == PivotType.contacts)
            ContactsListView(
              contacts: _filteredContacts,
              onSelectContact: (c) => setState(() => _selectedContact = c),
            )
          else
            GraphView(
              contacts: _filteredContacts,
              pivot: _pivot,
              onSelectContact: (c) => setState(() => _selectedContact = c),
              onOpenTag: _openTagDetail,
              starColorMode: _starColorMode,
              selectedId: _selectedContact?.id,
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
            onOpenSettings: _openSettings,
          ),

          // Contact Card
          ContactCard(
            contact: _selectedContact,
            tagCounts: tagUsageCounts(_contacts),
            relatives: _selectedContact != null
                ? relativesOf(_selectedContact!, _contacts)
                : const [],
            onSelectRelative: (r) => setState(() => _selectedContact = r),
            onOpenTag: _openTagDetail,
            onClose: () => setState(() => _selectedContact = null),
            onEdit: _selectedContact != null
                ? () => _openEditForm(_selectedContact!)
                : null,
            onLogInteraction: _onLogInteraction,
            // Swipe left/right through the filtered list; disabled at the ends.
            onNext: _selectedIndex >= 0 &&
                    _selectedIndex < _filteredContacts.length - 1
                ? () => _selectAdjacentContact(1)
                : null,
            onPrevious:
                _selectedIndex > 0 ? () => _selectAdjacentContact(-1) : null,
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

  /// Filter button (Mutuals only) with a small badge showing the active filter
  /// count. Opens the [FilterSheet].
  Widget _buildFilterButton() {
    final count = _filter.activeCount;
    return IconButton(
      tooltip: 'Filter',
      onPressed: _openFilterSheet,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.tune,
            color: _filter.isActive
                ? const Color(0xFF818cf8)
                : const Color(0xFF6b7280),
            size: 20,
          ),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                decoration: const BoxDecoration(
                  color: Color(0xFF6366f1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() {
    return FilterSheet.show(
      context,
      filter: _filter,
      contacts: _contacts,
      onChanged: (f) => setState(() => _filter = f),
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
                  if (_pivot == PivotType.mutual ||
                      _pivot == PivotType.contacts)
                    _buildFilterButton(),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    color: const Color(0xFF1a1a1a),
                    icon: const Icon(Icons.more_vert,
                        color: Color(0xFF6b7280), size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'import':
                          if (!_importing) _importFromPhone();
                        case 'info':
                          _showInfo();
                        case 'attention':
                          _openNeedsAttention();
                        case 'duplicates':
                          _reviewDuplicates();
                      }
                    },
                    itemBuilder: (ctx) => [
                      // Phone import is mobile-only; hidden on web.
                      if (!kIsWeb)
                        _menuItem(
                          'import',
                          _importing
                              ? Icons.hourglass_top
                              : Icons.contact_phone_outlined,
                          _importing ? 'Importing…' : 'Import phone contacts',
                          enabled: !_importing,
                        ),
                      _menuItem('info', Icons.info_outline, 'About this view'),
                      const PopupMenuDivider(),
                      _menuItem('attention', Icons.notifications_outlined,
                          'Needs attention'),
                      _menuItem(
                          'duplicates', Icons.merge_type, 'Review duplicates'),
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

  /// Builds a three-dot menu row with a leading icon, matching the header
  /// palette. Disabled rows render in the muted color.
  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool enabled = true,
  }) {
    final textColor =
        enabled ? const Color(0xFFe2e8f0) : const Color(0xFF6b7280);
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9ca3af)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: textColor)),
        ],
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
      (
        PivotType.stats,
        Icons.emoji_events_outlined,
        'Stats',
        'Fun stats and badges that gamify growing and tending your network.',
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
    // The Stats tab is a full dashboard, not a clustered graph — no legend.
    if (_pivot == PivotType.stats || _pivot == PivotType.contacts) {
      return const SizedBox.shrink();
    }
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
                  Text(
                    // Live count of nodes currently in the visualization;
                    // reflects the active search/filter and updates in real time
                    // because the legend rebuilds with the filtered list.
                    'Contact Node (${_filteredContacts.length})',
                    style: const TextStyle(
                        color: Color(0xFF9ca3af), fontSize: 10),
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
