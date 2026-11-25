import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:helkady_debts_ledger/main.dart';
import 'package:helkady_debts_ledger/models.dart';
import 'package:helkady_debts_ledger/reminders.dart';

Entry mk({
  double amount = 100,
  DateTime? due,
  List<Payment> pay = const [],
  Direction dir = Direction.lent,
  String cur = 'EGP',
}) =>
    Entry(
      id: 1,
      person: 'Ali',
      amount: amount,
      currency: cur,
      direction: dir,
      created: DateTime(2026, 11, 1),
      due: due,
      payments: pay,
    );

void main() {
  final now = DateTime(2026, 11, 25, 12);

  test('remaining and settled with partial payments', () {
    final e = mk(pay: [Payment(30, now), Payment(20.5, now)]);
    expect(e.paid, 50.5);
    expect(e.remaining, 49.5);
    expect(e.isSettled, isFalse);
    expect(mk(pay: [Payment(100, now)]).isSettled, isTrue);
    expect(mk(pay: [Payment(99.999, now)]).isSettled, isTrue);
  });

  test('status: overdue, due soon, open, settled', () {
    expect(mk(due: DateTime(2026, 11, 24)).statusOn(now), Status.overdue);
    expect(mk(due: DateTime(2026, 11, 25)).statusOn(now), Status.dueSoon);
    expect(mk(due: DateTime(2026, 11, 28)).statusOn(now), Status.dueSoon);
    expect(mk(due: DateTime(2026, 11, 29)).statusOn(now), Status.open);
    expect(mk().statusOn(now), Status.open);
    expect(mk(due: DateTime(2026, 1, 1), pay: [Payment(100, now)]).statusOn(now),
        Status.settled);
  });

  test('totals per currency ignore settled entries', () {
    final t = totalsByCurrency([
      mk(amount: 100, pay: [Payment(40, now)]),
      mk(amount: 50, dir: Direction.borrowed),
      mk(amount: 10, cur: 'USD'),
      mk(amount: 999, pay: [Payment(999, now)]),
    ]);
    expect(t['EGP']!.owedToMe, 60);
    expect(t['EGP']!.iOwe, 50);
    expect(t['EGP']!.net, 10);
    expect(t['USD']!.owedToMe, 10);
    expect(t.length, 2);
  });

  test('reminder times: day before and due day at 9:00, future only', () {
    final e = mk(due: DateTime(2026, 11, 27));
    expect(reminderTimes(e, now), [DateTime(2026, 11, 26, 9), DateTime(2026, 11, 27, 9)]);
    // Due tomorrow: the "day before" instant (today 9:00) already passed.
    expect(reminderTimes(mk(due: DateTime(2026, 11, 26)), now), [DateTime(2026, 11, 26, 9)]);
    expect(reminderTimes(mk(due: DateTime(2026, 11, 20)), now), isEmpty);
    expect(reminderTimes(mk(), now), isEmpty);
    expect(reminderTimes(mk(due: DateTime(2026, 12, 1), pay: [Payment(100, now)]), now),
        isEmpty);
  });

  test('json round trip', () {
    final e = mk(due: DateTime(2026, 12, 1), pay: [Payment(5, now)]);
    final back = decodeEntries(encodeEntries([e])).single;
    expect(back.person, 'Ali');
    expect(back.due, DateTime(2026, 12, 1));
    expect(back.payments.single.amount, 5);
    expect(back.direction, Direction.lent);
  });

  test('notification ids never collide across entries', () {
    final ids = <int>{};
    for (var i = 1; i < 500; i++) {
      ids..add(idDayBefore(i))..add(idDueDay(i));
    }
    expect(ids.length, 998);
  });

  test('formatAmount trims .00', () {
    expect(formatAmount(10), '10');
    expect(formatAmount(10.5), '10.50');
  });

  testWidgets('empty state shows and totals render with entries', (tester) async {
    await tester.pumpWidget(LedgerApp(entries: const [], arabic: false));
    await tester.pump();
    expect(find.text('No entries yet'), findsWidgets);
    await tester.pumpWidget(LedgerApp(key: const ValueKey('second'), entries: [mk(amount: 250)], arabic: false));
    await tester.pump();
    expect(find.text('Ali'), findsWidgets);
    expect(find.textContaining('250'), findsWidgets);
  });

  testWidgets('Arabic mode uses RTL', (tester) async {
    await tester.pumpWidget(LedgerApp(entries: const [], arabic: true));
    await tester.pump();
    expect(find.text('دفتر الديون'), findsOneWidget);
  });

  testWidgets('add flow: validation, then entry shows with totals', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LedgerApp(entries: [], arabic: false));
    await tester.tap(find.byKey(const ValueKey('add-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Invalid amount'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('f-person')), matching: find.byType(EditableText)), 'Mona');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('f-amount')), matching: find.byType(EditableText)), '1200');
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(find.text('Mona'), findsOneWidget);
    expect(find.textContaining('1200'), findsWidgets);
    // Open detail, record a partial payment via the dialog.
    await tester.tap(find.text('Mona'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pay')), warnIfMissed: true);
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(EditableText)), '200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Remaining: 1000'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settle')));
    await tester.pumpAndSettle();
    expect(find.text('Remaining: 0'), findsOneWidget);
  });
}
