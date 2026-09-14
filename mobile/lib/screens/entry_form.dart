import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/models.dart' show Computed, Settings;
import '../state/app_state.dart';
import '../util/format.dart';

class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({super.key});

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _closing = TextEditingController();
  final _bop = TextEditingController();
  final _audience = TextEditingController();
  final _harian = TextEditingController();

  DateTime _date = DateTime.now();
  Settings? _settings;

  Computed? _preview;
  Timer? _debounce;
  bool _saving = false;
  String? _error;



  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final settings = await context.read<AppState>().api.settings();
    setState(() {
      _settings = settings;
      _harian.text = '${settings.harianDefault}';
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _closing.dispose();
    _bop.dispose();
    _audience.dispose();
    _harian.dispose();
    super.dispose();
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runPreview);
  }

  Future<void> _runPreview() async {
    final api = context.read<AppState>().api;
    try {
      final c = await api.preview(_int(_closing), _int(_bop), _int(_audience),
          _harian.text.trim().isEmpty ? null : _int(_harian));
      if (mounted) setState(() => _preview = c);
    } catch (_) {
      // keep last good preview; save will surface any real error.
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = context.read<AppState>().api;
      await api.createEntry({
        'entryDate': isoDate(_date),
        'closingCount': _int(_closing),
        'bopInput': _int(_bop),
        'audienceCount': _int(_audience),
        if (_harian.text.trim().isNotEmpty) 'harian': _int(_harian),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Input Closing')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Tanggal', prefixIcon: Icon(Icons.event)),
              child: Text(isoDate(_date)),
            ),
          ),
          const SizedBox(height: 14),
          _numField(_closing, 'Jumlah Closing', 'mis. 14'),
          _numField(_bop, 'BOP (Rp)', 'mis. 150000'),
          _numField(_audience, 'Jumlah Audience', 'mis. 33'),
          _numField(_harian, 'Potongan Harian (Rp)', 'default ${_settings!.harianDefault}'),
          const SizedBox(height: 8),
          _PreviewCard(preview: _preview, settings: _settings!),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label, hintText: hint),
          onChanged: (_) => _schedulePreview(),
        ),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }
}

// avoids pulling intl into this file just for one format call.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _PreviewCard extends StatelessWidget {
  final Computed? preview;
  final Settings settings;
  const _PreviewCard({required this.preview, required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = preview;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Perhitungan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (p == null)
              Text('Isi angka untuk melihat perkiraan.', style: TextStyle(color: scheme.onSurfaceVariant))
            else ...[
              _row('Closing', rupiah(p.closingTotal)),
              _row('BOP (${settings.bopPercent}%)', '- ${rupiah(p.bopValue)}'),
              _row('Souvenir (${settings.souvenirPercent}%)', '- ${rupiah(p.souvenirValue)}'),
              const Divider(),
              _row('Diterima Presenter', rupiah(p.takeHome), bold: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14)),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 16 : 14)),
          ],
        ),
      );
}
