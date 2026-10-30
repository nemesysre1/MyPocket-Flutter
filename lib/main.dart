import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';
import 'services.dart';

const ink = Color(0xFF1E2D2A), paper = Color(0xFFF5F3EE), line = Color(0xFFE2DED3), green = Color(0xFF2F6B4F), brick = Color(0xFFA4452C);
const icons = {
  'Gaji': Icons.payments_outlined, 'Bonus': Icons.card_giftcard, 'Usaha': Icons.storefront_outlined,
  'Makanan': Icons.restaurant_outlined, 'Minuman': Icons.local_cafe_outlined, 'Kebutuhan Pokok': Icons.shopping_basket_outlined,
  'Transportasi': Icons.directions_bus_outlined, 'Tagihan': Icons.receipt_long_outlined, 'Hiburan': Icons.movie_outlined,
  'Belanja': Icons.shopping_bag_outlined, 'Kesehatan': Icons.medical_services_outlined,
};
BoxDecoration box() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await initNotif();
  await store.load();
  await loadAi();
  await loadServer();
  runApp(const MyPocketApp());
}

class MyPocketApp extends StatelessWidget {
  const MyPocketApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MyPocket',
        debugShowCheckedModeBanner: false,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.light(primary: ink, onPrimary: Colors.white, surface: paper, onSurface: ink, secondary: brick),
          scaffoldBackgroundColor: paper,
          appBarTheme: const AppBarTheme(backgroundColor: paper, elevation: 0, scrolledUnderElevation: 0, foregroundColor: ink),
          navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: line, elevation: 0),
          dividerColor: line,
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: i, children: const [Home(), CalendarPage(), MapPage(), ChatPage()]),
        floatingActionButton: i == 3
            ? null
            : FloatingActionButton.extended(
                backgroundColor: ink, foregroundColor: Colors.white, elevation: 0,
                onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: paper, builder: (_) => const AddSheet()),
                icon: const Icon(Icons.add), label: const Text('Catat')),
        bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: (v) => setState(() => i = v), destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Kalender'),
          NavigationDestination(icon: Icon(Icons.place_outlined), label: 'Peta'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Asisten'),
        ]),
      );
}

class TxTile extends StatelessWidget {
  final Tx t;
  const TxTile(this.t, {super.key});
  @override
  Widget build(BuildContext context) => Dismissible(
        key: ValueKey(t.id),
        onDismissed: (_) => store.remove(t.id),
        background: Container(color: brick.withOpacity(.15)),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: line, foregroundColor: ink, child: Icon(icons[t.cat] ?? Icons.more_horiz, size: 20)),
          title: Text(t.cat, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${DateFormat('d MMM', 'id_ID').format(t.date)}${t.note.isEmpty ? '' : '  ·  ${t.note}'}'),
          trailing: Text('${t.income ? '+' : '-'} ${rp(t.amount)}', style: TextStyle(color: t.income ? green : brick, fontWeight: FontWeight.w600)),
        ),
      );
}

class Home extends StatelessWidget {
  const Home({super.key});
  Widget mini(String l, double v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 12)), const SizedBox(height: 2),
        Text(rp(v), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]));
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (c, _) {
          final now = DateTime.now();
          final m = store.items.where((t) => t.date.year == now.year && t.date.month == now.month);
          final inc = m.where((t) => t.income).fold(0.0, (s, t) => s + t.amount);
          final out = m.where((t) => !t.income).fold(0.0, (s, t) => s + t.amount);
          final bal = store.items.fold(0.0, (s, t) => s + (t.income ? t.amount : -t.amount));
          final tips = analyze(store.items);
          return SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: [
              Text(DateFormat('MMMM yyyy', 'id_ID').format(now), style: TextStyle(color: ink.withOpacity(.55))),
              const Text('Keuangan', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Saldo', style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 4),
                  Text(rp(bal), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  Row(children: [mini('Masuk bulan ini', inc), mini('Keluar bulan ini', out)]),
                ]),
              ),
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Perlu diperhatikan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final i in tips)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: box(),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(i.risk ? Icons.trending_up : Icons.error_outline, color: brick, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(i.title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(i.body),
                      ])),
                    ]),
                  ),
              ],
              const SizedBox(height: 20),
              const Text('Transaksi terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (store.items.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('Belum ada transaksi. Ketuk Catat untuk memulai.')),
              ...store.items.take(30).map(TxTile.new),
            ]),
          );
        },
      );
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime day = DateTime.now();
  List<Tx> on(DateTime d) => store.items.where((t) => isSameDay(t.date, d)).toList();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (c, _) {
          final list = on(day);
          return SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 100), children: [
              TableCalendar<Tx>(
                locale: 'id_ID', firstDay: DateTime(2020), lastDay: DateTime(2100), focusedDay: day,
                startingDayOfWeek: StartingDayOfWeek.monday,
                selectedDayPredicate: (d) => isSameDay(d, day),
                onDaySelected: (s, _) => setState(() => day = s),
                eventLoader: on,
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                calendarStyle: const CalendarStyle(
                  selectedDecoration: BoxDecoration(color: ink, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: line, shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: ink),
                  markerDecoration: BoxDecoration(color: brick, shape: BoxShape.circle),
                ),
              ),
              const Divider(height: 28),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DateFormat('EEEE, d MMMM', 'id_ID').format(day), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Tidak ada transaksi.')),
                ...list.map(TxTile.new),
              ])),
            ]),
          );
        },
      );
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (c, _) {
          final pts = store.items.where((t) => !t.income && t.lat != null).toList();
          return FlutterMap(
            options: MapOptions(initialCenter: pts.isEmpty ? const LatLng(-2.5, 118) : LatLng(pts.first.lat!, pts.first.lng!), initialZoom: pts.isEmpty ? 4.5 : 14),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.mypocket.app'),
              MarkerLayer(markers: [
                for (final t in pts)
                  Marker(
                    point: LatLng(t.lat!, t.lng!), width: 40, height: 40,
                    child: GestureDetector(
                      onTap: () => showModalBottomSheet(context: c, builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [TxTile(t)]))),
                      child: const Icon(Icons.location_on, color: brick, size: 36),
                    ),
                  ),
              ]),
            ],
          );
        },
      );
}

class AddSheet extends StatefulWidget {
  const AddSheet({super.key});
  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  bool inc = false, loc = true, busy = false;
  String cat = 'Makanan';
  DateTime date = DateTime.now();
  final amt = TextEditingController(), note = TextEditingController();

  Future<void> save() async {
    final a = double.tryParse(amt.text.replaceAll('.', ''));
    if (a == null || a <= 0) return;
    setState(() => busy = true);
    final p = (loc && !inc) ? await locate() : null;
    await store.add(Tx(id: DateTime.now().microsecondsSinceEpoch.toString(), income: inc, cat: cat, amount: a, date: date, note: note.text.trim(), lat: p?.latitude, lng: p?.longitude));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cats = inc ? incomeCats : expenseCats;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: false, label: Text('Pengeluaran')), ButtonSegment(value: true, label: Text('Pemasukan'))],
            selected: {inc},
            onSelectionChanged: (s) => setState(() { inc = s.first; cat = (inc ? incomeCats : expenseCats).first; }),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final c in cats)
              ChoiceChip(label: Text(c), selected: cat == c, onSelected: (_) => setState(() => cat = c), selectedColor: ink, labelStyle: TextStyle(color: cat == c ? Colors.white : ink), showCheckmark: false, side: const BorderSide(color: line)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder())),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_outlined), title: Text(DateFormat('d MMMM yyyy', 'id_ID').format(date)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => date = d);
            },
          ),
          if (!inc) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Catat lokasi saat ini'), value: loc, activeColor: ink, onChanged: (v) => setState(() => loc = v)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : save, style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)), child: Text(busy ? 'Menyimpan...' : 'Simpan'))),
        ]),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final msgs = <Map<String, String>>[];
  final c = TextEditingController();
  bool wait = false;

  Future<void> send([String? q]) async {
    final t = (q ?? c.text).trim();
    if (t.isEmpty || wait) return;
    c.clear();
    setState(() { msgs.add({'role': 'user', 'content': t}); wait = true; });
    final r = await askGroq(msgs, aiContext(store.items));
    if (mounted) setState(() { msgs.add({'role': 'assistant', 'content': r}); wait = false; });
  }

  Widget online() => Column(children: [
        Expanded(
          child: msgs.isEmpty
              ? Padding(padding: const EdgeInsets.all(20), child: Wrap(spacing: 8, children: [
                  for (final q in ['Analisis pengeluaran saya bulan ini', 'Bagaimana cara berhemat?', 'Berapa dana darurat yang ideal?'])
                    ActionChip(label: Text(q), onPressed: () => send(q), backgroundColor: Colors.white, side: const BorderSide(color: line)),
                ]))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final m in msgs)
                    Align(
                      alignment: m['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                        decoration: m['role'] == 'user' ? BoxDecoration(color: ink, borderRadius: BorderRadius.circular(14)) : box(),
                        child: Text(m['content']!, style: TextStyle(color: m['role'] == 'user' ? Colors.white : ink)),
                      ),
                    ),
                  if (wait) const Padding(padding: EdgeInsets.all(8), child: Text('Menulis...')),
                ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(children: [
            Expanded(child: TextField(controller: c, onSubmitted: (_) => send(), decoration: InputDecoration(hintText: 'Tanyakan soal keuanganmu', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: line))))),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: () => send(), style: IconButton.styleFrom(backgroundColor: ink), icon: const Icon(Icons.arrow_upward)),
          ]),
        ),
      ]);

  Widget offline() => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final now = DateTime.now();
          final per = <String, double>{};
          for (final t in store.items.where((t) => !t.income && now.difference(t.date).inDays < 30)) {
            per[t.cat] = (per[t.cat] ?? 0) + t.amount;
          }
          final top = per.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final tips = analyze(store.items);
          return ListView(padding: const EdgeInsets.all(20), children: [
            Container(padding: const EdgeInsets.all(14), decoration: box(), child: const Text('Mode offline. Chat AI nonaktif dan tidak ada data yang dikirim ke server. Analisis dan pengingat tetap berjalan di perangkat ini.')),
            const SizedBox(height: 20),
            const Text('Pengeluaran terbesar 30 hari', style: TextStyle(fontWeight: FontWeight.w700)),
            if (top.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Belum ada data.')),
            for (final e in top.take(3)) ListTile(contentPadding: EdgeInsets.zero, title: Text(e.key), trailing: Text(rp(e.value), style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
            const Text('Temuan', style: TextStyle(fontWeight: FontWeight.w700)),
            if (tips.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Belum ada temuan.')),
            for (final i in tips) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(i.risk ? Icons.trending_up : Icons.error_outline, color: brick), title: Text(i.title), subtitle: Text(i.body)),
          ]);
        },
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              const Expanded(child: Text('Asisten', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'Alamat server', onPressed: () => editServer(context), icon: const Icon(Icons.dns_outlined)),
              ValueListenableBuilder<bool>(
                valueListenable: aiOn,
                builder: (_, on, __) => Row(children: [
                  Text(on ? 'AI aktif' : 'Offline', style: TextStyle(color: ink.withOpacity(.6))),
                  Switch(value: on, activeColor: ink, onChanged: setAi),
                ]),
              ),
            ]),
          ),
          Expanded(child: ValueListenableBuilder<bool>(valueListenable: aiOn, builder: (_, on, __) => on ? online() : offline())),
        ]),
      );
}

Future<void> editServer(BuildContext context) async {
  final ctl = TextEditingController(text: serverUrl.value);
  String? status;
  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: paper,
        title: const Text('Alamat server'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: ctl, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://namamu.trycloudflare.com', border: OutlineInputBorder())),
          if (status != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(status!)),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              set(() => status = 'Menguji...');
              final ok = await testServer(ctl.text);
              set(() => status = ok ? 'Terhubung.' : 'Tidak dapat terhubung. Periksa alamat dan pastikan server menyala.');
            },
            child: const Text('Tes koneksi'),
          ),
          FilledButton(
            onPressed: () async {
              await setServer(ctl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}
