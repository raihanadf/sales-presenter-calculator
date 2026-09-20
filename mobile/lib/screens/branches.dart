import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

// superadmin-only: create branches, close or reopen them, and read their
// calculation values. a closed branch keeps all of its history.
class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().loadBranches();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final created = await showModalBottomSheet<NewBranch>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      builder: (_) => const _AddBranchSheet(),
    );
    if (created == null || !mounted) return;
    await _reload();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _CredentialsDialog(created: created),
    );
  }

  Future<void> _toggleActive(Branch branch) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context
          .read<AppState>()
          .api
          .updateBranch(branch.id, active: !branch.active);
      await _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // the accounts attached to a branch, admins included, with a password reset
  // for whoever forgot theirs.
  Future<void> _showMembers(Branch branch) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    List<AppUser> members;
    try {
      members = await state.api.branchMembers(branch.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.card,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding:
              EdgeInsets.fromLTRB(context.pageInset, 18, context.pageInset, 24),
          children: [
            Text(branch.name, style: display(20)),
            const SizedBox(height: 4),
            Text('${members.length} akun di cabang ini',
                style: TextStyle(color: context.colors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            for (final member in members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(member.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '@${member.username} · ${member.role == 'admin' ? 'Admin cabang' : 'Presenter'}'),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetPassword(member);
                  },
                  child: const Text('Reset password'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // a new password is generated and shown once; nothing stores it in clear text.
  Future<void> _resetPassword(AppUser member) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final password = await state.api.resetPassword(member.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Password baru ${member.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SelectableText(password,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 10),
            const Text('Kirim ke orangnya. Tidak muncul lagi setelah ini.'),
          ]),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: 'Username: @${member.username}\nPassword: $password'));
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
    final branches = context.watch<AppState>().branches;

    return Scaffold(
      appBar: AppBar(title: const Text('Cabang')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: context.colors.mint,
        foregroundColor: context.colors.ink,
        icon: const Icon(Icons.add_business_rounded),
        label: Text('Tambah',
            style: display(15,
                weight: FontWeight.w700,
                color: context.colors.ink,
                spacing: 0)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.colors.teal))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.colors.muted)),
                        const SizedBox(height: 14),
                        OutlinedButton(
                            onPressed: _reload,
                            child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: context.colors.teal,
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: pagePadding(context, top: 12, bottom: 110),
                    itemCount: branches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _BranchTile(
                      branch: branches[i],
                      onToggle: () => _toggleActive(branches[i]),
                      onOpen: () => _showMembers(branches[i]),
                    ),
                  ),
                ),
    );
  }
}

class _BranchTile extends StatelessWidget {
  final Branch branch;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  const _BranchTile(
      {required this.branch, required this.onToggle, required this.onOpen});

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: context.colors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.storefront_rounded, color: context.colors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(branch.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.colors.ink)),
                const SizedBox(height: 3),
                Text(branch.active ? 'Aktif' : 'Ditutup · hanya bisa dilihat',
                    style: TextStyle(
                        fontSize: 13,
                        color: branch.active
                            ? context.colors.teal
                            : context.colors.muted)),
              ],
            ),
          ),
          TextButton(
            onPressed: onToggle,
            child: Text(branch.active ? 'Tutup' : 'Buka'),
          ),
        ]),
        ),
        ),
      );
}

// the generated admin password is shown once here and never stored in clear
// text, so it has to be copied out now.
class _CredentialsDialog extends StatelessWidget {
  final NewBranch created;
  const _CredentialsDialog({required this.created});

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${created.branch.name} dibuat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Kirim akun ini ke admin cabang. Password hanya muncul sekali.'),
            const SizedBox(height: 16),
            _CredentialRow(label: 'Username', value: created.adminUsername),
            const SizedBox(height: 8),
            _CredentialRow(label: 'Password', value: created.adminPassword),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text:
                      'Username: ${created.adminUsername}\nPassword: ${created.adminPassword}'));
              Navigator.pop(context);
            },
            child: const Text('Salin & tutup'),
          ),
        ],
      );
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 82,
            child: Text(label,
                style: TextStyle(color: context.colors.muted, fontSize: 13))),
        Expanded(
            child: SelectableText(value,
                style: const TextStyle(fontWeight: FontWeight.w800))),
      ]);
}

class _AddBranchSheet extends StatefulWidget {
  const _AddBranchSheet();

  @override
  State<_AddBranchSheet> createState() => _AddBranchSheetState();
}

class _AddBranchSheetState extends State<_AddBranchSheet> {
  final _name = TextEditingController();
  final _adminName = TextEditingController();
  final _adminUsername = TextEditingController();
  final _closingPrice = TextEditingController(text: '81000');
  final _bopPercent = TextEditingController(text: '60');
  final _souvenirUnitPrice = TextEditingController(text: '6000');
  final _souvenirPercent = TextEditingController(text: '60');
  final _harianDefault = TextEditingController(text: '100000');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _adminName.dispose();
    _adminUsername.dispose();
    _closingPrice.dispose();
    _bopPercent.dispose();
    _souvenirUnitPrice.dispose();
    _souvenirPercent.dispose();
    _harianDefault.dispose();
    super.dispose();
  }

  int _int(TextEditingController c) => int.parse(c.text.trim());

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await context.read<AppState>().api.createBranch(
            _name.text.trim(),
            {
              'closingPrice': _int(_closingPrice),
              'bopPercent': _int(_bopPercent),
              'souvenirUnitPrice': _int(_souvenirUnitPrice),
              'souvenirPercent': _int(_souvenirPercent),
              'harianDefault': _int(_harianDefault),
            },
            _adminName.text.trim(),
            _adminUsername.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(created);
    } on FormatException {
      setState(() => _error = 'Semua angka harus diisi.');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
            left: context.pageInset,
            right: context.pageInset,
            top: 14,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: context.colors.line,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Cabang baru', style: display(20)),
              const SizedBox(height: 6),
              Text(
                'Satu tim di lokasi yang sama boleh jadi cabang sendiri, '
                'misalnya "Cabang Malang - Grup 2".',
                style: TextStyle(color: context.colors.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Nama cabang',
                      prefixIcon: Icon(Icons.storefront_rounded))),
              const SizedBox(height: 22),
              const SectionTitle('Angka perhitungan'),
              _NumberField(controller: _closingPrice, label: 'Harga closing'),
              const SizedBox(height: 14),
              _NumberField(controller: _bopPercent, label: 'Persen BOP'),
              const SizedBox(height: 14),
              _NumberField(
                  controller: _souvenirUnitPrice, label: 'Harga souvenir'),
              const SizedBox(height: 14),
              _NumberField(
                  controller: _souvenirPercent, label: 'Persen souvenir'),
              const SizedBox(height: 14),
              _NumberField(
                  controller: _harianDefault, label: 'Harian (default)'),
              const SizedBox(height: 22),
              const SectionTitle('Admin cabang'),
              TextField(
                  controller: _adminName,
                  decoration: const InputDecoration(
                      labelText: 'Nama admin',
                      prefixIcon: Icon(Icons.badge_outlined))),
              const SizedBox(height: 14),
              TextField(
                  controller: _adminUsername,
                  decoration: const InputDecoration(
                      labelText: 'Username admin',
                      prefixIcon: Icon(Icons.alternate_email_rounded))),
              const SizedBox(height: 8),
              Text('Password dibuat otomatis dan ditampilkan satu kali.',
                  style:
                      TextStyle(color: context.colors.muted, fontSize: 12)),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Buat cabang'),
              ),
            ]),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _NumberField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
      );
}
