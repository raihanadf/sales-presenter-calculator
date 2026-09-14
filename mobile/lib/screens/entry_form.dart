import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/models.dart' show Computed, Settings;
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
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
    try {
      final c = await context.read<AppState>().api.preview(_int(_closing), _int(_bop), _int(_audience), _harian.text.trim().isEmpty ? null : _int(_harian));
      if (mounted) setState(() => _preview = c);
    } catch (_) {
      // keep last good preview; save surfaces any real error.
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AppState>().api.createEntry({
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) return Scaffold(body: Center(child: CircularProgressIndicator(color: context.colors.teal)));
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Closing')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ReceiptCard(preview: _preview, settings: _settings!, harian: _harian.text.trim().isEmpty ? _settings!.harianDefault : _int(_harian)),
          const SizedBox(height: 22),
          const SectionTitle('Rincian closing'),
          Panel(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(kRadiusSm),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tanggal', prefixIcon: Icon(Icons.event_rounded)),
                  child: Text(isoDate(_date), style: display(15, weight: FontWeight.w600, spacing: 0)),
                ),
              ),
              const SizedBox(height: 14),
              _numField(_closing, 'Jumlah Closing', 'mis. 14', Icons.tag_rounded),
              _numField(_bop, 'BOP (Rp)', 'mis. 150000', Icons.card_giftcard_rounded),
              _numField(_audience, 'Jumlah Audience', 'mis. 33', Icons.groups_rounded),
              _numField(_harian, 'Potongan Harian (Rp)', 'default ${_settings!.harianDefault}', Icons.remove_circle_outline_rounded, last: true),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            ]),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox.shrink() : const Icon(Icons.check_rounded),
            label: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan Closing'),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, String hint, IconData icon, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 14),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon)),
          style: display(15, weight: FontWeight.w600, spacing: 0),
          onChanged: (_) => _schedulePreview(),
        ),
      );
}

// receipt: deep-teal panel with the take-home as the mint hero total.
class _ReceiptCard extends StatelessWidget {
  final Computed? preview;
  final Settings settings;
  final int harian;
  const _ReceiptCard({required this.preview, required this.settings, required this.harian});

  @override
  Widget build(BuildContext context) {
    final p = preview;
    final colors = context.colors;
    final foreground = colors.outlined ? colors.ink : Colors.white;
    final muted = colors.outlined ? colors.muted : Colors.white70;
    return Transform.rotate(
      angle: colors.outlined ? 0.01 : 0,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: colors.outlined
            ? panelDecoration(context, color: colors.gold, radius: kRadius + 4)
            : BoxDecoration(
                borderRadius: BorderRadius.circular(kRadius + 4),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colors.teal, colors.tealDark]),
                boxShadow: [BoxShadow(color: colors.tealDark.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10))],
              ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('PERHITUNGAN', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
          const SizedBox(height: 16),
          if (p == null)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Isi angka closing untuk lihat perkiraan.', style: TextStyle(color: muted)))
          else ...[
            _row('Closing', p.closingTotal, false, foreground, muted),
            _row('BOP (${settings.bopPercent}%)', p.bopValue, true, foreground, muted),
            _row('Souvenir (${settings.souvenirPercent}%)', p.souvenirValue, true, foreground, muted),
            _row('Potongan harian', harian, true, foreground, muted),
            Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: DashedLine(color: foreground.withValues(alpha: 0.45))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Diterima presenter', style: TextStyle(color: foreground, fontSize: 14, fontWeight: FontWeight.w700)),
              Rupiah(p.takeHome, size: 30, color: colors.outlined ? colors.ink : colors.mint),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _row(String label, int value, bool minus, Color foreground, Color muted) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: muted, fontSize: 14)),
          Text('${minus ? '− ' : ''}${rupiah(value)}', style: display(15, weight: FontWeight.w600, color: foreground, spacing: 0)),
        ]),
      );
}

// yyyy-mm-dd without pulling intl into this screen.
String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
