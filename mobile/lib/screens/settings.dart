import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _closingPrice = TextEditingController();
  final _bopPercent = TextEditingController();
  final _souvenirUnitPrice = TextEditingController();
  final _souvenirPercent = TextEditingController();
  final _harianDefault = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await context.read<AppState>().api.settings();
    setState(() {
      _closingPrice.text = '${s.closingPrice}';
      _bopPercent.text = '${s.bopPercent}';
      _souvenirUnitPrice.text = '${s.souvenirUnitPrice}';
      _souvenirPercent.text = '${s.souvenirPercent}';
      _harianDefault.text = '${s.harianDefault}';
      _loading = false;
    });
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _saved = null;
    });
    try {
      await context.read<AppState>().api.updateSettings({
        'closingPrice': _int(_closingPrice),
        'bopPercent': _int(_bopPercent),
        'souvenirUnitPrice': _int(_souvenirUnitPrice),
        'souvenirPercent': _int(_souvenirPercent),
        'harianDefault': _int(_harianDefault),
      });
      setState(() => _saved = 'Tersimpan');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _closingPrice.dispose();
    _bopPercent.dispose();
    _souvenirUnitPrice.dispose();
    _souvenirPercent.dispose();
    _harianDefault.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Harga')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Nilai tetap dipakai untuk closing baru. Closing lama tidak berubah.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                _field(_closingPrice, 'Harga per Closing (Rp)'),
                _field(_bopPercent, 'Persentase BOP (%)'),
                _field(_souvenirUnitPrice, 'Harga Souvenir per Audience (Rp)'),
                _field(_souvenirPercent, 'Persentase Souvenir (%)'),
                _field(_harianDefault, 'Potongan Harian default (Rp)'),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (_saved != null) ...[
                  const SizedBox(height: 8),
                  Text(_saved!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ],
                const SizedBox(height: 18),
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

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label),
        ),
      );
}
