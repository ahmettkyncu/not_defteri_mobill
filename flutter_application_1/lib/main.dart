import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('notlar_kutusu');
  await Hive.openBox('ayarlar');
  runApp(const NotUygulamasi());
}

class NotUygulamasi extends StatelessWidget {
  const NotUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pro Not Defteri',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFFC107),
          foregroundColor: Colors.black,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1F1F1F),
        ),
      ),
      home: const AnaSayfa(),
    );
  }
}

// --- 1. SAYFA: ANA SAYFA ---
class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final _notKutusu = Hive.box('notlar_kutusu');
  final _ayarlarKutusu = Hive.box('ayarlar');
  String _aramaMetni = "";

  // GİZLİ KASA AYARLARI
  bool _gizliModAcik = false;

  // --- AKILLI ŞİFRE YÖNETİMİ ---
  Future<void> _kasaIslemleri() async {
    // 1. Önce veritabanında kayıtlı şifre var mı diye bakıyoruz.
    String? kayitliSifre = _ayarlarKutusu.get('kasa_sifresi');

    if (kayitliSifre == null) {
      // HİÇ ŞİFRE YOKSA -> ŞİFRE OLUŞTURMA EKRANI
      await _sifreOlustur();
    } else {
      // ŞİFRE VARSA -> GİRİŞ EKRANI
      await _sifreSor(kayitliSifre);
    }
  }

  // Şifre Oluşturma (İlk Kez)
  Future<void> _sifreOlustur() async {
    TextEditingController pass1 = TextEditingController();
    TextEditingController pass2 = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false, // Dışarı basınca kapanmasın
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text("🆕 Kasa Kurulumu",
            style: TextStyle(color: Colors.orange)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Gizli kasanızı kullanmak için lütfen bir şifre belirleyin.",
                style: TextStyle(color: Colors.white70)),
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
                      borderSide: BorderSide(color: Colors.grey))),
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
                      borderSide: BorderSide(color: Colors.grey))),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: Colors.red))),
          TextButton(
            onPressed: () {
              if (pass1.text.isNotEmpty && pass1.text == pass2.text) {
                // Şifreyi Kaydet
                _ayarlarKutusu.put('kasa_sifresi', pass1.text);
                Navigator.pop(context);

                // Kasayı otomatik aç
                setState(() => _gizliModAcik = true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("✅ Şifre Oluşturuldu! Kasa Açık."),
                    backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Şifreler eşleşmiyor veya boş!"),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text("Oluştur", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Şifre Sorma (Giriş)
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
              child: const Text("İptal", style: TextStyle(color: Colors.red))),
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
                    backgroundColor: Colors.red));
              }
            },
            child: const Text("Giriş", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Notu Gizleme/Gösterme
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
      appBar: _gizliModAcik
          ? AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => setState(() => _gizliModAcik = false)),
              title: const Text("🔒 Gizli Kasa",
                  style: TextStyle(color: Colors.green)),
              actions: [
                IconButton(
                    icon: const Icon(Icons.settings, color: Colors.grey),
                    onPressed: () => _ayarlarMenusunuAc(context)),
              ],
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (!_gizliModAcik)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                child: Row(
                  children: [
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
                                    border: InputBorder.none),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 50, width: 50,
                      decoration: BoxDecoration(
                          color: const Color(0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(25)),
                      // ANA SAYFA AYARLAR BUTONU (Şifre değiştirme burada YOK)
                      child: IconButton(
                          icon: const Icon(Icons.settings, color: Colors.grey),
                          onPressed: () => _ayarlarMenusunuAc(context)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFFFC107),
                backgroundColor: Colors.black,
                // Aşağı çekince Akıllı Kasa İşlemleri Başlar
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
                        return not['baslik']
                                .toString()
                                .toLowerCase()
                                .contains(_aramaMetni) ||
                            not['icerik']
                                .toString()
                                .toLowerCase()
                                .contains(_aramaMetni);
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
                                color: Colors.grey.shade800),
                            const SizedBox(height: 10),
                            Text(
                                _gizliModAcik
                                    ? "Kasa Boş"
                                    : "Not listeniz boş\n(Gizli kasa için aşağı çek)",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600)),
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
                        bool isListe = not['listeModu'] ?? false;
                        List<String> ekliResimler =
                            List<String>.from(not['resimler'] ?? []);

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
                                                color: Colors.yellow),
                                            title: Text(
                                                _gizliModAcik
                                                    ? "Notu Kasadan Çıkar"
                                                    : "Notu Gizli Kasaya Taşı",
                                                style: const TextStyle(
                                                    color: Colors.white)),
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              _notuTasi(gercekIndex, not,
                                                  !_gizliModAcik);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.delete,
                                                color: Colors.red),
                                            title: const Text("Notu Sil",
                                                style: TextStyle(
                                                    color: Colors.white)),
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              _notKutusu.deleteAt(gercekIndex);
                                            },
                                          ),
                                        ],
                                      ),
                                    ));
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
                                Text(not["baslik"] ?? "",
                                    style: TextStyle(
                                        color: _yaziRenginiBul(kartRengi),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 8),
                                isListe
                                    ? Row(children: [
                                        Icon(Icons.check_box,
                                            size: 16,
                                            color: _yaziRenginiBul(kartRengi)
                                                .withOpacity(0.7)),
                                        const SizedBox(width: 5),
                                        Text("Görev Listesi",
                                            style: TextStyle(
                                                color:
                                                    _yaziRenginiBul(kartRengi)
                                                        .withOpacity(0.7),
                                                fontSize: 14))
                                      ])
                                    : Text(not["icerik"] ?? "",
                                        maxLines: 6,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: _yaziRenginiBul(kartRengi)
                                                .withOpacity(0.7),
                                            fontSize: 14)),
                                if (ekliResimler.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Row(children: [
                                      const Icon(Icons.image,
                                          size: 14, color: Colors.white70),
                                      Text(" ${ekliResimler.length} ",
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                    ]),
                                  ),
                                const SizedBox(height: 12),
                                Text(_tarihFormatla(not["tarih"]),
                                    style: TextStyle(
                                        color: _yaziRenginiBul(kartRengi)
                                            .withOpacity(0.5),
                                        fontSize: 12)),
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
                    NotEkleSayfasi(otomatikGizli: _gizliModAcik)),
          ),
          child: Icon(Icons.add,
              size: 32, color: _gizliModAcik ? Colors.white : Colors.black),
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

  void _ayarlarMenusunuAc(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (c) => SizedBox(
            height: 200,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                    width: 40,
                    height: 4,
                    color: Colors.grey,
                    margin: const EdgeInsets.only(bottom: 20)),

                // SADECE GİZLİ MOD AÇIKSA GÖSTER
                if (_gizliModAcik)
                  ListTile(
                      leading: const Icon(Icons.password, color: Colors.orange),
                      title: const Text("Gizli Kasa Şifresini Değiştir",
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(c);
                        _sifreDegistir();
                      }),

                ListTile(
                    leading: const Icon(Icons.delete_sweep, color: Colors.red),
                    title: const Text("Tüm Notları Sil",
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      _notKutusu.clear();
                      Navigator.pop(c);
                    })
              ],
            )));
  }

  Future<void> _sifreDegistir() async {
    TextEditingController eski = TextEditingController();
    TextEditingController yeni = TextEditingController();
    String? mevcut = _ayarlarKutusu.get('kasa_sifresi');

    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1F1F1F),
              title: const Text("Şifre Değiştir",
                  style: TextStyle(color: Colors.white)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: eski,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "Eski Şifre",
                        hintStyle: TextStyle(color: Colors.grey))),
                TextField(
                    controller: yeni,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "Yeni Şifre",
                        hintStyle: TextStyle(color: Colors.grey))),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("İptal",
                        style: TextStyle(color: Colors.red))),
                TextButton(
                    onPressed: () {
                      if (eski.text == mevcut && yeni.text.isNotEmpty) {
                        _ayarlarKutusu.put('kasa_sifresi', yeni.text);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Şifre Değişti!"),
                                backgroundColor: Colors.green));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Eski şifre yanlış!"),
                                backgroundColor: Colors.red));
                      }
                    },
                    child: const Text("Kaydet",
                        style: TextStyle(color: Colors.white))),
              ],
            ));
  }
}

// --- 2. SAYFA: NOT EKLEME/DÜZENLEME (AYNI KOD) ---
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
  final TextEditingController _icerikController = TextEditingController();
  final _notKutusu = Hive.box('notlar_kutusu');
  final SpeechToText _speechToText = SpeechToText();

  bool _dinliyorMu = false;
  String _geciciYazi = "";
  int _secilenRenk = 0xFF1F1F1F;
  bool _sabitMi = false;
  bool _gizliMi = false;
  List<String> _ekliResimler = [];
  bool _listeModu = false;
  List<Map<String, dynamic>> _gorevListesi = [];

  @override
  void initState() {
    super.initState();
    _mikrofonuHazirla();

    _gizliMi = widget.otomatikGizli;

    if (widget.mevcutNot != null) {
      _baslikController.text = widget.mevcutNot!['baslik'];
      _icerikController.text = widget.mevcutNot!['icerik'];
      _secilenRenk = widget.mevcutNot!['renk'] ?? 0xFF1F1F1F;
      _sabitMi = widget.mevcutNot!['sabit'] ?? false;
      _gizliMi = widget.mevcutNot!['gizli'] ?? false;
      _listeModu = widget.mevcutNot!['listeModu'] ?? false;
      _ekliResimler = List<String>.from(widget.mevcutNot!['resimler'] ?? []);
      List hamListe = widget.mevcutNot!['gorevListesi'] ?? [];
      _gorevListesi =
          hamListe.map((e) => Map<String, dynamic>.from(e)).toList();
    }
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
          if (_listeModu) {
            _gorevListesi.add({'text': _geciciYazi, 'yapildi': false});
          } else {
            _icerikController.text = "${_icerikController.text} $_geciciYazi";
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

  Future<void> _ocrIslemi() async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
        context: context,
        builder: (ctx) => SizedBox(
            height: 150,
            child: Column(children: [
              const ListTile(
                  title: Text("Metni Tara",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _ocrGerceklestir(ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Kamera")),
                ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _ocrGerceklestir(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.image),
                    label: const Text("Galeri")),
              ]),
            ])));
  }

  Future<void> _ocrGerceklestir(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Metin taranıyor...")));
    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);
    setState(() {
      if (_listeModu) {
        List<String> satirlar = recognizedText.text.split('\n');
        for (var s in satirlar) {
          if (s.trim().isNotEmpty)
            _gorevListesi.add({'text': s.trim(), 'yapildi': false});
        }
      } else {
        _icerikController.text =
            "${_icerikController.text}\n${recognizedText.text}";
      }
    });
    textRecognizer.close();
  }

  Future<void> _resimEkle() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) setState(() => _ekliResimler.add(image.path));
  }

  void _resimSil(int index) {
    setState(() {
      _ekliResimler.removeAt(index);
    });
  }

  void _paylas() {
    if (_baslikController.text.isNotEmpty)
      Share.share("${_baslikController.text}\n\n${_icerikController.text}");
  }

  void _sil() {
    if (widget.notKey != null) {
      _notKutusu.deleteAt(widget.notKey!);
      Navigator.pop(context);
    }
  }

  void _kaydetVeyaGuncelle() {
    if (_dinliyorMu) {
      _speechToText.stop();
      if (_geciciYazi.isNotEmpty && !_listeModu)
        _icerikController.text = "${_icerikController.text} $_geciciYazi";
    }

    if (_baslikController.text.isNotEmpty ||
        _icerikController.text.isNotEmpty ||
        _ekliResimler.isNotEmpty ||
        _gorevListesi.isNotEmpty) {
      Map yeniVeri = {
        "baslik": _baslikController.text,
        "icerik": _icerikController.text,
        "tarih": DateTime.now().toString(),
        "renk": _secilenRenk,
        "sabit": _sabitMi,
        "gizli": _gizliMi,
        "listeModu": _listeModu,
        "gorevListesi": _gorevListesi,
        "resimler": _ekliResimler,
      };
      if (widget.notKey != null)
        _notKutusu.putAt(widget.notKey!, yeniVeri);
      else
        _notKutusu.add(yeniVeri);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Boş not kaydedilemez")));
    }
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
                  if (_listeModu) ...[
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _gorevListesi.removeAt(oldIndex);
                          _gorevListesi.insert(newIndex, item);
                        });
                      },
                      children: [
                        for (int index = 0;
                            index < _gorevListesi.length;
                            index++)
                          ListTile(
                            key: ValueKey(index),
                            leading: Checkbox(
                                value: _gorevListesi[index]['yapildi'],
                                onChanged: (val) => setState(() =>
                                    _gorevListesi[index]['yapildi'] = val),
                                checkColor: Colors.black,
                                activeColor: Colors.white),
                            title: TextFormField(
                              initialValue: _gorevListesi[index]['text'],
                              style: TextStyle(
                                  color: Colors.white,
                                  decoration: _gorevListesi[index]['yapildi']
                                      ? TextDecoration.lineThrough
                                      : null),
                              decoration: const InputDecoration(
                                  border: InputBorder.none),
                              onChanged: (val) =>
                                  _gorevListesi[index]['text'] = val,
                            ),
                            trailing: IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.grey),
                                onPressed: () => setState(
                                    () => _gorevListesi.removeAt(index))),
                          ),
                      ],
                    ),
                    TextButton.icon(
                        onPressed: () => setState(() =>
                            _gorevListesi.add({'text': '', 'yapildi': false})),
                        icon: const Icon(Icons.add, color: Colors.white70),
                        label: const Text("Yeni Madde Ekle",
                            style: TextStyle(color: Colors.white70))),
                  ] else
                    TextField(
                        controller: _icerikController,
                        maxLines: null,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                        decoration: const InputDecoration(
                            hintText: "Notunuzu yazın...",
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none)),
                  if (_dinliyorMu)
                    Text(" $_geciciYazi...",
                        style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontStyle: FontStyle.italic)),
                  const SizedBox(height: 20),
                  if (_ekliResimler.isNotEmpty)
                    SizedBox(
                        height: 120,
                        child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _ekliResimler.length,
                            itemBuilder: (context, index) {
                              return Stack(children: [
                                Container(
                                    margin: const EdgeInsets.only(
                                        right: 10, top: 10),
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        image: DecorationImage(
                                            image: FileImage(
                                                File(_ekliResimler[index])),
                                            fit: BoxFit.cover))),
                                Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                        onTap: () => _resimSil(index),
                                        child: const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.red,
                                            child: Icon(Icons.close,
                                                size: 16,
                                                color: Colors.white)))),
                              ]);
                            })),
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
                    Tooltip(
                        message: "Resim Ekle",
                        child: IconButton(
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 28),
                            onPressed: _resimEkle)),

                    // GÖREV LİSTESİ MODU BUTONU
                    Tooltip(
                      message: "Liste Modu",
                      child: IconButton(
                        icon: Icon(
                            _listeModu ? Icons.list_alt : Icons.edit_note,
                            color: _listeModu
                                ? const Color(0xFFFFC107)
                                : Colors.white,
                            size: 28),
                        onPressed: () =>
                            setState(() => _listeModu = !_listeModu),
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
