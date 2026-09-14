import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/excel_import.dart';
import '../util/format.dart';
import '../util/recap_pdf.dart';
import '../widgets.dart';

Future<bool?> showImportSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      builder: (_) => const _ImportSheet(),
    );

Future<void> showExportSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      builder: (_) => const _ExportSheet(),
    );

// subsequence match: every char of the query appears in order inside the text.
bool _fuzzy(String query, String text) {
  var i = 0;
  for (var j = 0; j < text.length && i < query.length; j++) {
    if (text[j] == query[i]) i++;
  }
  return i == query.length;
}

class _ImportSheet extends StatefulWidget {
  const _ImportSheet();

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  Settings? _settings;
  List<AppUser> _presenters = [];
  AppUser? _presenter;
  ImportResult? _parsed;
  String? _fileName;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    final results = await Future.wait([api.settings(), api.presenters()]);
    if (!mounted) return;
    setState(() {
      _settings = results[0] as Settings;
      _presenters = results[1] as List<AppUser>;
    });
  }

  Future<void> _downloadTemplate() async {
    final bytes = buildImportTemplate(_settings!);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/template-import-closing.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _fileName = file.name;
      _parsed = parseImport(bytes);
      _error = null;
    });
  }

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      await context.read<AppState>().api.bulkImport(
          _presenter!.id, _parsed!.rows.map((r) => r.toJson()).toList());
      if (mounted) Navigator.pop(context, true);
      return;
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = _parsed?.rows ?? const [];
    final ready = _presenter != null && rows.isNotEmpty && !_importing;

    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(context.pageInset, 18, context.pageInset, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Import Closing', style: display(22)),
              const SizedBox(height: 4),
              Text('Unggah closing massal dari Excel.',
                  style: TextStyle(color: colors.muted)),
              const SizedBox(height: 20),
              _StepCard(
                step: '1',
                title: 'Unduh template',
                subtitle:
                    'Isi tanggal, jumlah closing, BOP, audiens, dan potongan harian.',
                action: OutlinedButton.icon(
                  onPressed: _settings == null ? null : _downloadTemplate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Unduh Template'),
                ),
              ),
              const SizedBox(height: 12),
              _StepCard(
                step: '2',
                title: 'Pilih file terisi',
                subtitle: _fileName ?? 'Format .xlsx dari template di atas.',
                action: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Pilih File'),
                ),
              ),
              if (_parsed != null) ...[
                const SizedBox(height: 10),
                Text('${rows.length} baris siap diimport.',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: colors.ink)),
                for (final err in _parsed!.errors)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(err,
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade800)),
                  ),
              ],
              const SizedBox(height: 12),
              _StepCard(
                step: '3',
                title: 'Pilih presenter',
                subtitle: _presenter == null
                    ? 'Ketik untuk mencari nama.'
                    : 'Terpilih: ${_presenter!.name}',
                action: Autocomplete<AppUser>(
                  displayStringForOption: (u) => u.name,
                  optionsBuilder: (value) {
                    final q = value.text.trim().toLowerCase();
                    if (q.isEmpty) return _presenters;
                    return _presenters.where((u) =>
                        _fuzzy(q, '${u.name} ${u.username}'.toLowerCase()));
                  },
                  onSelected: (u) => setState(() => _presenter = u),
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmit) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Cari presenter',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: ready ? _import : null,
                child: _importing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(rows.isEmpty
                        ? 'Import'
                        : 'Import ${rows.length} closing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final Widget action;
  const _StepCard(
      {required this.step,
      required this.title,
      required this.subtitle,
      required this.action});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.mint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.line),
                ),
                child: Text(step, style: display(14, color: colors.ink)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(color: colors.muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          action,
        ],
      ),
    );
  }
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet();

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late String _month;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _month = thisMonth();
  }

  // last 12 months as yyyy-mm, newest first.
  List<String> get _options {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entries = await context.read<AppState>().api.monthEntries(_month);
      if (entries.isEmpty) {
        setState(() => _error = 'Belum ada closing di bulan ini.');
        return;
      }
      final bytes = await buildRecapPdf(_month, entries);
      await Printing.sharePdf(bytes: bytes, filename: 'rekap-$_month.pdf');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: SingleChildScrollView(
        padding:
            EdgeInsets.fromLTRB(context.pageInset, 18, context.pageInset, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Export Rekap', style: display(22)),
            const SizedBox(height: 4),
            Text('Rekap bulanan take-home per presenter dalam PDF.',
                style: TextStyle(color: colors.muted)),
            const SizedBox(height: 20),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _month,
                  isExpanded: true,
                  items: [
                    for (final m in _options)
                      DropdownMenuItem(value: m, child: Text(monthLabel(m))),
                  ],
                  onChanged: (v) => setState(() => _month = v!),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Buat PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
