# HElkady-DebtsLedger

Android app (Flutter): a ledger for money you lent and money you borrowed, with due-date reminders.
تطبيق أندرويد (فلاتر): دفتر لما أقرضته وما اقترضته، مع تذكير بمواعيد الاستحقاق.

## English
- Add entries: who, amount, currency, note, optional due date, and whether you lent or borrowed.
- Record partial payments or mark an entry fully paid. Settled entries move to the bottom.
- Totals per currency: owed to you, you owe, net. Status: open, due soon (3 days), overdue, settled.
- Reminders at 9:00 the day before and on the due date (cancelled once settled or deleted).
- English and Arabic UI. Works offline. Data stays on the phone.

Build: `flutter pub get && flutter test && flutter build apk --debug` (Flutter 3.50, JDK 21, Android SDK 37).

Tested: unit tests for balances, status, totals, reminder times, storage format, and a UI test of the add, pay and settle flow. Not tested on a real device: notification delivery.

## العربية
- أضف سجلًا: الاسم، المبلغ، العملة، ملاحظة، موعد استحقاق اختياري، وهل أقرضت أم اقترضت.
- سجّل دفعات جزئية أو سدّد كامل المبلغ. السجلات المسدّدة تنزل لآخر القائمة.
- إجماليات لكل عملة: لك، عليك، الصافي. الحالات: مفتوح، قريب الاستحقاق (3 أيام)، متأخر، مسدّد.
- تذكير الساعة 9:00 قبل الاستحقاق بيوم وفي يوم الاستحقاق (يُلغى عند السداد أو الحذف).
- واجهة بالعربية والإنجليزية. يعمل بدون إنترنت. البيانات تبقى على الهاتف.
