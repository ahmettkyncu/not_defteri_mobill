import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';

import 'NotificationService.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('notlar_kutusu');
  await Hive.openBox('ayarlar');

  await NotificationService.instance.init();

  runApp(const NotUygulamasi());
}

class NotUygulamasi extends StatefulWidget {
  const NotUygulamasi({super.key});

  @override
  State<NotUygulamasi> createState() => _NotUygulamasiState();
}

class _NotUygulamasiState extends State<NotUygulamasi> {
  final _ayarlarKutusu = Hive.box('ayarlar');
  late bool _darkMi;

  @override
  void initState() {
    super.initState();
    _darkMi = _ayarlarKutusu.get('dark_mode', defaultValue: true);
  }

  void _temaDegistir(bool val) {
    setState(() => _darkMi = val);
    _ayarlarKutusu.put('dark_mode', val);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme:
          const AppBarTheme(backgroundColor: Colors.black, elevation: 0),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFFC107),
        foregroundColor: Colors.black,
      ),
      bottomSheetTheme:
          const BottomSheetThemeData(backgroundColor: Color(0xFF1F1F1F)),
    );

    final ThemeData lightTheme = ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme:
          const AppBarTheme(backgroundColor: Colors.white, elevation: 0),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFFC107),
        foregroundColor: Colors.black,
      ),
      bottomSheetTheme:
          const BottomSheetThemeData(backgroundColor: Colors.white),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pro Not Defteri',
      theme: _darkMi ? darkTheme : lightTheme,
      home: AnaSayfa(
        darkMi: _darkMi,
        onThemeChanged: _temaDegistir,
      ),
    );
  }
}

// -------------------- ANA SAYFA --------------------
class AnaSayfa extends StatefulWidget {
  final bool darkMi;
  final void Function(bool) onThemeChanged;

  const AnaSayfa(
      {super.key, required this.darkMi, required this.onThemeChanged});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final _notKutusu = Hive.box('notlar_kutusu');
  final _ayarlarKutusu = Hive.box('ayarlar');

  String _aramaMetni = "";
  bool _gizliModAcik = false;

  Future<void> _kasaIslemleri() async {
    String? kayitliSifre = _ayarlarKutusu.get('kasa_sifresi');
    if (kayitliSifre == null) {
      await _sifreOlustur();
    } else {
      await _sifreSor(kayitliSifre);
    }
  }

  Future<void> _sifreOlustur() async {
    final pass1 = TextEditingController();
    final pass2 = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text("🆕 Kasa Kurulumu",
            style: TextStyle(color: Colors.orange)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Gizli kasanızı kullanmak için lütfen bir şifre belirleyin.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: pass1,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Şifre",
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
              ),
            ),
            TextField(
              controller: pass2,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Şifre Tekrar",
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              if (pass1.text.isNotEmpty && pass1.text == pass2.text) {
                _ayarlarKutusu.put('kasa_sifresi', pass1.text);
                Navigator.pop(context);

                setState(() => _gizliModAcik = true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("✅ Şifre Oluşturuldu! Kasa Açık."),
                  backgroundColor: Colors.green,
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Şifreler eşleşmiyor veya boş!"),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text("Oluştur", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sifreSor(String dogruSifre) async {
    final girilenSifre = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title:
            const Text("🔒 Gizli Kasa", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: girilenSifre,
          keyboardType: TextInputType.number,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Şifrenizi girin",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              if (girilenSifre.text == dogruSifre) {
                setState(() => _gizliModAcik = !_gizliModAcik);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      _gizliModAcik ? "🔓 Kasa AÇILDI" : "🔒 Kasa KAPANDI"),
                  backgroundColor: _gizliModAcik ? Colors.green : Colors.red,
                ));
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Hatalı Şifre!"),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text("Giriş", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sifreDegistir() async {
    final eski = TextEditingController();
    final yeni = TextEditingController();
    final String? mevcut = _ayarlarKutusu.get('kasa_sifresi');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title:
            const Text("Şifre Değiştir", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: eski,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  hintText: "Eski Şifre",
                  hintStyle: TextStyle(color: Colors.grey)),
            ),
            TextField(
              controller: yeni,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  hintText: "Yeni Şifre",
                  hintStyle: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              if (eski.text == mevcut && yeni.text.isNotEmpty) {
                _ayarlarKutusu.put('kasa_sifresi', yeni.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Şifre Değişti!"),
                  backgroundColor: Colors.green,
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Eski şifre yanlış!"),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _notuTasi(int index, Map notData, bool gizle) {
    final yeniVeri = Map<String, dynamic>.from(notData);
    yeniVeri['gizli'] = gizle;
    _notKutusu.putAt(index, yeniVeri);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(gizle ? "Kilitlendi 🔒" : "Kilidi Açıldı 🔓"),
      backgroundColor: Colors.blue,
      duration: const Duration(milliseconds: 800),
    ));
  }

  Color _yaziRenginiBul(Color arkaplan) =>
      arkaplan.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  String _tarihFormatla(String? t) {
    if (t == null) return "";
    try {
      final d = DateTime.parse(t);
      return "${d.day}.${d.month}.${d.year}";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("Ayarlar",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary:
                    Icon(widget.darkMi ? Icons.dark_mode : Icons.light_mode),
                title: const Text("Tema"),
                subtitle: Text(widget.darkMi ? "Koyu (Siyah)" : "Açık (Beyaz)"),
                value: widget.darkMi,
                onChanged: (val) => widget.onThemeChanged(val),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: const Text("Tüm Notları Sil"),
                onTap: () async {
                  // Not: istersen burada tüm bildirimleri de iptal edebiliriz.
                  await _notKutusu.clear();
                  if (mounted) Navigator.pop(context);
                },
              ),
              if (_gizliModAcik) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password, color: Colors.orange),
                  title: const Text("Gizli Kasa Şifresini Değiştir"),
                  onTap: () {
                    Navigator.pop(context);
                    _sifreDegistir();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      appBar: _gizliModAcik
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _gizliModAcik = false),
              ),
              title: const Text("🔒 Gizli Kasa",
                  style: TextStyle(color: Colors.green)),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu, color: Colors.grey),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (!_gizliModAcik)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                onChanged: (value) => setState(
                                    () => _aramaMetni = value.toLowerCase()),
                                decoration: const InputDecoration(
                                  hintText: "Notlarda ara...",
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFFFC107),
                backgroundColor: Colors.black,
                onRefresh: () async {
                  if (!_gizliModAcik) await _kasaIslemleri();
                },
                child: ValueListenableBuilder(
                  valueListenable: _notKutusu.listenable(),
                  builder: (context, box, _) {
                    final tumNotlar = box.values.toList();
                    final Map<int, Map> filtrelenmisNotlar = {};

                    for (int i = 0; i < tumNotlar.length; i++) {
                      final veri =
                          Map<String, dynamic>.from(tumNotlar[i] as Map);
                      final bool notGizliMi = veri['gizli'] ?? false;

                      if (_gizliModAcik) {
                        if (notGizliMi) filtrelenmisNotlar[i] = veri;
                      } else {
                        if (!notGizliMi) filtrelenmisNotlar[i] = veri;
                      }
                    }

                    var gosterilecekIndexler = filtrelenmisNotlar.keys.toList();

                    if (_aramaMetni.isNotEmpty) {
                      gosterilecekIndexler = gosterilecekIndexler.where((idx) {
                        final not = filtrelenmisNotlar[idx]!;
                        final baslik =
                            (not['baslik'] ?? "").toString().toLowerCase();

                        final detayli =
                            (not['detayli_satirlar'] as List? ?? []);
                        final metin = detayli
                            .where((s) => (s is Map) && s['tip'] == 'metin')
                            .map((s) => (s['text'] ?? "").toString())
                            .join(' ')
                            .toLowerCase();

                        return baslik.contains(_aramaMetni) ||
                            metin.contains(_aramaMetni);
                      }).toList();
                    }

                    gosterilecekIndexler.sort((a, b) {
                      final notA = filtrelenmisNotlar[a]!;
                      final notB = filtrelenmisNotlar[b]!;
                      return (notB['tarih'] ?? "")
                          .toString()
                          .compareTo((notA['tarih'] ?? "").toString());
                    });

                    if (gosterilecekIndexler.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _gizliModAcik
                                  ? Icons.lock_outline
                                  : Icons.note_alt_outlined,
                              size: 60,
                              color: Colors.grey.shade800,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _gizliModAcik
                                  ? "Kasa Boş"
                                  : "Not listeniz boş\n(Gizli kasa için aşağı çek)",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    }

                    return MasonryGridView.count(
                      padding: const EdgeInsets.all(10),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      itemCount: gosterilecekIndexler.length,
                      itemBuilder: (context, listIndex) {
                        final gercekIndex = gosterilecekIndexler[listIndex];
                        final not = filtrelenmisNotlar[gercekIndex]!;
                        final renkKodu = not['renk'] ?? 0xFF1F1F1F;
                        final kartRengi = Color(renkKodu);
                        final yaziRengi = _yaziRenginiBul(kartRengi);

                        final detayliSatirlar =
                            (not['detayli_satirlar'] as List? ?? []);
                        final resimSayisi = detayliSatirlar
                            .where((s) => (s is Map) && s['tip'] == 'resim')
                            .length;

                        final reminderStr =
                            (not['reminderAt'] ?? "").toString();
                        final hasReminder = reminderStr.isNotEmpty;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NotEkleSayfasi(
                                  mevcutNot: not,
                                  notKey: gercekIndex,
                                  otomatikGizli: _gizliModAcik,
                                ),
                              ),
                            );
                          },
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => Container(
                                height: 120,
                                color: const Color(0xFF1F1F1F),
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: Icon(
                                        _gizliModAcik
                                            ? Icons.lock_open
                                            : Icons.lock,
                                        color: Colors.yellow,
                                      ),
                                      title: Text(
                                        _gizliModAcik
                                            ? "Notu Kasadan Çıkar"
                                            : "Notu Gizli Kasaya Taşı",
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _notuTasi(
                                            gercekIndex, not, !_gizliModAcik);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete,
                                          color: Colors.red),
                                      title: const Text("Notu Sil",
                                          style:
                                              TextStyle(color: Colors.white)),
                                      onTap: () async {
                                        Navigator.pop(ctx);

                                        final existing =
                                            _notKutusu.getAt(gercekIndex);
                                        final nid = existing?['notificationId'];
                                        if (nid != null) {
                                          await NotificationService.instance
                                              .cancel(nid as int);
                                        }

                                        _notKutusu.deleteAt(gercekIndex);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: kartRengi,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (not["baslik"] ?? "").toString(),
                                        style: TextStyle(
                                          color: yaziRengi,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (hasReminder)
                                      Icon(Icons.alarm,
                                          size: 16,
                                          color: yaziRengi.withOpacity(0.7)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (detayliSatirlar.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: detayliSatirlar
                                        .take(5)
                                        .map<Widget>((s) {
                                      if (s is! Map)
                                        return const SizedBox.shrink();

                                      if (s['tip'] == 'resim') {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 4.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.image,
                                                  size: 16,
                                                  color: yaziRengi
                                                      .withOpacity(0.7)),
                                              const SizedBox(width: 4),
                                              Text("(Resim)",
                                                  style: TextStyle(
                                                      color: yaziRengi
                                                          .withOpacity(0.7),
                                                      fontSize: 12)),
                                            ],
                                          ),
                                        );
                                      }

                                      final isBox =
                                          (s['isCheckbox'] ?? false) as bool;
                                      final isChecked =
                                          (s['isChecked'] ?? false) as bool;
                                      final text = (s['text'] ?? "").toString();

                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          children: [
                                            if (isBox)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 6.0),
                                                child: Icon(
                                                  isChecked
                                                      ? Icons.check_box
                                                      : Icons
                                                          .check_box_outline_blank,
                                                  size: 16,
                                                  color: yaziRengi
                                                      .withOpacity(0.7),
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                text,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isChecked
                                                      ? yaziRengi
                                                          .withOpacity(0.4)
                                                      : yaziRengi
                                                          .withOpacity(0.7),
                                                  fontSize: 14,
                                                  decoration: isChecked
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                  decorationColor: yaziRengi
                                                      .withOpacity(0.4),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                if (resimSayisi > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.image,
                                            size: 14, color: Colors.white70),
                                        Text(" $resimSayisi ",
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  _tarihFormatla(
                                      (not["tarih"] ?? "").toString()),
                                  style: TextStyle(
                                      color: yaziRengi.withOpacity(0.5),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          backgroundColor:
              _gizliModAcik ? Colors.green : const Color(0xFFFFC107),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => NotEkleSayfasi(otomatikGizli: _gizliModAcik)),
          ),
          child: Icon(Icons.add,
              size: 32, color: _gizliModAcik ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}

// -------------------- NOT EKLE / DÜZENLE --------------------
class NotEkleSayfasi extends StatefulWidget {
  final Map? mevcutNot;
  final int? notKey;
  final bool otomatikGizli;

  const NotEkleSayfasi(
      {super.key, this.mevcutNot, this.notKey, this.otomatikGizli = false});

  @override
  State<NotEkleSayfasi> createState() => _NotEkleSayfasiState();
}

class _NotEkleSayfasiState extends State<NotEkleSayfasi> {
  final TextEditingController _baslikController = TextEditingController();
  final _notKutusu = Hive.box('notlar_kutusu');
  final SpeechToText _speechToText = SpeechToText();

  final List<NotSatiri> _satirlar = [];

  bool _dinliyorMu = false;
  String _geciciYazi = "";
  int _secilenRenk = 0xFF1F1F1F;
  bool _sabitMi = false;
  bool _gizliMi = false;

  // Hatırlatıcı alanları (merge)
  DateTime? _reminderDateTime;
  int? _notificationId;

  @override
  void initState() {
    super.initState();
    _mikrofonuHazirla();

    _gizliMi = widget.otomatikGizli;

    if (widget.mevcutNot != null) {
      _baslikController.text = (widget.mevcutNot!['baslik'] ?? "").toString();
      _secilenRenk = widget.mevcutNot!['renk'] ?? 0xFF1F1F1F;
      _sabitMi = widget.mevcutNot!['sabit'] ?? false;
      _gizliMi = widget.mevcutNot!['gizli'] ?? false;

      // Hatırlatıcı yükle
      final reminderStr = widget.mevcutNot!['reminderAt'];
      if (reminderStr != null && reminderStr.toString().isNotEmpty) {
        try {
          _reminderDateTime = DateTime.parse(reminderStr.toString());
        } catch (_) {}
      }
      _notificationId = widget.mevcutNot!['notificationId'];

      final detayli = (widget.mevcutNot!['detayli_satirlar'] as List? ?? []);

      // Backward compatibility: eski alanlar varsa detayli'ye dönüştür
      final eskiListe = (widget.mevcutNot!['gorevListesi'] as List? ?? []);
      final duzMetin = (widget.mevcutNot!['icerik'] ?? "").toString();
      final eskiResimler =
          List<String>.from(widget.mevcutNot!['resimler'] ?? []);

      if (detayli.isNotEmpty) {
        for (final d in detayli) {
          if (d is! Map) continue;
          if (d['tip'] == 'resim') {
            _satirlar
                .add(NotSatiri.resim(resimYolu: d['resimYolu']?.toString()));
          } else {
            _satirEkle(
              text: (d['text'] ?? "").toString(),
              isCheckbox: (d['isCheckbox'] ?? false) as bool,
              isChecked: (d['isChecked'] ?? false) as bool,
            );
          }
        }
      } else {
        if (eskiListe.isNotEmpty) {
          for (final e in eskiListe) {
            if (e is! Map) continue;
            _satirEkle(
              text: (e['text'] ?? "").toString(),
              isCheckbox: true,
              isChecked: (e['yapildi'] ?? false) as bool,
            );
          }
        } else if (duzMetin.isNotEmpty) {
          for (final p in duzMetin.split('\n')) {
            _satirEkle(text: p, isCheckbox: false);
          }
        }
        for (final resimYolu in eskiResimler) {
          _satirlar.add(NotSatiri.resim(resimYolu: resimYolu));
        }
      }

      if (_satirlar.isEmpty) _satirEkle();
    } else {
      _satirEkle();
    }
  }

  void _mikrofonuHazirla() async {
    await _speechToText.initialize();
  }

  void _satirEkle(
      {String text = "",
      bool isCheckbox = false,
      bool isChecked = false,
      int? index}) {
    final yeniSatir = NotSatiri.metin(
      controller: TextEditingController(text: text),
      focusNode: FocusNode(),
      isCheckbox: isCheckbox,
      isChecked: isChecked,
    );
    setState(() {
      if (index != null) {
        _satirlar.insert(index, yeniSatir);
      } else {
        _satirlar.add(yeniSatir);
      }
    });
  }

  int _aktifIndexiBul() {
    int idx = _satirlar
        .indexWhere((s) => s.tip == SatirTipi.metin && s.focusNode!.hasFocus);
    if (idx == -1) idx = _satirlar.length;
    return idx;
  }

  // ---- Hatırlatıcı: seç/kaldır (merge) ----
  Future<void> _hatirlaticiSec() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminderDateTime ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: "Hatırlatıcı Tarihi Seç",
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderDateTime ?? now),
      helpText: "Hatırlatıcı Saati Seç",
    );

    if (pickedTime == null) return;

    final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute);

    if (dt.isBefore(now.add(const Duration(seconds: 5)))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Geçmiş bir saat seçilemez.")));
      return;
    }

    setState(() => _reminderDateTime = dt);
  }

  Future<void> _hatirlaticiyiKaldir() async {
    if (_notificationId != null) {
      await NotificationService.instance.cancel(_notificationId!);
    }
    setState(() {
      _reminderDateTime = null;
      _notificationId = null;
    });
  }

  String _formatReminder(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return "$dd.$mm.$yyyy  $hh:$min";
  }

  // ---- Sesle yazma ----
  void _sesleYazmayiYonet() async {
    if (_dinliyorMu) {
      await _speechToText.stop();
      setState(() {
        _dinliyorMu = false;
        if (_geciciYazi.isNotEmpty) {
          final idx = _satirlar.indexWhere(
              (s) => s.tip == SatirTipi.metin && s.focusNode!.hasFocus);
          if (idx == -1) {
            _satirEkle(text: _geciciYazi);
          } else {
            _satirlar[idx].controller!.text += " $_geciciYazi";
          }
          _geciciYazi = "";
        }
      });
    } else {
      setState(() => _dinliyorMu = true);
      await _speechToText.listen(
        onResult: (r) => setState(() => _geciciYazi = r.recognizedWords),
        localeId: "tr_TR",
      );
    }
  }

  // ---- Checkbox toggle ----
  void _toggleCheckbox() {
    int idx = _satirlar
        .indexWhere((s) => s.tip == SatirTipi.metin && s.focusNode!.hasFocus);

    if (idx == -1) {
      _satirEkle(isCheckbox: true);
      Future.delayed(Duration.zero, () {
        _satirlar.last.focusNode!.requestFocus();
      });
      return;
    }

    setState(() {
      _satirlar[idx].isCheckbox = !_satirlar[idx].isCheckbox;
      if (!_satirlar[idx].isCheckbox) _satirlar[idx].isChecked = false;
    });
    _satirlar[idx].focusNode!.requestFocus();
  }

  // ---- OCR: aktif satıra ekleme ----
  Future<void> _ocrIslemi() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);

    setState(() {
      final satirlar = recognizedText.text.split('\n');
      int eklemeIndexi = _aktifIndexiBul();
      for (final s in satirlar) {
        if (s.trim().isNotEmpty) {
          _satirEkle(text: s.trim(), index: eklemeIndexi);
          eklemeIndexi++;
        }
      }
    });
    textRecognizer.close();
  }

  // ---- Resim ekle ----
  Future<void> _resimEkle(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        int idx = _aktifIndexiBul();
        if (idx < _satirlar.length &&
            _satirlar[idx].tip == SatirTipi.metin &&
            _satirlar[idx].controller!.text.isNotEmpty) {
          idx++;
        }
        _satirlar.insert(idx, NotSatiri.resim(resimYolu: image.path));
      });
    }
  }

  // ---- Çizim (Signature) -> resim satırı ----
  Future<void> _cizimYap() async {
    final SignatureController controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.white,
      exportBackgroundColor: Colors.transparent,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 350,
              width: double.maxFinite,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                color: Colors.black,
              ),
              child: Signature(
                controller: controller,
                backgroundColor: Colors.black,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  onPressed: () => controller.clear(),
                ),
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.orange),
                  onPressed: () => controller.undo(),
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.isNotEmpty) {
                final Uint8List? data = await controller.toPngBytes();
                if (!context.mounted) return;

                if (data != null) {
                  final tempDir = await getTemporaryDirectory();
                  final file = await File(
                    '${tempDir.path}/draw_${DateTime.now().millisecondsSinceEpoch}.png',
                  ).create();
                  file.writeAsBytesSync(data);

                  setState(() {
                    int idx = _aktifIndexiBul();
                    if (idx < _satirlar.length &&
                        _satirlar[idx].tip == SatirTipi.metin &&
                        _satirlar[idx].controller!.text.isNotEmpty) {
                      idx++;
                    }
                    _satirlar.insert(
                        idx, NotSatiri.resim(resimYolu: file.path));
                  });
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  // ---- Resim büyüt ----
  void _resimiBuyut(String resimYolu) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(File(resimYolu)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Fotoğraf üstüne çiz ----
  Future<void> _fotografUzerineCiz(int index, String imagePath) async {
    final SignatureController controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.red,
      exportBackgroundColor: Colors.transparent,
    );

    final GlobalKey globalKey = GlobalKey();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: globalKey,
              child: SizedBox(
                height: 400,
                width: double.maxFinite,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(File(imagePath), fit: BoxFit.contain),
                    ),
                    Positioned.fill(
                      child: Signature(
                        controller: controller,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  onPressed: () => controller.clear(),
                ),
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.orange),
                  onPressed: () => controller.undo(),
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final boundary = globalKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
              final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
              final ByteData? byteData =
                  await image.toByteData(format: ui.ImageByteFormat.png);

              if (!mounted) return;

              if (byteData != null) {
                final tempDir = await getTemporaryDirectory();
                final file = await File(
                  '${tempDir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png',
                ).create();
                file.writeAsBytesSync(byteData.buffer.asUint8List());

                setState(() {
                  _satirlar[index].resimYolu = file.path;
                });
              }

              if (mounted && ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Kaydet",
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  // ---- Paylaş ----
  void _paylas() {
    final icerik = _satirlar.where((s) => s.tip == SatirTipi.metin).map((e) {
      final prefix = e.isCheckbox ? (e.isChecked ? "[x] " : "[ ] ") : "";
      return "$prefix${e.controller!.text}";
    }).join("\n");

    if (_baslikController.text.isNotEmpty) {
      Share.share(
          "${_baslikController.text}\n\n(Resimler paylaşılamıyor)\n\n$icerik");
    }
  }

  // ---- Sil: bildirimi de iptal et (merge) ----
  Future<void> _sil() async {
    if (widget.notKey != null) {
      final existing = _notKutusu.getAt(widget.notKey!);
      final nid = existing?['notificationId'];
      if (nid != null) {
        await NotificationService.instance.cancel(nid as int);
      }
      _notKutusu.deleteAt(widget.notKey!);
      if (mounted) Navigator.pop(context);
    }
  }

  // ---- Kaydet/Güncelle: detayli + reminder schedule/cancel (merge) ----
  Future<void> _kaydetVeyaGuncelle() async {
    // dinleme açıkken kaydetme: stop + geçici yazıyı ekle
    if (_dinliyorMu) {
      await _speechToText.stop();
      setState(() => _dinliyorMu = false);
      if (_geciciYazi.isNotEmpty) {
        final idx = _satirlar.indexWhere(
            (s) => s.tip == SatirTipi.metin && s.focusNode!.hasFocus);
        if (idx == -1) {
          _satirEkle(text: _geciciYazi);
        } else {
          _satirlar[idx].controller!.text += " $_geciciYazi";
        }
        _geciciYazi = "";
      }
    }

    final detayliListe = _satirlar.map((s) {
      if (s.tip == SatirTipi.resim) {
        return {"tip": "resim", "resimYolu": s.resimYolu};
      } else {
        return {
          "tip": "metin",
          "text": s.controller!.text,
          "isCheckbox": s.isCheckbox,
          "isChecked": s.isChecked,
        };
      }
    }).toList();

    final icerikVarMi = _satirlar.any((s) =>
        (s.tip == SatirTipi.resim) ||
        (s.tip == SatirTipi.metin && s.controller!.text.trim().isNotEmpty));

    if (_baslikController.text.isEmpty && !icerikVarMi) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Boş not kaydedilemez")));
      return;
    }

    // notification id üret / koru
    _notificationId ??=
        DateTime.now().millisecondsSinceEpoch.remainder(1000000000);

    final yeniVeri = <String, dynamic>{
      "baslik": _baslikController.text,
      "detayli_satirlar": detayliListe,
      "tarih": DateTime.now().toString(),
      "renk": _secilenRenk,
      "sabit": _sabitMi,
      "gizli": _gizliMi,

      // eski alanlar (compat)
      "icerik": "",
      "resimler": [],
      "gorevListesi": [],

      // reminder
      "reminderAt": _reminderDateTime?.toIso8601String(),
      "notificationId": _notificationId,
    };

    if (widget.notKey != null) {
      _notKutusu.putAt(widget.notKey!, yeniVeri);
    } else {
      _notKutusu.add(yeniVeri);
    }

    // schedule / cancel
    if (_reminderDateTime != null && _notificationId != null) {
      await NotificationService.instance.schedule(
        id: _notificationId!,
        title: _baslikController.text.isNotEmpty
            ? _baslikController.text
            : "Not Hatırlatıcı",
        body: _satirlar
                .where((s) => s.tip == SatirTipi.metin)
                .map((e) => e.controller!.text)
                .join("\n")
                .trim()
                .isNotEmpty
            ? _satirlar
                .where((s) => s.tip == SatirTipi.metin)
                .map((e) => e.controller!.text)
                .join("\n")
            : "Notunu kontrol et",
        dateTime: _reminderDateTime!,
      );
    } else {
      if (_notificationId != null) {
        await NotificationService.instance.cancel(_notificationId!);
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final List<int> renkPaleti = [
      0xFF1F1F1F,
      0xFF3E2723,
      0xFF004D40,
      0xFF1A237E,
      0xFFB71C1C,
      0xFFFF6F00
    ];

    return Scaffold(
      backgroundColor: Color(_secilenRenk),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _gizliMi
            ? const Text("🔒 Gizli Not",
                style: TextStyle(fontSize: 16, color: Colors.green))
            : null,
        actions: [
          IconButton(
            icon: Icon(_sabitMi ? Icons.push_pin : Icons.push_pin_outlined,
                color: Colors.white),
            onPressed: () => setState(() => _sabitMi = !_sabitMi),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _paylas,
          ),
          if (widget.notKey != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _sil,
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _baslikController,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: "Başlık",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),

                  // ---- Hatırlatıcı UI (merge) ----
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm, color: Colors.white70),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _reminderDateTime == null
                                ? "Hatırlatıcı yok"
                                : "Hatırlatıcı: ${_formatReminder(_reminderDateTime!)}",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        TextButton(
                            onPressed: _hatirlaticiSec,
                            child: const Text("Seç")),
                        if (_reminderDateTime != null)
                          IconButton(
                            onPressed: _hatirlaticiyiKaldir,
                            icon: const Icon(Icons.close,
                                color: Colors.redAccent),
                            tooltip: "Hatırlatıcıyı kaldır",
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ---- Satırlar: metin / resim ----
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _satirlar.length,
                    itemBuilder: (context, index) {
                      final satir = _satirlar[index];

                      if (satir.tip == SatirTipi.resim) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              GestureDetector(
                                onTap: () => _resimiBuyut(satir.resimYolu!),
                                child: Container(
                                  width: double.infinity,
                                  constraints:
                                      const BoxConstraints(maxHeight: 300),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(satir.resimYolu!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      radius: 16,
                                      child: Icon(Icons.brush,
                                          color: Colors.yellowAccent, size: 18),
                                    ),
                                    onPressed: () => _fotografUzerineCiz(
                                        index, satir.resimYolu!),
                                  ),
                                  IconButton(
                                    icon: const CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      radius: 16,
                                      child: Icon(Icons.close,
                                          color: Colors.white, size: 18),
                                    ),
                                    onPressed: () => setState(
                                        () => _satirlar.removeAt(index)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      // metin satırı
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (satir.isCheckbox)
                            Transform.scale(
                              scale: 1.1,
                              child: Checkbox(
                                value: satir.isChecked,
                                checkColor: Colors.black,
                                activeColor: Colors.white,
                                side: const BorderSide(
                                    color: Colors.white70, width: 2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                                onChanged: (bool? val) => setState(
                                    () => satir.isChecked = val ?? false),
                              ),
                            ),
                          Expanded(
                            child: TextField(
                              controller: satir.controller,
                              focusNode: satir.focusNode,
                              style: TextStyle(
                                color: satir.isChecked
                                    ? Colors.white54
                                    : Colors.white,
                                fontSize: 18,
                                decoration: satir.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: Colors.white54,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) {
                                _satirEkle(
                                    index: index + 1,
                                    isCheckbox: satir.isCheckbox);
                                Future.delayed(Duration.zero, () {
                                  _satirlar[index + 1]
                                      .focusNode!
                                      .requestFocus();
                                });
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // boş alana tıklayınca yeni satır
                  GestureDetector(
                    onTap: () {
                      _satirEkle();
                      Future.delayed(Duration.zero, () {
                        _satirlar.last.focusNode!.requestFocus();
                      });
                    },
                    child: Container(height: 100, color: Colors.transparent),
                  ),

                  if (_dinliyorMu)
                    Text(
                      " $_geciciYazi...",
                      style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ),

          // ---- Alt Toolbar ----
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.black26,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: renkPaleti
                        .map(
                          (renk) => GestureDetector(
                            onTap: () => setState(() => _secilenRenk = renk),
                            child: Container(
                              margin:
                                  const EdgeInsets.only(right: 12, bottom: 10),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Color(renk),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _secilenRenk == renk
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                  width: 2,
                                ),
                              ),
                              child: _secilenRenk == renk
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Tooltip(
                      message: "Metni Tara",
                      child: IconButton(
                        icon: const Icon(Icons.document_scanner_outlined,
                            color: Colors.white, size: 28),
                        onPressed: _ocrIslemi,
                      ),
                    ),
                    Tooltip(
                      message: "Sesle Yaz",
                      child: IconButton(
                        icon: Icon(
                          _dinliyorMu
                              ? Icons.stop_circle_outlined
                              : Icons.record_voice_over,
                          color: _dinliyorMu ? Colors.red : Colors.white,
                          size: 28,
                        ),
                        onPressed: _sesleYazmayiYonet,
                      ),
                    ),
                    PopupMenuButton<ImageSource>(
                      tooltip: "Resim Ekle",
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 28),
                      onSelected: (source) => _resimEkle(source),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: ImageSource.camera,
                          child: Row(children: [
                            Icon(Icons.camera, color: Colors.black),
                            SizedBox(width: 8),
                            Text("Kamera")
                          ]),
                        ),
                        PopupMenuItem(
                          value: ImageSource.gallery,
                          child: Row(children: [
                            Icon(Icons.image, color: Colors.black),
                            SizedBox(width: 8),
                            Text("Galeri")
                          ]),
                        ),
                      ],
                      color: Colors.white,
                    ),
                    Tooltip(
                      message: "Çizim Yap",
                      child: IconButton(
                        icon: const Icon(Icons.draw,
                            color: Colors.white, size: 28),
                        onPressed: _cizimYap,
                      ),
                    ),
                    Tooltip(
                      message: "Kutucuk Ekle/Kaldır",
                      child: IconButton(
                        icon: const Icon(Icons.check_box_outlined,
                            color: Colors.white, size: 28),
                        onPressed: _toggleCheckbox,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _kaydetVeyaGuncelle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      child: const Icon(Icons.check, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- MODELLER --------------------
enum SatirTipi { metin, resim }

class NotSatiri {
  SatirTipi tip;
  TextEditingController? controller;
  FocusNode? focusNode;
  bool isCheckbox;
  bool isChecked;
  String? resimYolu;

  NotSatiri.metin({
    required this.controller,
    required this.focusNode,
    this.isCheckbox = false,
    this.isChecked = false,
  })  : tip = SatirTipi.metin,
        resimYolu = null;

  NotSatiri.resim({
    required this.resimYolu,
  })  : tip = SatirTipi.resim,
        controller = null,
        focusNode = null,
        isCheckbox = false,
        isChecked = false;
}
