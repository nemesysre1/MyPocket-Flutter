import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Jalankan dengan: --dart-define=BACKEND_URL=https://api.domainmu.com --dart-define=APP_TOKEN=xxx
// 10.0.2.2 = localhost komputer jika dijalankan di emulator Android.
const backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://10.0.2.2:5000');
const appToken = String.fromEnvironment('APP_TOKEN');

const incomeCats = ['Gaji', 'Bonus', 'Usaha', 'Lainnya'];
const expenseCats = ['Makanan', 'Minuman', 'Kebutuhan Pokok', 'Transportasi', 'Tagihan', 'Hiburan', 'Belanja', 'Kesehatan', 'Lainnya'];

String rp(num v) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(v);

class Tx {
  final String id, cat, note;
  final bool income;
  final double amount;
  final DateTime date;
  final double? lat, lng;
  Tx({required this.id, required this.income, required this.cat, required this.amount, required this.date, this.note = '', this.lat, this.lng});
  Map<String, dynamic> toJson() => {'id': id, 'income': income, 'cat': cat, 'amount': amount, 'date': date.toIso8601String(), 'note': note, 'lat': lat, 'lng': lng};
  factory Tx.fromJson(Map<String, dynamic> j) => Tx(id: j['id'], income: j['income'], cat: j['cat'], amount: (j['amount'] as num).toDouble(), date: DateTime.parse(j['date']), note: j['note'] ?? '', lat: (j['lat'] as num?)?.toDouble(), lng: (j['lng'] as num?)?.toDouble());
}

class Store extends ChangeNotifier {
  List<Tx> items = [];
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    items = (p.getStringList('tx') ?? []).map((e) => Tx.fromJson(jsonDecode(e))).toList();
    _sort();
    notifyListeners();
  }

  void _sort() => items.sort((a, b) => b.date.compareTo(a.date));
  Future<void> _save() async => (await SharedPreferences.getInstance()).setStringList('tx', items.map((e) => jsonEncode(e.toJson())).toList());

  Future<void> add(Tx t) async {
    items.add(t);
    _sort();
    notifyListeners();
    await _save();
    if (!t.income) {
      for (final i in analyze(items).where((i) => i.cat == t.cat)) {
        notify(i);
      }
    }
  }

  Future<void> remove(String id) async {
    items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save();
  }
}

final store = Store();

// Switch asisten AI: mati = mode offline, tidak ada data dikirim ke server.
final aiOn = ValueNotifier<bool>(false);
Future<void> loadAi() async => aiOn.value = (await SharedPreferences.getInstance()).getBool('ai_on') ?? false;
Future<void> setAi(bool v) async {
  aiOn.value = v;
  await (await SharedPreferences.getInstance()).setBool('ai_on', v);
}

// Alamat server bisa diganti dari dalam aplikasi (tersimpan di HP).
final serverUrl = ValueNotifier<String>(backendUrl);
String normUrl(String v) {
  v = v.trim().replaceAll(RegExp(r'/+$'), '');
  if (v.endsWith('/chat')) v = v.substring(0, v.length - 5);
  if (v.isNotEmpty && !v.startsWith('http')) v = 'https://$v';
  return v;
}

Future<void> loadServer() async {
  final v = (await SharedPreferences.getInstance()).getString('server_url');
  if (v != null && v.isNotEmpty) serverUrl.value = v;
}

Future<void> setServer(String v) async {
  v = normUrl(v);
  serverUrl.value = v.isEmpty ? backendUrl : v;
  await (await SharedPreferences.getInstance()).setString('server_url', v);
}

Future<bool> testServer(String v) async {
  try {
    final r = await http.get(Uri.parse('${normUrl(v)}/health')).timeout(const Duration(seconds: 8));
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

// ---------- Analisis pengeluaran ----------
class Insight {
  final String cat, title, body;
  final bool risk;
  Insight(this.cat, this.title, this.body, this.risk);
}

List<Insight> analyze(List<Tx> all) {
  final now = DateTime.now(), res = <Insight>[];
  final inc30 = all.where((t) => t.income && now.difference(t.date).inDays < 30).fold(0.0, (s, t) => s + t.amount);
  final by = <String, List<Tx>>{};
  for (final t in all.where((t) => !t.income)) {
    by.putIfAbsent(t.cat, () => []).add(t); // sudah terurut terbaru dulu
  }
  by.forEach((c, l) {
    final latest = l.first, prev = l.skip(1).toList();
    if (now.difference(latest.date).inDays <= 3) {
      if (prev.length >= 3) {
        final avg = prev.fold(0.0, (s, t) => s + t.amount) / prev.length;
        if (latest.amount > avg * 2) {
          res.add(Insight(c, 'Di luar kebiasaan', '$c ${rp(latest.amount)} jauh di atas rata-rata biasanya (${rp(avg)}).', false));
        }
      } else if (prev.isEmpty && latest.amount >= 200000) {
        res.add(Insight(c, 'Pengeluaran baru', 'Belum pernah ada pengeluaran $c sebelumnya, kali ini ${rp(latest.amount)}.', false));
      }
    }
    final last = l.where((t) => now.difference(t.date).inDays < 30).toList();
    final sum = last.fold(0.0, (s, t) => s + t.amount);
    final limit = inc30 > 0 ? inc30 * 0.15 : 500000;
    if (last.length >= 4 && sum >= limit) {
      res.add(Insight(c, 'Berpotensi membebani', '$c muncul ${last.length}x dalam 30 hari (${rp(sum)}). Bila terus berlanjut, setara ${rp(sum * 12)} per tahun.', true));
    }
  });
  return res;
}

String aiContext(List<Tx> all) {
  final now = DateTime.now();
  final l = all.where((t) => now.difference(t.date).inDays < 30);
  final inc = l.where((t) => t.income).fold(0.0, (s, t) => s + t.amount);
  final per = <String, double>{};
  for (final t in l.where((t) => !t.income)) {
    per[t.cat] = (per[t.cat] ?? 0) + t.amount;
  }
  return 'Data 30 hari terakhir. Pemasukan: ${rp(inc)}. Pengeluaran per kategori: ${per.entries.map((e) => '${e.key} ${rp(e.value)}').join(', ')}. '
      'Temuan: ${analyze(all).map((i) => i.body).join(' | ')}';
}

// ---------- Asisten AI (lewat backend Flask, key Groq tidak ada di aplikasi) ----------
Future<String> askGroq(List<Map<String, String>> history, String ctx) async {
  if (!aiOn.value) return 'Asisten AI sedang dinonaktifkan.';
  try {
    final r = await http
        .post(Uri.parse('${serverUrl.value}/chat'),
            headers: {'Content-Type': 'application/json', 'X-App-Token': appToken},
            body: jsonEncode({'messages': history, 'context': ctx}))
        .timeout(const Duration(seconds: 40));
    if (r.statusCode != 200) return 'Server asisten bermasalah (kode ${r.statusCode}).';
    return jsonDecode(utf8.decode(r.bodyBytes))['reply'];
  } catch (_) {
    return 'Tidak bisa terhubung ke server. Periksa koneksi atau alamat BACKEND_URL.';
  }
}

// ---------- Lokasi & notifikasi ----------
Future<Position?> locate() async {
  try {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition();
  } catch (_) {
    return null;
  }
}

final _np = FlutterLocalNotificationsPlugin();
Future<void> initNotif() async {
  await _np.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()));
  await _np.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
}

void notify(Insight i) => _np.show(i.body.hashCode, i.title, i.body,
    const NotificationDetails(android: AndroidNotificationDetails('pengingat', 'Pengingat', importance: Importance.high, priority: Priority.high), iOS: DarwinNotificationDetails()));
