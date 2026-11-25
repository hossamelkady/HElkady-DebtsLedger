import 'dart:convert';

enum Direction { lent, borrowed } // lent: they owe me. borrowed: I owe them.

enum Status { settled, overdue, dueSoon, open }

class Payment {
  final double amount;
  final DateTime date;
  const Payment(this.amount, this.date);

  Map<String, dynamic> toJson() => {'a': amount, 'd': date.toIso8601String()};
  factory Payment.fromJson(Map<String, dynamic> j) =>
      Payment((j['a'] as num).toDouble(), DateTime.parse(j['d'] as String));
}

class Entry {
  final int id;
  final String person;
  final double amount;
  final String currency;
  final Direction direction;
  final String note;
  final DateTime created;
  final DateTime? due; // date only (time ignored)
  final List<Payment> payments;

  const Entry({
    required this.id,
    required this.person,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.created,
    this.note = '',
    this.due,
    this.payments = const [],
  });

  double get paid => payments.fold(0.0, (s, p) => s + p.amount);
  double get remaining {
    final r = amount - paid;
    return r < 0.005 ? 0 : r;
  }

  bool get isSettled => remaining == 0;

  Status statusOn(DateTime now, {int soonDays = 3}) {
    if (isSettled) return Status.settled;
    final d = due;
    if (d == null) return Status.open;
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    if (dd.isBefore(today)) return Status.overdue;
    if (dd.difference(today).inDays <= soonDays) return Status.dueSoon;
    return Status.open;
  }

  Entry copyWith({List<Payment>? payments, DateTime? due, bool clearDue = false}) =>
      Entry(
        id: id,
        person: person,
        amount: amount,
        currency: currency,
        direction: direction,
        created: created,
        note: note,
        due: clearDue ? null : (due ?? this.due),
        payments: payments ?? this.payments,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'p': person,
        'a': amount,
        'c': currency,
        'dir': direction.name,
        'n': note,
        'cr': created.toIso8601String(),
        'due': due?.toIso8601String(),
        'pay': payments.map((e) => e.toJson()).toList(),
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'] as int,
        person: j['p'] as String,
        amount: (j['a'] as num).toDouble(),
        currency: j['c'] as String,
        direction: Direction.values.byName(j['dir'] as String),
        note: (j['n'] as String?) ?? '',
        created: DateTime.parse(j['cr'] as String),
        due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
        payments: ((j['pay'] as List?) ?? const [])
            .map((e) => Payment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

String encodeEntries(List<Entry> l) =>
    jsonEncode(l.map((e) => e.toJson()).toList());

List<Entry> decodeEntries(String s) => (jsonDecode(s) as List)
    .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
    .toList();

/// Totals of unsettled balances per currency.
class Totals {
  final double owedToMe;
  final double iOwe;
  const Totals(this.owedToMe, this.iOwe);
  double get net => owedToMe - iOwe;
}

Map<String, Totals> totalsByCurrency(List<Entry> entries) {
  final m = <String, List<double>>{};
  for (final e in entries) {
    if (e.isSettled) continue;
    final t = m.putIfAbsent(e.currency, () => [0, 0]);
    if (e.direction == Direction.lent) {
      t[0] += e.remaining;
    } else {
      t[1] += e.remaining;
    }
  }
  return m.map((k, v) => MapEntry(k, Totals(v[0], v[1])));
}

/// Reminder instants for [e]: 9:00 local the day before the due date and 9:00
/// on the due date. Only future instants of unsettled entries are returned.
List<DateTime> reminderTimes(Entry e, DateTime now, {int hour = 9}) {
  final d = e.due;
  if (d == null || e.isSettled) return const [];
  final day = DateTime(d.year, d.month, d.day);
  final out = <DateTime>[
    DateTime(day.year, day.month, day.day - 1, hour),
    DateTime(day.year, day.month, day.day, hour),
  ];
  return out.where((t) => t.isAfter(now)).toList();
}
