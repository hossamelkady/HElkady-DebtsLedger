import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'strings.dart';

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

Future<void> initReminders() async {
  await _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
}

Future<void> requestReminderPermissions() async {
  final a = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await a?.requestNotificationsPermission();
  await a?.requestExactAlarmsPermission();
}

/// Notification ids: entry id * 2 (day before) and entry id * 2 + 1 (due day).
int idDayBefore(int entryId) => entryId * 2;
int idDueDay(int entryId) => entryId * 2 + 1;

String formatAmount(double v) {
  final s = v.toStringAsFixed(2);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

Future<void> cancelFor(Entry e) async {
  await _plugin.cancel(id: idDayBefore(e.id));
  await _plugin.cancel(id: idDueDay(e.id));
}

Future<void> scheduleFor(Entry e, Str s, {DateTime? now}) async {
  await cancelFor(e);
  final n = now ?? DateTime.now();
  final a = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  final exactOk = await a?.canScheduleExactNotifications() ?? false;
  final mode = exactOk
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;
  final times = reminderTimes(e, n);
  for (final t in times) {
    final isDueDay = t.day == e.due!.day && t.month == e.due!.month && t.year == e.due!.year;
    final body = s.reminderBody(e, formatAmount(e.remaining), isDueDay);
    await _plugin.zonedSchedule(
      id: isDueDay ? idDueDay(e.id) : idDayBefore(e.id),
      title: s.reminderTitle,
      body: body,
      scheduledDate: tz.TZDateTime.from(t, tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'debt_reminders',
          s.reminderTitle,
          channelDescription: s.reminderTitle,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: mode,
    );
  }
}

Future<void> rescheduleAll(List<Entry> all, Str s) async {
  for (final e in all) {
    await scheduleFor(e, s);
  }
}
