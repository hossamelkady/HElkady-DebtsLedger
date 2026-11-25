import 'models.dart';

class Str {
  final bool ar;
  const Str(this.ar);

  String get appTitle => ar ? 'دفتر الديون' : 'Debts Ledger';
  String get all => ar ? 'الكل' : 'All';
  String get owedToMe => ar ? 'لي عند الناس' : 'Owed to me';
  String get iOwe => ar ? 'عليّ' : 'I owe';
  String get add => ar ? 'إضافة' : 'Add';
  String get newEntry => ar ? 'دين جديد' : 'New entry';
  String get person => ar ? 'الاسم' : 'Person';
  String get amount => ar ? 'المبلغ' : 'Amount';
  String get currency => ar ? 'العملة' : 'Currency';
  String get note => ar ? 'ملاحظة' : 'Note';
  String get dueDate => ar ? 'تاريخ الاستحقاق' : 'Due date';
  String get noDue => ar ? 'بدون موعد' : 'No due date';
  String get save => ar ? 'حفظ' : 'Save';
  String get cancel => ar ? 'إلغاء' : 'Cancel';
  String get delete => ar ? 'حذف' : 'Delete';
  String get lentLabel => ar ? 'أنا سلّفت' : 'I lent';
  String get borrowedLabel => ar ? 'أنا استلفت' : 'I borrowed';
  String get addPayment => ar ? 'تسجيل دفعة' : 'Record payment';
  String get settleAll => ar ? 'تسوية كاملة' : 'Mark fully paid';
  String get payments => ar ? 'الدفعات' : 'Payments';
  String get remaining => ar ? 'المتبقي' : 'Remaining';
  String get paid => ar ? 'المدفوع' : 'Paid';
  String get empty => ar ? 'لا توجد ديون بعد' : 'No entries yet';
  String get language => ar ? 'English' : 'العربية';
  String get required => ar ? 'مطلوب' : 'Required';
  String get invalidAmount => ar ? 'مبلغ غير صحيح' : 'Invalid amount';
  String get notifPerm => ar ? 'السماح بالتذكيرات' : 'Allow reminders';
  String get reminderTitle => ar ? 'تذكير بدين' : 'Debt reminder';
  String get netLabel => ar ? 'الصافي' : 'Net';
  String get confirmDelete => ar ? 'حذف هذا السجل؟' : 'Delete this entry?';

  String status(Status s) {
    switch (s) {
      case Status.settled:
        return ar ? 'مسدّد' : 'Settled';
      case Status.overdue:
        return ar ? 'متأخر' : 'Overdue';
      case Status.dueSoon:
        return ar ? 'قريب الاستحقاق' : 'Due soon';
      case Status.open:
        return ar ? 'مفتوح' : 'Open';
    }
  }

  String reminderBody(Entry e, String remaining, bool dueToday) {
    final lent = e.direction == Direction.lent;
    if (ar) {
      final when = dueToday ? 'اليوم' : 'غدًا';
      return lent
          ? '${e.person} عليه لك $remaining ${e.currency} يستحق $when'
          : 'عليك لـ ${e.person} مبلغ $remaining ${e.currency} يستحق $when';
    }
    final when = dueToday ? 'today' : 'tomorrow';
    return lent
        ? '${e.person} owes you $remaining ${e.currency}, due $when'
        : 'You owe ${e.person} $remaining ${e.currency}, due $when';
  }
}
