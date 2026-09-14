import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

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
  bool _saved = false;

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
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    try {
      await context.read<AppState>().api.updateSettings({
        'closingPrice': _int(_closingPrice),
        'bopPercent': _int(_bopPercent),
        'souvenirUnitPrice': _int(_souvenirUnitPrice),
        'souvenirPercent': _int(_souvenirPercent),
        'harianDefault': _int(_harianDefault),
      });
      setState(() => _saved = true);
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(kRadiusSm)),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: AppColors.ink),
                    SizedBox(width: 10),
                    Expanded(child: Text('Nilai ini dipakai untuk closing baru. Closing yang sudah tercatat tidak berubah.', style: TextStyle(fontSize: 13, color: AppColors.ink))),
                  ]),
                ),
                const SizedBox(height: 18),
                Panel(padding: const EdgeInsets.all(16), child: Column(children: [
                  _field(_closingPrice, 'Harga per Closing (Rp)', Icons.sell_rounded),
                  _field(_bopPercent, 'Persentase BOP (%)', Icons.percent_rounded),
                  _field(_souvenirUnitPrice, 'Harga Souvenir / Audience (Rp)', Icons.card_giftcard_rounded),
                  _field(_souvenirPercent, 'Persentase Souvenir (%)', Icons.percent_rounded),
                  _field(_harianDefault, 'Potongan Harian default (Rp)', Icons.remove_circle_outline_rounded, last: true),
                ])),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                if (_saved) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.teal),
                    const SizedBox(width: 8),
                    Text('Tersimpan', style: display(14, weight: FontWeight.w600, color: AppColors.teal, spacing: 0)),
                  ]),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan'),
                ),
              ],
            ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 14),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          style: display(15, weight: FontWeight.w600, spacing: 0),
        ),
      );
}
