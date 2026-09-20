import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final state = context.read<AppState>();
    // a new presenter must land in exactly one branch, so the owner has to
    // pick which branch it is before creating one.
    if (state.user!.isSuperadmin && state.selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih satu cabang dulu di halaman utama.')));
      return;
    }
    final created = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, backgroundColor: context.colors.card, builder: (_) => const _AddPresenterSheet());
    if (created == true) setState(_reload);
  }

  // superadmin only: move a presenter to another branch. entries already
  // recorded stay with the branch they were recorded in.
  Future<void> _move(AppUser presenter) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final target = await showModalBottomSheet<Branch>(
      context: context,
      backgroundColor: context.colors.card,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(context.pageInset, 18, context.pageInset, 24),
          children: [
            Text('Pindahkan ${presenter.name}', style: display(19)),
            const SizedBox(height: 4),
            Text('Riwayat closing lama tetap tercatat di cabang lamanya.',
                style: TextStyle(color: context.colors.muted, fontSize: 13)),
            const SizedBox(height: 14),
            for (final branch in state.branches.where((b) => b.active && b.id != presenter.branchId))
              ListTile(
                leading: const Icon(Icons.storefront_rounded),
                title: Text(branch.name),
                onTap: () => Navigator.pop(context, branch),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    try {
      await state.api.movePresenter(presenter.id, target.id);
      messenger.showSnackBar(SnackBar(
          content: Text('${presenter.name} dipindah ke ${target.name}.')));
      setState(_reload);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // superadmin only: issue a new password when someone forgot theirs. it is
  // shown once here and must be copied out now.
  Future<void> _resetPassword(AppUser presenter) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reset password ${presenter.name}?'),
        content: const Text(
            'Password lama langsung tidak bisa dipakai. Password baru muncul satu kali.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final password = await state.api.resetPassword(presenter.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Password baru ${presenter.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SelectableText(password,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 10),
            const Text('Kirim ke orangnya. Tidak bisa dilihat lagi setelah ini.'),
          ]),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: 'Username: @${presenter.username}\nPassword: $password'));
                Navigator.pop(context);
              },
              child: const Text('Salin & tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
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
                  Text(
                      list[i].branchName == null
                          ? '@${list[i].username}'
                          : '@${list[i].username} · ${list[i].branchName}',
                      style: TextStyle(color: context.colors.muted, fontSize: 13)),
                ])),
                if (context.read<AppState>().user!.isSuperadmin)
                  PopupMenuButton<String>(
                    onSelected: (value) => value == 'move'
                        ? _move(list[i])
                        : _resetPassword(list[i]),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'move', child: Text('Pindah cabang')),
                      PopupMenuItem(
                          value: 'reset', child: Text('Reset password')),
                    ],
                  ),
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
