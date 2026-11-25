import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class Store {
  static const _k = 'entries_v1';
  static const _kLang = 'ar';
  static const _kNext = 'next_id';

  static Future<List<Entry>> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s == null) return [];
    try {
      return decodeEntries(s);
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Entry> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, encodeEntries(l));
  }

  static Future<int> nextId() async {
    final p = await SharedPreferences.getInstance();
    final n = (p.getInt(_kNext) ?? 1);
    await p.setInt(_kNext, n + 1);
    return n;
  }

  static Future<bool> loadArabic() async =>
      (await SharedPreferences.getInstance()).getBool(_kLang) ?? false;

  static Future<void> saveArabic(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kLang, v);
}
