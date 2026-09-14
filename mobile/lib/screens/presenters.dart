import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class PresentersScreen extends StatefulWidget {
  const PresentersScreen({super.key});

  @override
  State<PresentersScreen> createState() => _PresentersScreenState();
}

class _PresentersScreenState extends State<PresentersScreen> {
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppState>().api.presenters();
  }

  Future<void> _add() async {
    final created = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, backgroundColor: context.colors.card, builder: (_) => const _AddPresenterSheet());
    if (created == true) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Presenter')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: context.colors.mint,
        foregroundColor: context.colors.ink,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text('Tambah', style: display(15, weight: FontWeight.w700, color: context.colors.ink, spacing: 0)),
      ),
      body: FutureBuilder<List<AppUser>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: context.colors.teal));
          if (snap.hasError) return Center(child: Text('${snap.error}', style: TextStyle(color: context.colors.muted)));
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: EmptyNote('Belum ada presenter. Tambah lewat tombol di bawah.'));
          return ListView.separated(
            padding: pagePadding(context, top: 12, bottom: 110),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => Panel(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 44, height: 44, alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.colors.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: Text(list[i].name.isNotEmpty ? list[i].name[0].toUpperCase() : '?', style: display(18, color: context.colors.teal, spacing: 0))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(list[i].name, style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.ink, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('@${list[i].username}', style: TextStyle(color: context.colors.muted, fontSize: 13)),
                ])),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _AddPresenterSheet extends StatefulWidget {
  const _AddPresenterSheet();

  @override
  State<_AddPresenterSheet> createState() => _AddPresenterSheetState();
}

class _AddPresenterSheetState extends State<_AddPresenterSheet> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AppState>().api.createPresenter(_name.text.trim(), _username.text.trim(), _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(left: context.pageInset, right: context.pageInset, top: 14, bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Presenter baru', style: display(20)),
          const SizedBox(height: 20),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama', prefixIcon: Icon(Icons.badge_outlined))),
          const SizedBox(height: 16),
          TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email_rounded))),
          const SizedBox(height: 16),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password (min 6)', prefixIcon: Icon(Icons.lock_outline_rounded))),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan'),
          ),
        ]),
      ),
    );
  }
}
