import 'dart:io';
import 'package:bybata/core/theme/app_theme.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_logger.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Opens the in-app diagnostic log viewer.
///
/// Usable on every build mode (debug / profile / release). Pulls from the
/// [AppLogger] in-memory ring buffer so users in the field can copy or
/// share the log without needing a Mac/Xcode.
class DiagnosticLogScreen extends StatefulWidget {
  const DiagnosticLogScreen({super.key});

  static const String routeName = '/diagnostic-log';

  @override
  State<DiagnosticLogScreen> createState() => _DiagnosticLogScreenState();
}

class _DiagnosticLogScreenState extends State<DiagnosticLogScreen> {
  final ScrollController _scroll = ScrollController();
  bool _autoScroll = true;
  LogLevel? _filter;

  @override
  void initState() {
    super.initState();
    AppLogger.addListener(_onLogChanged);
  }

  @override
  void dispose() {
    AppLogger.removeListener(_onLogChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onLogChanged() {
    if (!mounted) return;
    setState(() {});
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  List<LogEntry> _entries() {
    final all = AppLogger.snapshot();
    if (_filter == null) return all;
    return all.where((e) => e.level == _filter).toList(growable: false);
  }

  String _formatAll(List<LogEntry> entries) {
    final mode = kReleaseMode
        ? 'release'
        : (kProfileMode ? 'profile' : 'debug');
    final header = '=== Bybata diagnostic log ($mode) ===\n'
        'Generated: ${DateTime.now().toIso8601String()}\n'
        'Entries: ${entries.length}\n\n';
    return header + entries.map((e) => e.format()).join('\n');
  }

  Future<void> _copyAll() async {
    final text = _formatAll(_entries());
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppToast.show(context, 'Copied ${text.length} chars to clipboard');
  }

  Future<void> _shareAll() async {
    final entries = _entries();
    final text = _formatAll(entries);

    // Strategy: write to a file first and share the FILE, not raw text.
    // iOS share sheet handles file attachments far more reliably than text
    // (works with Mail, Messages, Files, AirDrop, Notes, third-party apps).
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/bybata-log-$stamp.txt');
      await file.writeAsString(text, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain', name: 'bybata-log.txt')],
        subject: 'Bybata diagnostic log',
        text: 'Diagnostic log captured ${DateTime.now().toIso8601String()} '
            '(${entries.length} entries)',
      );
    } catch (e, s) {
      // Fallback: share as plain text.
      AppLogger.logError(e, s, hint: 'DiagnosticLog.share file failed');
      try {
        await Share.share(text, subject: 'Bybata diagnostic log');
      } catch (e2, s2) {
        AppLogger.logError(e2, s2, hint: 'DiagnosticLog.share text failed');
        if (mounted) {
          AppToast.show(context, 'Share failed: $e2');
        }
      }
    }
  }

  /// Opens a fullscreen viewer with a single SelectableText. Users can
  /// long-press → "Select All" → "Copy" using the native iOS menu, bypassing
  /// any Flutter Clipboard issues. Works even when the share sheet is blocked.
  void _openTextViewer() {
    final text = _formatAll(_entries());
    GuardedNavigator.push(context, 
      MaterialPageRoute(
        builder: (_) => _LogTextViewer(text: text),
      ),
    );
  }

  void _clear() {
    AppLogger.clear();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            icon: Icon(
              _autoScroll
                  ? Icons.vertical_align_bottom
                  : Icons.pause_circle_outline,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: _copyAll,
          ),
          IconButton(
            tooltip: 'View as text',
            icon: const Icon(Icons.text_snippet_outlined),
            onPressed: _openTextViewer,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share),
            onPressed: _shareAll,
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(label: 'All', value: null),
                _filterChip(label: 'Errors', value: LogLevel.error),
                _filterChip(label: 'Warn', value: LogLevel.warn),
                _filterChip(label: 'Info', value: LogLevel.info),
                _filterChip(label: 'Debug', value: LogLevel.debug),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No log entries yet.\nReproduce the issue to capture errors.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _LogTile(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required LogLevel? value}) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;
  const _LogTile({required this.entry});

  Color _color(BuildContext c) {
    switch (entry.level) {
      case LogLevel.error:
        return Colors.redAccent;
      case LogLevel.warn:
        return Colors.orangeAccent;
      case LogLevel.info:
        return AppColors.primary;
      case LogLevel.debug:
        return Theme.of(c).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = entry.timestamp.toLocal().toIso8601String().split('T').last;
    return InkWell(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: entry.format()));
        if (!context.mounted) return;
        AppToast.show(context, 'Entry copied');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
            left: BorderSide(color: _color(context), width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  entry.level.name.toUpperCase(),
                  style: TextStyle(
                    color: _color(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 2),
            SelectableText(
              entry.message,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            if (entry.stack != null) ...[
              const SizedBox(height: 4),
              SelectableText(
                entry.stack.toString(),
                maxLines: 8,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fullscreen text viewer used by [DiagnosticLogScreen]. Renders the entire
/// log into a single [SelectableText] so users can long-press → Select All →
/// Copy via the native iOS menu, and use the share sheet for files/email.
class _LogTextViewer extends StatelessWidget {
  final String text;
  const _LogTextViewer({required this.text});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppToast.show(context, 'Copied ${text.length} chars');
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/bybata-log-$stamp.txt');
      await file.writeAsString(text, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain', name: 'bybata-log.txt')],
        subject: 'Bybata diagnostic log',
      );
    } catch (e, s) {
      AppLogger.logError(e, s, hint: 'LogTextViewer.share');
      if (context.mounted) {
        AppToast.show(context, 'Share failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log (text)'),
        actions: [
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(context),
          ),
          IconButton(
            tooltip: 'Share file',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _shareFile(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: SelectableText(
              text.isEmpty ? 'No log entries yet.' : text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.35,
              ),
              showCursor: true,
            ),
          ),
        ),
      ),
    );
  }
}
