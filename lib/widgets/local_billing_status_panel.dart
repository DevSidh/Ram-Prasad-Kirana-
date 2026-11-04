import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/local_billing_store.dart';
import '../services/local_billing_sync.dart';

class LocalBillingStatusPanel extends StatefulWidget {
  const LocalBillingStatusPanel({super.key, required this.sync});
  final LocalBillingSync sync;

  @override
  State<LocalBillingStatusPanel> createState() =>
      _LocalBillingStatusPanelState();
}

class _LocalBillingStatusPanelState extends State<LocalBillingStatusPanel> {
  bool _busy = false;
  String? _message;

  Future<void> _backup() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file = await const LocalBillingStore().createBackup(File(
          'C:/Ramprasad store/backups/manual-${DateTime.now().millisecondsSinceEpoch}.fsbak'));
      final saved = await FilePicker.saveFile(
        fileName: file.uri.pathSegments.last,
        bytes: await file.readAsBytes(),
        mimeType: 'application/octet-stream',
        dialogTitle: 'Export local billing backup',
        allowedExtensions: const ['fsbak'],
      );
      if (mounted) {
        setState(() => _message = saved == null
            ? 'Backup created at ${file.path}. Export cancelled.'
            : 'Local billing backup exported.');
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Backup failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreCopy() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    File? temporary;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['fsbak'],
      );
      if (files.isEmpty) return;
      final size = await files.single.length();
      if (size == null || size > 128 * 1024 * 1024) {
        throw const FormatException('Choose a backup smaller than 128 MB.');
      }
      final stamp = DateTime.now().microsecondsSinceEpoch;
      temporary =
          File('${Directory.systemTemp.path}/faststore-restore-$stamp.fsbak');
      await temporary.writeAsBytes(await files.single.readAsBytes(),
          flush: true);
      final result = await const LocalBillingStore().restoreBackup(
          temporary, Directory('C:/Ramprasad store/restored-$stamp'));
      if (mounted) {
        setState(() => _message =
            'Backup verified and restored to ${result.path}. Current billing records were not overwritten.');
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Restore failed: $error');
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.sync,
        builder: (context, _) {
          final sync = widget.sync;
          return Card(
            child: ExpansionTile(
              leading: Icon(sync.online == true
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined),
              title: Text(
                  '${sync.online == true ? 'Server reachable' : sync.online == false ? 'Offline' : 'Connection not verified'} · ${sync.pending} upload(s) · ${sync.conflicts.length} conflict(s)'),
              subtitle: Text(
                  'Last server check: ${sync.lastSync?.toLocal().toString().split('.').first ?? 'Not yet'}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${sync.localOnly} computer-only bill(s). These are not uploaded. Cached stock is an estimate; online orders can change central availability.'),
                        if (sync.error != null)
                          Text(sync.error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        if (sync.backupError != null)
                          Text('Automatic backup: ${sync.backupError}'),
                        for (final conflict in sync.conflicts)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.sync_problem_outlined),
                            title: Text(conflict['invoiceNumber']?.toString() ??
                                'Local bill'),
                            subtitle: Text(conflict['syncError']?.toString() ??
                                'Review required'),
                          ),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton.icon(
                            onPressed:
                                sync.running ? null : () => sync.synchronize(),
                            icon: const Icon(Icons.sync),
                            label: const Text('Sync pending bills'),
                          ),
                          if (sync.conflicts.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: sync.running
                                  ? null
                                  : () =>
                                      sync.synchronize(retryConflicts: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry reviewed conflicts'),
                            ),
                          OutlinedButton.icon(
                              onPressed: _busy ? null : _backup,
                              icon: const Icon(Icons.backup_outlined),
                              label: const Text('Export local backup')),
                          OutlinedButton.icon(
                              onPressed: _busy ? null : _restoreCopy,
                              icon: const Icon(Icons.restore),
                              label: const Text('Verify / restore a copy')),
                        ]),
                        if (sync.running || _busy)
                          const LinearProgressIndicator(),
                        if (_message != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_message!)),
                      ]),
                ),
              ],
            ),
          );
        },
      );
}
