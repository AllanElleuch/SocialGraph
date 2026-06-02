import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/cloud_backup_service.dart';

/// Dark-theme palette for the backup management surface (RFC-004, U4.2).
class _Palette {
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color border = Color(0xFF333333);
  static const Color accent = Color(0xFF818CF8);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color danger = Color(0xFFEF4444);
}

/// A full-screen view for managing cloud backups: create a new snapshot of the
/// current contacts, browse existing snapshots, and restore or delete them.
///
/// The view owns all Firestore access through [service]; the parent supplies
/// the live [contacts] (used when creating a backup) and an [onRestore]
/// callback invoked with the restored contact list when the user confirms a
/// restore.
class BackupView extends StatefulWidget {
  final String uid;
  final List<Contact> contacts;
  final CloudBackupService service;
  final void Function(List<Contact> restored) onRestore;

  const BackupView({
    super.key,
    required this.uid,
    required this.contacts,
    required this.service,
    required this.onRestore,
  });

  /// Pushes the view as a full-screen route.
  static Future<void> show(
    BuildContext context, {
    required String uid,
    required List<Contact> contacts,
    required CloudBackupService service,
    required void Function(List<Contact> restored) onRestore,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BackupView(
          uid: uid,
          contacts: contacts,
          service: service,
          onRestore: onRestore,
        ),
      ),
    );
  }

  @override
  State<BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends State<BackupView> {
  List<CloudBackup>? _backups;
  String? _error;
  bool _busy = false;

  /// Current operation label (e.g. "Backing up…") shown above the progress bar,
  /// or null when idle.
  String? _progressLabel;

  /// Fraction complete (0..1) of the running operation, or null for an
  /// indeterminate bar (e.g. deletes, which aren't step-counted).
  double? _progress;

  /// Relays service progress into a determinate bar.
  void _onProgress(int completed, int total) {
    if (!mounted || total <= 0) return;
    setState(() => _progress = completed / total);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    try {
      final list = await widget.service.listBackups(widget.uid);
      if (mounted) setState(() => _backups = list);
    } catch (e) {
      if (mounted) {
        setState(() {
          _backups = const [];
          _error = _messageFor(e);
        });
      }
    }
  }

  Future<void> _createBackup() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progressLabel = 'Backing up…';
      _progress = 0;
    });
    try {
      await widget.service.createBackup(
        widget.uid,
        widget.contacts,
        onProgress: _onProgress,
      );
      if (!mounted) return;
      _snack('Backed up ${widget.contacts.length} '
          'contact${widget.contacts.length == 1 ? '' : 's'}');
      await _load();
    } catch (e) {
      if (mounted) _snack(_messageFor(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progressLabel = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _restore(CloudBackup backup) async {
    final confirmed = await _confirm(
      title: 'Restore this backup?',
      message:
          'This replaces your current ${widget.contacts.length} contacts with '
          'the ${backup.contactCount} from ${_formatDate(backup.createdAt)}. '
          'Consider backing up first.',
      confirmLabel: 'Restore',
    );
    if (confirmed != true || _busy) return;

    setState(() {
      _busy = true;
      _progressLabel = 'Restoring…';
      _progress = 0;
    });
    try {
      final restored = await widget.service.restoreBackup(
        widget.uid,
        backup.id,
        onProgress: _onProgress,
      );
      if (!mounted) return;
      widget.onRestore(restored);
      _snack('Restored ${restored.length} '
          'contact${restored.length == 1 ? '' : 's'}');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _progressLabel = null;
          _progress = null;
        });
        _snack(_messageFor(e));
      }
    }
  }

  Future<void> _delete(CloudBackup backup) async {
    final confirmed = await _confirm(
      title: 'Delete this backup?',
      message: 'The snapshot from ${_formatDate(backup.createdAt)} will be '
          'permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed != true || _busy) return;

    // Deletes aren't step-counted, so the bar stays indeterminate (_progress
    // null) while still showing a labelled busy state.
    setState(() {
      _busy = true;
      _progressLabel = 'Deleting…';
      _progress = null;
    });
    try {
      await widget.service.deleteBackup(widget.uid, backup.id);
      if (mounted) _snack('Backup deleted');
      await _load();
    } catch (e) {
      if (mounted) _snack(_messageFor(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progressLabel = null;
          _progress = null;
        });
      }
    }
  }

  String _messageFor(Object e) =>
      e is CloudBackupException ? e.message : 'Something went wrong: $e';

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _Palette.surface,
        title: Text(title,
            style: const TextStyle(color: _Palette.textPrimary, fontSize: 16)),
        content: Text(message,
            style: const TextStyle(color: _Palette.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: _Palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? _Palette.danger : _Palette.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backups = _backups;
    return Scaffold(
      backgroundColor: _Palette.background,
      appBar: AppBar(
        backgroundColor: _Palette.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: _Palette.textPrimary),
        title: const Text(
          'Cloud backups',
          style: TextStyle(
            color: _Palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _CreateBar(
            contactCount: widget.contacts.length,
            busy: _busy,
            onCreate: _createBackup,
          ),
          if (_busy)
            _ProgressBar(label: _progressLabel, value: _progress),
          Expanded(
            child: backups == null
                ? const Center(
                    child: CircularProgressIndicator(color: _Palette.accent),
                  )
                : _BackupList(
                    backups: backups,
                    error: _error,
                    formatDate: _formatDate,
                    onRestore: _restore,
                    onDelete: _delete,
                  ),
          ),
        ],
      ),
    );
  }

  /// Formats a backup timestamp like "Jun 2, 2026 · 3:45 PM".
  static String _formatDate(DateTime? dt) {
    if (dt == null) return 'Just now';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} '
        '· $hour12:$minute $ampm';
  }
}

class _CreateBar extends StatelessWidget {
  final int contactCount;
  final bool busy;
  final VoidCallback onCreate;

  const _CreateBar({
    required this.contactCount,
    required this.busy,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: _Palette.surface,
        border: Border(bottom: BorderSide(color: _Palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Back up to the cloud',
                  style: TextStyle(
                    color: _Palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Save a snapshot of your $contactCount '
                  'contact${contactCount == 1 ? '' : 's'}.',
                  style: const TextStyle(
                    color: _Palette.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: busy ? null : onCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: _Palette.accent,
              foregroundColor: Colors.black,
              disabledBackgroundColor: _Palette.border,
            ),
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: const Text('Back up'),
          ),
        ],
      ),
    );
  }
}

/// A labelled progress strip shown beneath the create bar while a backup,
/// restore, or delete is running. A null [value] renders an indeterminate bar
/// (used for deletes); otherwise it fills from 0..1 and shows a percentage.
class _ProgressBar extends StatelessWidget {
  final String? label;
  final double? value;

  const _ProgressBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final percent = value == null ? null : (value!.clamp(0, 1) * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: _Palette.surface,
        border: Border(bottom: BorderSide(color: _Palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label ?? 'Working…',
                style: const TextStyle(color: _Palette.textMuted, fontSize: 12),
              ),
              if (percent != null)
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: _Palette.textMuted,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: _Palette.border,
              valueColor: const AlwaysStoppedAnimation<Color>(_Palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupList extends StatelessWidget {
  final List<CloudBackup> backups;
  final String? error;
  final String Function(DateTime?) formatDate;
  final void Function(CloudBackup) onRestore;
  final void Function(CloudBackup) onDelete;

  const _BackupList({
    required this.backups,
    required this.error,
    required this.formatDate,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (backups.isEmpty) {
      return _EmptyState(error: error);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: backups.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 1,
        color: _Palette.border,
      ),
      itemBuilder: (context, index) {
        final backup = backups[index];
        return _BackupRow(
          backup: backup,
          dateLabel: formatDate(backup.createdAt),
          onRestore: () => onRestore(backup),
          onDelete: () => onDelete(backup),
        );
      },
    );
  }
}

class _BackupRow extends StatelessWidget {
  final CloudBackup backup;
  final String dateLabel;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _BackupRow({
    required this.backup,
    required this.dateLabel,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_outlined,
              color: _Palette.accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backup.label?.isNotEmpty == true ? backup.label! : dateLabel,
                  style: const TextStyle(
                    color: _Palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${backup.contactCount} '
                  'contact${backup.contactCount == 1 ? '' : 's'}'
                  '${backup.label?.isNotEmpty == true ? ' · $dateLabel' : ''}',
                  style: const TextStyle(
                    color: _Palette.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRestore,
            child: const Text('Restore',
                style: TextStyle(color: _Palette.accent)),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Delete backup',
            icon: const Icon(Icons.delete_outline,
                color: _Palette.textMuted, size: 20),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? error;
  const _EmptyState({required this.error});

  @override
  Widget build(BuildContext context) {
    final isError = error != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.cloud_off_outlined : Icons.cloud_outlined,
            color: isError ? _Palette.danger : _Palette.textMuted,
            size: 44,
          ),
          const SizedBox(height: 14),
          Text(
            isError ? 'Could not load backups' : 'No backups yet',
            style: const TextStyle(
              color: _Palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error ?? 'Tap "Back up" to save your first cloud snapshot.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _Palette.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
