import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'reminders.dart';
import 'store.dart';
import 'strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initReminders();
  final entries = await Store.load();
  final ar = await Store.loadArabic();
  runApp(LedgerApp(entries: entries, arabic: ar));
}

class LedgerApp extends StatefulWidget {
  final List<Entry> entries;
  final bool arabic;
  const LedgerApp({super.key, required this.entries, required this.arabic});

  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> {
  late List<Entry> entries = List.of(widget.entries);
  late bool ar = widget.arabic;

  Str get s => Str(ar);

  @override
  void initState() {
    super.initState();
    rescheduleAll(entries, s).catchError((_) {});
  }

  Future<void> _persist() async {
    await Store.save(entries);
    setState(() {});
  }

  Future<void> addEntry(Entry e) async {
    entries.add(e);
    await _persist();
    try {
      await requestReminderPermissions();
      await scheduleFor(e, s);
    } catch (_) {}
  }

  Future<void> update(Entry e) async {
    final i = entries.indexWhere((x) => x.id == e.id);
    if (i < 0) return;
    entries[i] = e;
    await _persist();
    try {
      await scheduleFor(e, s);
    } catch (_) {}
  }

  Future<void> remove(Entry e) async {
    entries.removeWhere((x) => x.id == e.id);
    await _persist();
    try {
      await cancelFor(e);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: s.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F5FA8)),
        useMaterial3: true,
      ),
      builder: (context, child) => Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: HomePage(
        s: s,
        entries: entries,
        onAdd: addEntry,
        onUpdate: update,
        onDelete: remove,
        onToggleLang: () async {
          ar = !ar;
          await Store.saveArabic(ar);
          setState(() {});
          rescheduleAll(entries, s).catchError((_) {});
        },
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final Str s;
  final List<Entry> entries;
  final Future<void> Function(Entry) onAdd;
  final Future<void> Function(Entry) onUpdate;
  final Future<void> Function(Entry) onDelete;
  final VoidCallback onToggleLang;
  const HomePage({
    super.key,
    required this.s,
    required this.entries,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.onToggleLang,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.appTitle),
          actions: [TextButton(onPressed: onToggleLang, child: Text(s.language))],
          bottom: TabBar(tabs: [
            Tab(text: s.all),
            Tab(text: s.owedToMe),
            Tab(text: s.iOwe),
          ]),
        ),
        body: SafeArea(
          child: Column(children: [
            TotalsBar(s: s, entries: entries),
            Expanded(
              child: TabBarView(children: [
                EntryList(s: s, entries: entries, onUpdate: onUpdate, onDelete: onDelete),
                EntryList(
                    s: s,
                    entries: entries.where((e) => e.direction == Direction.lent).toList(),
                    onUpdate: onUpdate,
                    onDelete: onDelete),
                EntryList(
                    s: s,
                    entries: entries.where((e) => e.direction == Direction.borrowed).toList(),
                    onUpdate: onUpdate,
                    onDelete: onDelete),
              ]),
            ),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('add-fab'),
          icon: const Icon(Icons.add),
          label: Text(s.add),
          onPressed: () async {
            final e = await Navigator.of(context).push<Entry>(
              MaterialPageRoute(builder: (_) => AddPage(s: s)),
            );
            if (e != null) await onAdd(e);
          },
        ),
      ),
    );
  }
}

class TotalsBar extends StatelessWidget {
  final Str s;
  final List<Entry> entries;
  const TotalsBar({super.key, required this.s, required this.entries});

  @override
  Widget build(BuildContext context) {
    final t = totalsByCurrency(entries);
    if (t.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          for (final k in t.keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(k, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${s.owedToMe}: ${formatAmount(t[k]!.owedToMe)}'),
                  Text('${s.iOwe}: ${formatAmount(t[k]!.iOwe)}'),
                  Text('${s.netLabel}: ${formatAmount(t[k]!.net)}'),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

Color statusColor(Status st) {
  switch (st) {
    case Status.settled:
      return Colors.grey;
    case Status.overdue:
      return Colors.red;
    case Status.dueSoon:
      return Colors.orange;
    case Status.open:
      return Colors.blue;
  }
}

class EntryList extends StatelessWidget {
  final Str s;
  final List<Entry> entries;
  final Future<void> Function(Entry) onUpdate;
  final Future<void> Function(Entry) onDelete;
  const EntryList({
    super.key,
    required this.s,
    required this.entries,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return Center(child: Text(s.empty));
    final now = DateTime.now();
    final sorted = List.of(entries)
      ..sort((a, b) {
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        final ad = a.due, bd = b.due;
        if (ad == null && bd == null) return b.created.compareTo(a.created);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final e = sorted[i];
        final st = e.statusOn(now);
        final lent = e.direction == Direction.lent;
        return ListTile(
          key: ValueKey('entry-${e.id}'),
          leading: Icon(lent ? Icons.arrow_circle_down : Icons.arrow_circle_up,
              color: lent ? Colors.green : Colors.red),
          title: Text(e.person),
          subtitle: Text([
            s.status(st),
            if (e.due != null) DateFormat('d MMM yyyy').format(e.due!),
            if (e.note.isNotEmpty) e.note,
          ].join(' · ')),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${formatAmount(e.remaining)} ${e.currency}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor(st))),
              if (e.paid > 0)
                Text('/ ${formatAmount(e.amount)}',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DetailPage(s: s, entry: e, onUpdate: onUpdate, onDelete: onDelete),
          )),
        );
      },
    );
  }
}

class AddPage extends StatefulWidget {
  final Str s;
  const AddPage({super.key, required this.s});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _form = GlobalKey<FormState>();
  final _person = TextEditingController();
  final _amount = TextEditingController();
  final _currency = TextEditingController(text: 'EGP');
  final _note = TextEditingController();
  Direction dir = Direction.lent;
  DateTime? due;

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _currency.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.newEntry)),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<Direction>(
            segments: [
              ButtonSegment(value: Direction.lent, label: Text(s.lentLabel)),
              ButtonSegment(value: Direction.borrowed, label: Text(s.borrowedLabel)),
            ],
            selected: {dir},
            onSelectionChanged: (v) => setState(() => dir = v.first),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('f-person'),
            controller: _person,
            decoration: InputDecoration(labelText: s.person),
            validator: (v) => (v == null || v.trim().isEmpty) ? s.required : null,
          ),
          TextFormField(
            key: const ValueKey('f-amount'),
            controller: _amount,
            decoration: InputDecoration(labelText: s.amount),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            validator: (v) {
              final n = double.tryParse(v ?? '');
              return (n == null || n <= 0) ? s.invalidAmount : null;
            },
          ),
          TextFormField(
            controller: _currency,
            decoration: InputDecoration(labelText: s.currency),
            validator: (v) => (v == null || v.trim().isEmpty) ? s.required : null,
          ),
          TextFormField(controller: _note, decoration: InputDecoration(labelText: s.note)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.dueDate),
            subtitle: Text(due == null ? s.noDue : DateFormat('d MMM yyyy').format(due!)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (due != null)
                IconButton(
                    icon: const Icon(Icons.clear), onPressed: () => setState(() => due = null)),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: due ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 10),
                  );
                  if (d != null) setState(() => due = d);
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('save'),
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              final id = await Store.nextId();
              if (!context.mounted) return;
              Navigator.of(context).pop(Entry(
                id: id,
                person: _person.text.trim(),
                amount: double.parse(_amount.text),
                currency: _currency.text.trim().toUpperCase(),
                direction: dir,
                note: _note.text.trim(),
                created: DateTime.now(),
                due: due,
              ));
            },
            child: Text(s.save),
          ),
        ]),
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  final Str s;
  final Entry entry;
  final Future<void> Function(Entry) onUpdate;
  final Future<void> Function(Entry) onDelete;
  const DetailPage({
    super.key,
    required this.s,
    required this.entry,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Entry e = widget.entry;

  Future<void> _addPayment(double amt) async {
    final a = amt > e.remaining ? e.remaining : amt;
    if (a <= 0) return;
    e = e.copyWith(payments: [...e.payments, Payment(a, DateTime.now())]);
    await widget.onUpdate(e);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(title: Text(e.person), actions: [
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(s.confirmDelete),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: Text(s.delete)),
                ],
              ),
            );
            if (ok == true) {
              await widget.onDelete(e);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${formatAmount(e.amount)} ${e.currency}',
            style: Theme.of(context).textTheme.headlineMedium),
        Text(e.direction == Direction.lent ? s.lentLabel : s.borrowedLabel),
        if (e.due != null) Text('${s.dueDate}: ${DateFormat('d MMM yyyy').format(e.due!)}'),
        if (e.note.isNotEmpty) Text(e.note),
        const Divider(),
        Text('${s.paid}: ${formatAmount(e.paid)}'),
        Text('${s.remaining}: ${formatAmount(e.remaining)}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (!e.isSettled) ...[
          FilledButton(
            key: const ValueKey('pay'),
            onPressed: () async {
              final c = TextEditingController();
              final v = await showDialog<double>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text(s.addPayment),
                  content: TextField(
                    controller: c,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: s.amount),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d), child: Text(s.cancel)),
                    TextButton(
                        onPressed: () => Navigator.pop(d, double.tryParse(c.text)),
                        child: Text(s.save)),
                  ],
                ),
              );
              if (v != null) await _addPayment(v);
            },
            child: Text(s.addPayment),
          ),
          OutlinedButton(
            key: const ValueKey('settle'),
            onPressed: () => _addPayment(e.remaining),
            child: Text(s.settleAll),
          ),
        ],
        const SizedBox(height: 12),
        if (e.payments.isNotEmpty) Text(s.payments, style: Theme.of(context).textTheme.titleMedium),
        for (final p in e.payments)
          ListTile(
            dense: true,
            title: Text('${formatAmount(p.amount)} ${e.currency}'),
            trailing: Text(DateFormat('d MMM yyyy').format(p.date)),
          ),
      ]),
    );
  }
}
