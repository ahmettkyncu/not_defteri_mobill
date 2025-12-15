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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('notlar_kutusu');
  await Hive.openBox('ayarlar');
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

// --- 1. SAYFA: ANA SAYFA ---
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
    TextEditingController pass1 = TextEditingController();
    TextEditingController pass2 = TextEditingController();

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
    TextEditingController girilenSifre = TextEditingController();
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

  void _notuTasi(int index, Map notData, bool gizle) {
    Map yeniVeri = Map.from(notData);
    yeniVeri['gizli'] = gizle;
    _notKutusu.putAt(index, yeniVeri);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(gizle ? "Kilitlendi 🔒" : "Kilidi Açıldı 🔓"),
      backgroundColor: Colors.blue,
      duration: const Duration(milliseconds: 800),
    ));
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
                child: Text(
                  "Ayarlar",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
                onTap: () {
                  _notKutusu.clear();
                  Navigator.pop(context);
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
                  builder: (context, box, widget) {
                    List<dynamic> tumNotlar = box.values.toList();
                    Map<int, Map> filtrelenmisNotlar = {};

                    for (int i = 0; i < tumNotlar.length; i++) {
                      Map veri = tumNotlar[i] as Map;
                      bool notGizliMi = veri['gizli'] ?? false;

                      if (_gizliModAcik) {
                        if (notGizliMi) filtrelenmisNotlar[i] = veri;
                      } else {
                        if (!notGizliMi) filtrelenmisNotlar[i] = veri;
                      }
                    }

                    List<int> gosterilecekIndexler =
                        filtrelenmisNotlar.keys.toList();

                    if (_aramaMetni.isNotEmpty) {
                      gosterilecekIndexler = gosterilecekIndexler.where((idx) {
                        var not = filtrelenmisNotlar[idx]!;
                        String tumIcerik =
                            (not['detayli_satirlar'] as List? ?? [])
                                .where((s) => s['tip'] == 'metin')
                                .map((s) => s['text'].toString())
                                .join(' ');

                        return not['baslik']
                                .toString()
                                .toLowerCase()
                                .contains(_aramaMetni) ||
                            tumIcerik.toLowerCase().contains(_aramaMetni);
                      }).toList();
                    }

                    gosterilecekIndexler.sort((a, b) {
                      var notA = filtrelenmisNotlar[a]!;
                      var notB = filtrelenmisNotlar[b]!;
                      return notB['tarih'].compareTo(notA['tarih']);
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
                        int gercekIndex = gosterilecekIndexler[listIndex];
                        final not = filtrelenmisNotlar[gercekIndex]!;
                        int renkKodu = not['renk'] ?? 0xFF1F1F1F;
                        Color kartRengi = Color(renkKodu);
                        Color yaziRengi = _yaziRenginiBul(kartRengi);

                        List detayliSatirlar = not['detayli_satirlar'] ?? [];
                        int resimSayisi = detayliSatirlar
                            .where((s) => s['tip'] == 'resim')
                            .length;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NotEkleSayfasi(
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
                                      title: const Text(
                                        "Notu Sil",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      onTap: () {
                                        Navigator.pop(ctx);
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
                                Text(
                                  not["baslik"] ?? "",
                                  style: TextStyle(
                                    color: yaziRengi,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (detayliSatirlar.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: detayliSatirlar
                                        .take(5)
                                        .map<Widget>((s) {
                                      if (s['tip'] == 'resim') {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 4.0),
                                          child: Row(children: [
                                            Icon(Icons.image,
                                                size: 16,
                                                color: yaziRengi.withValues(
                                                    alpha: 0.7)),
                                            const SizedBox(width: 4),
                                            Text("(Resim)",
                                                style: TextStyle(
                                                    color: yaziRengi.withValues(
                                                        alpha: 0.7),
                                                    fontSize: 12))
                                          ]),
                                        );
                                      }

                                      bool isBox = s['isCheckbox'] ?? false;
                                      bool isChecked = s['isChecked'] ?? false;
                                      String text = s['text'] ?? "";
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
                                                  color: yaziRengi.withValues(
                                                      alpha: 0.7),
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                text,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isChecked
                                                      ? yaziRengi.withValues(
                                                          alpha: 0.4)
                                                      : yaziRengi.withValues(
                                                          alpha: 0.7),
                                                  fontSize: 14,
                                                  decoration: isChecked
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                  decorationColor: yaziRengi
                                                      .withValues(alpha: 0.4),
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
                                        Text(
                                          " $resimSayisi ",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  _tarihFormatla(not["tarih"]),
                                  style: TextStyle(
                                    color: yaziRengi.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
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
              builder: (context) =>
                  NotEkleSayfasi(otomatikGizli: _gizliModAcik),
            ),
          ),
          child: Icon(
            Icons.add,
            size: 32,
            color: _gizliModAcik ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Color _yaziRenginiBul(Color arkaplan) =>
      arkaplan.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  String _tarihFormatla(String? t) {
    if (t == null) return "";
    try {
      DateTime d = DateTime.parse(t);
      return "${d.day}.${d.month}.${d.year}";
    } catch (e) {
      return "";
    }
  }

  Future<void> _sifreDegistir() async {
    TextEditingController eski = TextEditingController();
    TextEditingController yeni = TextEditingController();
    String? mevcut = _ayarlarKutusu.get('kasa_sifresi');

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
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
            TextField(
              controller: yeni,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Yeni Şifre",
                hintStyle: TextStyle(color: Colors.grey),
              ),
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
}

// --- 2. SAYFA: NOT EKLEME/DÜZENLEME ---
class NotEkleSayfasi extends StatefulWidget {
  final Map? mevcutNot;
  final int? notKey; // Index
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

  final List<NotSatiri> _satirlar = []; // FİX: final yapıldı

  bool _dinliyorMu = false;
  String _geciciYazi = "";
  int _secilenRenk = 0xFF1F1F1F;
  bool _sabitMi = false;
  bool _gizliMi = false;

  @override
  void initState() {
    super.initState();
    _mikrofonuHazirla();
    _gizliMi = widget.otomatikGizli;

    if (widget.mevcutNot != null) {
      _baslikController.text = widget.mevcutNot!['baslik'];
      _secilenRenk = widget.mevcutNot!['renk'] ?? 0xFF1F1F1F;
      _sabitMi = widget.mevcutNot!['sabit'] ?? false;
      _gizliMi = widget.mevcutNot!['gizli'] ?? false;

      List detayli = widget.mevcutNot!['detayli_satirlar'] ?? [];

      List eskiListe = widget.mevcutNot!['gorevListesi'] ?? [];
      String duzMetin = widget.mevcutNot!['icerik'] ?? "";
      List<String> eskiResimler =
          List<String>.from(widget.mevcutNot!['resimler'] ?? []);

      if (detayli.isNotEmpty) {
        for (var d in detayli) {
          if (d['tip'] == 'resim') {
            _satirlar.add(NotSatiri.resim(resimYolu: d['resimYolu']));
          } else {
            _satirEkle(
              text: d['text'],
              isCheckbox: d['isCheckbox'] ?? false,
              isChecked: d['isChecked'] ?? false,
            );
          }
        }
      } else {
        if (eskiListe.isNotEmpty) {
          for (var e in eskiListe) {
            _satirEkle(
                text: e['text'], isCheckbox: true, isChecked: e['yapildi']);
          }
        } else if (duzMetin.isNotEmpty) {
          List<String> parcali = duzMetin.split('\n');
          for (var p in parcali) {
            _satirEkle(text: p, isCheckbox: false);
          }
        }
        for (var resimYolu in eskiResimler) {
          _satirlar.add(NotSatiri.resim(resimYolu: resimYolu));
        }
      }

      if (_satirlar.isEmpty) {
        _satirEkle();
      }
    } else {
      _satirEkle();
    }
  }

  void _satirEkle(
      {String text = "",
      bool isCheckbox = false,
      bool isChecked = false,
      int? index}) {
    var yeniSatir = NotSatiri.metin(
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

  void _mikrofonuHazirla() async {
    await _speechToText.initialize();
  }

  void _sesleYazmayiYonet() async {
    if (_dinliyorMu) {
      await _speechToText.stop();
      setState(() {
        _dinliyorMu = false;
        if (_geciciYazi.isNotEmpty) {
          int idx = _satirlar.indexWhere(
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
          localeId: "tr_TR");
    }
  }

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

  Future<void> _ocrIslemi() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    setState(() {
      List<String> satirlar = recognizedText.text.split('\n');
      int eklemeIndexi = _aktifIndexiBul();
      for (var s in satirlar) {
        if (s.trim().isNotEmpty) {
          _satirEkle(text: s.trim(), index: eklemeIndexi);
          eklemeIndexi++;
        }
      }
    });
    textRecognizer.close();
  }

  Future<void> _resimEkle(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
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

  Future<void> _cizimYap() async {
    // FİX: controller ismi düzeltildi
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
                controller: controller, // FİX: _ kaldırıldı
                backgroundColor: Colors.black,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  onPressed: () => controller.clear(), // FİX: _ kaldırıldı
                ),
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.orange),
                  onPressed: () => controller.undo(), // FİX: _ kaldırıldı
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
                // FİX: _ kaldırıldı
                final Uint8List? data =
                    await controller.toPngBytes(); // FİX: _ kaldırıldı

                // FİX: async gap kontrolü
                if (!context.mounted) return;

                if (data != null) {
                  final tempDir = await getTemporaryDirectory();
                  final file = await File(
                          '${tempDir.path}/draw_${DateTime.now().millisecondsSinceEpoch}.png')
                      .create();
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
              // FİX: async gap kontrolü
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    controller.dispose(); // FİX: _ kaldırıldı
  }

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

  Future<void> _fotografUzerineCiz(int index, String imagePath) async {
    // FİX: controller ismi düzeltildi
    final SignatureController controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.red,
      exportBackgroundColor: Colors.transparent,
    );

    GlobalKey globalKey = GlobalKey();

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
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned.fill(
                      child: Signature(
                        controller: controller, // FİX: _ kaldırıldı
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
                  onPressed: () => controller.clear(), // FİX: _ kaldırıldı
                ),
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.orange),
                  onPressed: () => controller.undo(), // FİX: _ kaldırıldı
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
              RenderRepaintBoundary boundary = globalKey.currentContext!
                  .findRenderObject() as RenderRepaintBoundary;
              ui.Image image = await boundary.toImage(pixelRatio: 2.0);
              ByteData? byteData =
                  await image.toByteData(format: ui.ImageByteFormat.png);

              // FİX: async gap kontrolü
              if (!mounted) return;

              if (byteData != null) {
                final tempDir = await getTemporaryDirectory();
                final file = await File(
                        '${tempDir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png')
                    .create();
                file.writeAsBytesSync(byteData.buffer.asUint8List());

                setState(() {
                  _satirlar[index].resimYolu = file.path;
                });
              }
              // FİX: async gap kontrolü
              if (mounted && ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text("Kaydet",
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    controller.dispose(); // FİX: _ kaldırıldı
  }

  void _paylas() {
    String icerik = _satirlar.where((s) => s.tip == SatirTipi.metin).map((e) {
      String prefix = e.isCheckbox ? (e.isChecked ? "[x] " : "[ ] ") : "";
      return "$prefix${e.controller!.text}";
    }).join("\n");

    if (_baslikController.text.isNotEmpty) {
      Share.share(
          "${_baslikController.text}\n\n(Resimler paylaşılamıyor)\n\n$icerik");
    }
  }

  void _sil() {
    if (widget.notKey != null) {
      _notKutusu.deleteAt(widget.notKey!);
      Navigator.pop(context);
    }
  }

  void _kaydetVeyaGuncelle() {
    List<Map<String, dynamic>> detayliListe = _satirlar.map((s) {
      if (s.tip == SatirTipi.resim) {
        return {
          "tip": "resim",
          "resimYolu": s.resimYolu,
        };
      } else {
        return {
          "tip": "metin",
          "text": s.controller!.text,
          "isCheckbox": s.isCheckbox,
          "isChecked": s.isChecked,
        };
      }
    }).toList();

    bool icerikVarMi = _satirlar.any((s) =>
        (s.tip == SatirTipi.resim) ||
        (s.tip == SatirTipi.metin && s.controller!.text.trim().isNotEmpty));

    if (_baslikController.text.isEmpty && !icerikVarMi) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Boş not kaydedilemez")));
      return;
    }

    Map yeniVeri = {
      "baslik": _baslikController.text,
      "detayli_satirlar": detayliListe,
      "tarih": DateTime.now().toString(),
      "renk": _secilenRenk,
      "sabit": _sabitMi,
      "gizli": _gizliMi,
      "icerik": "",
      "resimler": [],
      "gorevListesi": []
    };

    if (widget.notKey != null) {
      _notKutusu.putAt(widget.notKey!, yeniVeri);
    } else {
      _notKutusu.add(yeniVeri);
    }
    Navigator.pop(context);
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
              onPressed: () => setState(() => _sabitMi = !_sabitMi)),
          IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _paylas),
          if (widget.notKey != null)
            IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                onPressed: _sil),
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
                          border: InputBorder.none)),
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
                                      border:
                                          Border.all(color: Colors.white24)),
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
                                            color: Colors.yellowAccent,
                                            size: 18)),
                                    onPressed: () => _fotografUzerineCiz(
                                        index, satir.resimYolu!),
                                  ),
                                  IconButton(
                                    icon: const CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        radius: 16,
                                        child: Icon(Icons.close,
                                            color: Colors.white, size: 18)),
                                    onPressed: () {
                                      setState(() {
                                        _satirlar.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

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
                                onChanged: (bool? val) {
                                  setState(() {
                                    satir.isChecked = val ?? false;
                                  });
                                },
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
                  GestureDetector(
                    onTap: () {
                      _satirEkle();
                      Future.delayed(Duration.zero, () {
                        _satirlar.last.focusNode!.requestFocus();
                      });
                    },
                    child: Container(
                      height: 100,
                      color: Colors.transparent,
                    ),
                  ),
                  if (_dinliyorMu)
                    Text(" $_geciciYazi...",
                        style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: const BoxDecoration(
                color: Colors.black26,
                border: Border(top: BorderSide(color: Colors.white10))),
            child: Column(
              children: [
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                        children: renkPaleti
                            .map((renk) => GestureDetector(
                                onTap: () =>
                                    setState(() => _secilenRenk = renk),
                                child: Container(
                                    margin: const EdgeInsets.only(
                                        right: 12, bottom: 10),
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                        color: Color(renk),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: _secilenRenk == renk
                                                ? Colors.white
                                                : Colors.grey.shade800,
                                            width: 2)),
                                    child: _secilenRenk == renk
                                        ? const Icon(Icons.check,
                                            size: 16, color: Colors.white)
                                        : null)))
                            .toList())),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Tooltip(
                        message: "Metni Tara",
                        child: IconButton(
                            icon: const Icon(Icons.document_scanner_outlined,
                                color: Colors.white, size: 28),
                            onPressed: _ocrIslemi)),
                    Tooltip(
                        message: "Sesle Yaz",
                        child: IconButton(
                            icon: Icon(
                                _dinliyorMu
                                    ? Icons.stop_circle_outlined
                                    : Icons.record_voice_over,
                                color: _dinliyorMu ? Colors.red : Colors.white,
                                size: 28),
                            onPressed: _sesleYazmayiYonet)),
                    PopupMenuButton<ImageSource>(
                      tooltip: "Resim Ekle",
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 28),
                      onSelected: (source) => _resimEkle(source),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: ImageSource.camera,
                            child: Row(children: [
                              Icon(Icons.camera, color: Colors.black),
                              SizedBox(width: 8),
                              Text("Kamera")
                            ])),
                        const PopupMenuItem(
                            value: ImageSource.gallery,
                            child: Row(children: [
                              Icon(Icons.image, color: Colors.black),
                              SizedBox(width: 8),
                              Text("Galeri")
                            ])),
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
                            padding: const EdgeInsets.all(12)),
                        child: const Icon(Icons.check, color: Colors.black)),
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
