import 'dart:convert';
import 'package:aliyev_apk/main.dart' show globalIp, globalPort, globalAllowDateChange;
import 'package:audioplayers/audioplayers.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'barcode_scanner_page.dart';
import 'main.dart' show globalIp, globalPort, globalAllowDateChange, globalTermname,globalceki, globaleded, kSavedPrinterAddrKey, kSavedPrinterNameKey;  // qlobal dəyərlər üçün
import 'dart:async';



final AudioPlayer _audioPlayer1 = AudioPlayer();

/// ---- MODELLƏR ----

class LookupItem {
  final int id;
  final String name;
  LookupItem({required this.id, required this.name});

  factory LookupItem.fromMap(Map<String, dynamic> m) => LookupItem(
    id: (m['idn'] as num).toInt(),
    name: (m['adi'] ?? '').toString(),
  );
}

class SaleLine {
  final int productId; // 🔹 məhsulun idn-i
  final String barcode;
  final String name;
  final double qty;
  final String qeyd;

  SaleLine({
    required this.productId,
    required this.barcode,
    required this.name,
    required this.qty,
    required this.qeyd,
  });

  SaleLine copyWith({
    int? productId,
    String? barcode,
    String? name,
    double? qty,
    String? qeyd,
  }) {
    return SaleLine(
      productId: productId ?? this.productId,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      qeyd: qeyd ?? this.qeyd,
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId, // 🔹 draft üçün
    'barcode': barcode,
    'name': name,
    'qty': qty,
  };

  factory SaleLine.fromMap(Map<String, dynamic> m) => SaleLine(
    productId: (m['productId'] as num).toInt(),
    barcode: (m['barcode'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    qty: (m['qty'] as num).toDouble(),
    qeyd: (m['qeyd'] ?? '').toString(),
  );
}
final NumberFormat _qtyFmt18_3 = NumberFormat('#,###0.000', 'az'); // 1 234,56 kimi
String _fmt18_3(num v) => _qtyFmt18_3.format(v);

/// ---- SƏHİFƏ ----

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _formKey = GlobalKey<FormState>();

  // Header sahələri
  DateTime _date = DateTime.now();

  // ✅ ID-lər (SEÇİM)
  int? _fromWarehouseId;
  int? _toWarehouseId;




  List<LookupItem> _classList = [];
  List<LookupItem> _propertyList = [];

  LookupItem? selectedProperty;
  LookupItem? selectedClass;


  // ✅ Siyahılar
  List<LookupItem> _fromWarehouses = []; // /anbar?userId=...
  List<LookupItem> _toWarehouses = []; // /anbarlar

  // Satış sətirləri
  final List<SaleLine> _lines = [];

  final TextEditingController _noteCtrl = TextEditingController();

  // UI
  bool _loadingLookups = false;
  String? _lookupError;
  bool _submitting = false;

  // İR gizli TextField üçün
  final FocusNode _irFocus = FocusNode();
  final TextEditingController _irCtrl = TextEditingController();




  // Draft saxlanması üçün açar
  static const String _draftKey = 'transfer_draft';

  double get _totalQty => _lines.fold(0.0, (s, e) => s + e.qty);

  int get _lineCount => _lines.length;


  final Map<int, int> _addedCounts = {}; // productId -> neçə dəfə əlavə olunub

  void _incCount(int productId) {
    _addedCounts.update(productId, (v) => v + 1, ifAbsent: () => 1);
  }

  int get _totalAddedCount =>
      _addedCounts.values.fold(0, (sum, v) => sum + v);


  @override
  void initState() {
    super.initState();

    _loadDraft().then((_) => _loadLookups());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_irFocus);
    });

    _irFocus.addListener(() {
      if (_irFocus.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    });
  }


  @override
  void dispose() {
    _irCtrl.dispose();
    _irFocus.dispose();
    super.dispose();
  }


  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  // 🔧 IP/Port yalnız global-dan; boşdursa xətaya çıx
  Future<String> _getBaseUrl() async {
    if (globalIp == null ||
        globalPort == null ||
        globalIp!.trim().isEmpty ||
        globalPort!
            .toString()
            .trim()
            .isEmpty) {
      throw Exception('Server IP/Port təyin olunmayıb. Parametrləri yoxlayın.');
    }

    String host = globalIp!.trim();
    String port = globalPort!.toString().trim();

    // 'http://' / 'https://' yazılıbsa təmizlə
    host = host.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');

    // Emulator üçün localhost problemi
    if (host == '127.0.0.1' || host.toLowerCase() == 'localhost') {
      host = '10.0.2.2';
    }

    final base = 'http://$host:$port';
    debugPrint('BASE URL => $base');
    return base;
  }

  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });

    try {
      final base = await _getBaseUrl();

      // 🔹 Paralel istəklər
      final responses = await Future.wait([
        http.get(Uri.parse('$base/anbar?userId=$globalTermname')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$base/anbarlar')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$base/class')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$base/properties')).timeout(const Duration(seconds: 15)),
      ]);

      // 🔹 Cavabların hamısı uğurludursa yoxla
      if (responses.any((r) => r.statusCode != 200)) {
        throw Exception('Anbar siyahıları yüklənmədi (status != 200)');
      }

      // 🔹 JSON-ları parse et
      final fromJson = jsonDecode(responses[0].body) as List;
      final toJson = jsonDecode(responses[1].body) as List;
      final classJson = jsonDecode(responses[2].body) as List;
      final propJson = jsonDecode(responses[3].body) as List;

      final fromArr = fromJson.map((e) => LookupItem.fromMap(e)).toList();
      final toArr = toJson.map((e) => LookupItem.fromMap(e)).toList();
      final classes = classJson.map((e) => LookupItem.fromMap(e)).toList();
      final properties = propJson.map((e) => LookupItem.fromMap(e)).toList();

      // --- Default seçim ---
      int? defFromId = _fromWarehouseId ?? (fromArr.isNotEmpty ? fromArr.first.id : null);
      int? defToId = _toWarehouseId ?? (toArr.isNotEmpty ? toArr.first.id : null);

      final fromExists = defFromId != null && fromArr.any((x) => x.id == defFromId);
      if (!fromExists) defFromId = fromArr.isNotEmpty ? fromArr.first.id : null;

      final toExists = defToId != null && toArr.any((x) => x.id == defToId);
      if (!toExists) defToId = toArr.isNotEmpty ? toArr.first.id : null;


      if (defFromId != null && defToId != null && defFromId == defToId) {
        final alt = toArr.firstWhere(
              (x) => x.id != defFromId,
          orElse: () => toArr.isNotEmpty ? toArr.first : LookupItem(id: defToId!, name: ''),
        );
        defToId = alt.id;
      }

      // 🔹 State yenilə
      setState(() {
        _fromWarehouses = fromArr;
        _toWarehouses = toArr;
        _fromWarehouseId = defFromId;
        _toWarehouseId = defToId;
        _classList = classes;
        _propertyList = properties;
      });
    } catch (e) {
      setState(() => _lookupError = e.toString());
    } finally {
      setState(() => _loadingLookups = false);
    }

    if (_fromWarehouseId != null) {
      await _downloadMallar();
    }
  }


  Future<void> _downloadMallar() async {

    final url = Uri.parse('http://$globalIp:$globalPort/mallarqaliqfifo?userId=$_fromWarehouseId');

    try {
      final resp = await http.get(url, headers: {'ngrok-skip-browser-warning': 'true'}); // ngrok üçün əlavə header
      if (resp.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mallar_data', resp.body);
        if (mounted) {

        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Məlumatlar yüklənərkən xəta: ${resp.statusCode} ${resp.reasonPhrase}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Serverə qoşulma xətası: $e")),
        );
      }
    }
  }

  void _commitIrCtrl() {
    var code = _irCtrl.text;
    // skaner çox vaxt ardıcıl \r\n ötürür
    code = code.replaceAll('\n', '').replaceAll('\r', '').trim();
    _irCtrl.clear();
    if (code.isEmpty) return;


    _handleInfraredScan(code);

    // Fokus həmişə gizli inputda qalsın
    if (mounted) FocusScope.of(context).requestFocus(_irFocus);
  }



  Future<void> _handleInfraredScan(String barcode) async {
    // ⬇️ Skan edilən kodu vizual görmək üçün:
    /* if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skan: $barcode')),
      );
    }*/
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('mallar_data');
      if (jsonStr == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
              'Məhsul siyahısı boşdur. “Məlumatları yenilə” edin.')),
        );
        return;
      }

      final List<dynamic> allRaw = jsonDecode(jsonStr);
      final List<Map<String, dynamic>> all = allRaw
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList();

      // 1) Tərəzi barkodu?
      final parsed = _parseScaleBarcode(barcode);
      if (parsed != null) {
        final plu = parsed.plu;
        final qty = parsed.qty;

        final matchedScale = all.firstWhere(
              (m) {
            final mPlu = _toInt(m['plu']);
            return mPlu != null && mPlu == plu;
          },
          orElse: () => {},
        );

        if (matchedScale.isEmpty) {
          await _playDingSound1();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                'Tərəzi barkodu üçün məhsul tapılmadı (PLU: $plu)')),
          );
          return;
        }

        final productId = _toInt(matchedScale['idn']);
        if (productId == null) {
          await _playDingSound1();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Məhsulda idn tapılmadı.')),
          );
          return;
        }

        final name = matchedScale['adi']?.toString() ?? '';
        final barkod = matchedScale['barkod']?.toString() ?? '';

        setState(() {
          final idx = _lines.indexWhere((e) => e.productId == productId);
          if (idx != -1) {
            final ex = _lines[idx];
            _lines[idx] = ex.copyWith(qty: ex.qty + qty);
          } else {
            _lines.add(SaleLine(
              productId: productId,
              barcode: barkod.isNotEmpty ? barkod : barcode,
              name: name,
              qty: qty,
              qeyd: '',
            ));
          }
        });
        _incCount(productId);

        if (!mounted) return;
        /*  ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              '“$name” (${qty.toStringAsFixed(3)}) əlavə olundu')),
        );*/
        return;
      }

      // 2) Adi barkod
      final matched = all.firstWhere(
            (m) => (m['barkod']?.toString() ?? '') == barcode,
        orElse: () => {},
      );

      if (matched.isEmpty) {
        await _playDingSound1();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Barkod tapılmadı: $barcode')),
        );
        return;
      }

      final idn = (matched['idn'] as num?)?.toInt();
      final name = matched['adi']?.toString() ?? '';
      final barkod = matched['barkod']?.toString() ?? '';
      if (idn == null) {
        await _playDingSound1();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Məhsul ID tapılmadı.')),
        );
        return;
      }

      // ✅ Adi barkod üçün 1 ədəd avtomatik əlavə
      setState(() {
        final idx = _lines.indexWhere((e) => e.productId == idn);
        if (idx != -1) {
          final ex = _lines[idx];
          _lines[idx] = ex.copyWith(qty: ex.qty + 1);
        } else {
          _lines.add(SaleLine(
            productId: idn,
            barcode: barkod,
            name: name,
            qty: 1,
            qeyd: '',
          ));
        }
      });
      _incCount(idn);

      if (!mounted) return;
      /*ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“$name” (1) əlavə olundu')),
      );*/
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skan xətası: $e')),
      );
    } finally {
      // Fokus itirsə geri qaytaraq
      if (mounted) FocusScope.of(context).requestFocus(_irFocus);
    }
  }


  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_draftKey);
    if (jsonStr == null) return;
    try {
      final m = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _date = DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now();
        _fromWarehouseId = (m['fromWarehouseId'] as num?)?.toInt();
        _toWarehouseId = (m['toWarehouseId'] as num?)?.toInt();
        final arr = (m['lines'] as List<dynamic>? ?? [])
            .map((e) => SaleLine.fromMap(e as Map<String, dynamic>))
            .toList();
        _lines
          ..clear()
          ..addAll(arr);
      });
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'date': _date.toIso8601String(),
      'fromWarehouseId': _fromWarehouseId,
      'toWarehouseId': _toWarehouseId,
      'lines': _lines.map((e) => e.toMap()).toList(),
    };
    await prefs.setString(_draftKey, jsonEncode(map));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() =>
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      ));
      //_saveDraft();
    }
  }

  Future<void> _openProductPicker() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('mallar_data');

    if (jsonStr == null) {
      /*ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Məhsul siyahısı boşdur. “Məlumatları yenilə” edin.')),
      );*/
      return;
    }

    final List<dynamic> allRaw = jsonDecode(jsonStr) as List<dynamic>;
    final List<Map<String, dynamic>> all =
    allRaw.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v))).cast<Map<String, dynamic>>().toList();
    List<Map<String, dynamic>>? filtered = List.of(all);

    final Set<int> justAdded = <int>{};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final TextEditingController nameOrCodeCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 8,
          ),
          child: StatefulBuilder(

            builder: (context, setMS) {
              void doFilter() {
                final queryName = nameOrCodeCtrl.text.toLowerCase().trim();
                final queryMarka = selectedProperty?.name.toLowerCase().trim() ?? '';
                final queryTip = selectedClass?.name.toLowerCase().trim() ?? '';

                setMS(() {
                  filtered = all.where((m) {
                    final name = (m['adi'] ?? '').toString().toLowerCase();
                    final kod = (m['kod'] ?? '').toString().toLowerCase();
                    final marka = (m['marka'] ?? '').toString().toLowerCase();
                    final tip = (m['tip'] ?? '').toString().toLowerCase();

                    final matchNameOrCode =
                        queryName.isEmpty || name.contains(queryName) || kod.contains(queryName);
                    final matchMarka = queryMarka.isEmpty || marka.contains(queryMarka);
                    final matchTip = queryTip.isEmpty || tip.contains(queryTip);

                    return matchNameOrCode && matchMarka && matchTip;
                  }).cast<Map<String, dynamic>>().toList();
                });
              }


              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Məhsul seç',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  // 🔹 3 filter input
                  Column(
                    children: [
                      // 🔹 Ad və ya Kod + Marka
                      Row(
                        children: [
                          // Ad və ya Kod
                          Expanded(
                            child: Row(
                              children: [

                                // 🔸 Input sahəsi
                                Expanded(
                                  child: TextField(
                                    controller: nameOrCodeCtrl,
                                    autofocus: true,
                                    style: const TextStyle(color: Colors.black, fontSize: 14),
                                    cursorColor: Colors.black54,
                                    textInputAction: TextInputAction.search,
                                    decoration: const InputDecoration(
                                      labelText: 'Ad və ya Kod',
                                      prefixIcon: Icon(Icons.search),
                                      prefixIconColor: Colors.black54,
                                      isDense: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(width: 1.6, color: Colors.black54),
                                      ),
                                      labelStyle: TextStyle(color: Colors.black54),
                                      hintStyle: TextStyle(color: Colors.black45),
                                    ),
                                    onChanged: (_) => doFilter(),
                                  ),
                                ),
                                // 🔸 Sol təmizlə düyməsi
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.black54),
                                  tooltip: 'Təmizlə',
                                  onPressed: () {
                                    setState(() {
                                      nameOrCodeCtrl.clear();
                                      doFilter();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          // 🔹 Marka
                          Expanded(
                            child: Row(
                              children: [

                                Expanded(
                                  child: DropdownButtonFormField<LookupItem>(
                                    value: selectedProperty,
                                    decoration: const InputDecoration(
                                      labelText: 'Marka',
                                      isDense: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(width: 1.6, color: Colors.black54),
                                      ),
                                      labelStyle: TextStyle(color: Colors.black54),
                                    ),
                                    items: _propertyList.map((marka) {
                                      return DropdownMenuItem<LookupItem>(
                                        value: marka,
                                        child: Text(marka.name, style: const TextStyle(fontSize: 14, color: Colors.black)),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedProperty = value;
                                        doFilter();
                                      });
                                    },
                                  ),
                                ),
                                // Sol təmizlə düyməsi
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.black54),
                                  tooltip: 'Təmizlə',
                                  onPressed: () {
                                    setState(() {
                                      selectedProperty = null;
                                      doFilter();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      // 🔹 Tip
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [

                                Expanded(
                                  child: DropdownButtonFormField<LookupItem>(
                                    value: selectedClass,
                                    decoration: const InputDecoration(
                                      labelText: 'Tip',
                                      isDense: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(width: 1.6, color: Colors.black54),
                                      ),
                                      labelStyle: TextStyle(color: Colors.black54),
                                    ),
                                    items: _classList.map((type) {
                                      return DropdownMenuItem<LookupItem>(
                                        value: type,
                                        child: Text(type.name, style: const TextStyle(fontSize: 14, color: Colors.black)),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedClass = value;
                                        doFilter();
                                      });
                                    },
                                  ),
                                ),
                                // Sol təmizlə düyməsi
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.black54),
                                  tooltip: 'Təmizlə',
                                  onPressed: () {
                                    setState(() {
                                      selectedClass = null;
                                      doFilter();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // 🔹 ListView + Expanded ilə overflow-un qarşısını alırıq
                  Expanded(
                    child: filtered!.isEmpty
                        ? const Center(child: Text('Nəticə tapılmadı', style: TextStyle(fontSize: 12)))
                        : ListView.separated(
                      itemCount: filtered!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final m = filtered?[index];
                        final idn = (m?['idn'] as num?)?.toInt();
                        final name = (m?['adi'] ?? '').toString();
                        final barkod = (m?['barkod'] ?? '').toString();
                        final marka = (m?['marka'] ?? '').toString();
                        final tip = (m?['tip'] ?? '').toString();
                        final qaliq = (m?['bron_qaliq'] ?? '').toString();
                        final unit = (m?['unit_name'] ?? '').toString();
                        final price = double.tryParse(m?['satis']?.toString() ?? '') ?? 0.0;

                        return ListTile(
                          isThreeLine: true,
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold, // 🔹 Ad qalın
                            ),
                          ),
                          subtitle: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  style: const TextStyle(fontSize: 12, color: Colors.black),
                                  children: [
                                    TextSpan(
                                    text:'Barkod: ',
                                    style: const TextStyle(fontWeight: FontWeight.bold), // 🔹 Qalıq qalın
                                  ),
                                    TextSpan(text: '$barkod | '),
                                    TextSpan(
                                      text:'Qiymət: ${price.toStringAsFixed(2)} AZN\n',
                                      style: const TextStyle(fontWeight: FontWeight.bold), // 🔹 Qalıq qalın
                                    ),
                                    TextSpan(
                                      text:'Marka: ',
                                      style: const TextStyle(fontWeight: FontWeight.bold), // 🔹 Qalıq qalın
                                    ),
                                    TextSpan(text: '$marka | '),

                                    TextSpan(
                                      text:'Tip: ',
                                      style: const TextStyle(fontWeight: FontWeight.bold), // 🔹 Qalıq qalın
                                    ),
                                    TextSpan(text: '$tip\n'),

                                    TextSpan(
                                      text:'Qalıq: $qaliq $unit',
                                      style: const TextStyle(fontWeight: FontWeight.bold), // 🔹 Qalıq qalın
                                    ),
                                  ],
                                ),
                              ),


                              // 🔹 Əgər məhsulun özündə qeyd varsa
                              if ((m?['qeyd'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                  'Qeyd: ${(m?['qeyd'] ?? '').toString()}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black54),
                                ),

                              // 🔹 Əlavə olunma mesajı
                              if (idn != null && justAdded.contains(idn))
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Əlavə olundu',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.green),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            if (idn == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text(
                                    'Seçilən məhsulda idn tapılmadı.')),
                              );
                              return;
                            }

                            final added = await _askQtyAndAdd(
                              productId: idn,
                              barcode: barkod,
                              name: name,
                            );

                            if (added) {
                              setMS(() => justAdded.add(idn)); // ✅ yalnız əlavə olunanda yazılsın
                              Future.delayed(const Duration(seconds: 2), () {
                                if (Navigator.of(ctx).mounted) {
                                  setMS(() => justAdded.remove(idn));
                                }
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }


  Future<void> _scanAndAddProductLoop() async {
    while (mounted) {
      final barcode = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
      );

      // Kamera səhifəsindən geri çıxıbsa — döngünü bitir
      if (barcode == null || barcode
          .trim()
          .isEmpty) break;

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('mallar_data');
      if (jsonStr == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
              'Məhsul siyahısı boşdur. “Məlumatları yenilə” edin.')),
        );
        break; // məlumat yoxdursa, döngünü dayandır
      }

      final List<dynamic> allRaw = jsonDecode(jsonStr);
      final List<Map<String, dynamic>> all = allRaw
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList();

      // 1) Tərəzi barkodu?
      final parsed = _parseScaleBarcode(barcode);
      if (parsed != null) {
        final plu = parsed.plu;
        final qty = parsed.qty;

        final matchedScale = all.firstWhere(
              (m) {
            final mPlu = _toInt(m['plu']);
            return mPlu != null && mPlu == plu;
          },
          orElse: () => {},
        );

        if (matchedScale.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                'Tərəzi barkodu üçün məhsul tapılmadı (PLU: $plu)')),
          );
          // Tərəzi barkodu tapılmadı — yenə də skan etməyə davam et
          continue;
        }

        final productId = _toInt(matchedScale['idn']);
        if (productId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Məhsulda idn tapılmadı.')),
          );
          // Davam et
          continue;
        }

        final name = matchedScale['adi']?.toString() ?? '';
        final barkod = matchedScale['barkod']?.toString() ?? '';

        await _askQtyAndAdd(
          productId: productId,
          barcode: barkod.isNotEmpty ? barkod : barcode,
          name: name,
          presetQty: qty,
          bypassDialog: true,
        );

        if (!mounted) break;
        /*  ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              '“$name” (${qty.toStringAsFixed(3)}) əlavə olundu')),
        );*/

        // ✅ Tərəzi barkodunda avtomatik olaraq NÖVBƏTİ skan üçün döngü davam edir
        continue;
      }

      // 2) Adi barkod
      final matched = all.firstWhere(
            (m) => (m['barkod']?.toString() ?? '') == barcode,
        orElse: () => {},
      );

      if (matched.isEmpty) {
        await _playDingSound1();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Barkod tapılmadı: $barcode')),
        );
        // Tapılmadı — yenə skan etməyə davam edək
        continue;
      }

      final idn = (matched['idn'] as num?)?.toInt();
      final name = matched['adi']?.toString() ?? '';
      final barkod = matched['barkod']?.toString() ?? '';

      if (idn == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Məhsul ID tapılmadı.')),
        );
        // Davam
        continue;
      }

      // Miqdar dialoqu — yalnız OK basılarsa yenidən skan edəcəyik
      final added = await _askQtyAndAdd(
        productId: idn,
        barcode: barkod,
        name: name,
      );

      if (!mounted) break;

      if (added) {
        /*ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('“$name” əlavə olundu')),
        );*/
        // ✅ OK basıldı — növbəti skana KEÇ
        continue;
      } else {
        // ❌ Ləğv olundu — döngünü dayandır
        break;
      }
    }
  }

  Future<bool> _askQtyAndAdd({
    required int productId,
    required String barcode,
    required String name,
    double? presetQty,
    bool bypassDialog = false,
  }) async {
    // Birbaşa əlavə (dialoq açmadan)
    if (bypassDialog && presetQty != null) {
      setState(() {
        final idx = _lines.indexWhere((e) => e.productId == productId);
        if (idx != -1) {
          final ex = _lines[idx];
          _lines[idx] = ex.copyWith(qty: ex.qty + presetQty);
        } else {
          _lines.add(SaleLine(
            productId: productId,
            barcode: barcode,
            name: name,
            qty: presetQty,
            qeyd: '', // qeyd sahən varsa uyğun doldur
          ));
        }
      });
      _incCount(productId);
      if (mounted) FocusScope.of(context).requestFocus(_irFocus); // ⬅️ əlavə et
      return true;
    }

    // ==== aşağısı sənin köhnə dialoqun (sadəcə default dəyərləri yenilədik) ====
    final qtyCtrl = TextEditingController(text: (presetQty ?? 1).toString());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      qtyCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: qtyCtrl.text.length);
    });

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: const Text('Miqdar'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onTap: () =>
                  qtyCtrl.selection =
                      TextSelection(
                          baseOffset: 0, extentOffset: qtyCtrl.text.length),
                  decoration: const InputDecoration(
                    labelText: 'Miqdar',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Ləğv et')),
              FilledButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('Əlavə et')),
            ],
          ),
    );

    if (ok != true) return false; // ❌ istifadəçi ləğv etdi

    final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ??
        (presetQty ?? 1.0);

    setState(() {
      final idx = _lines.indexWhere((e) => e.productId == productId);
      if (idx != -1) {
        final ex = _lines[idx];
        _lines[idx] = ex.copyWith(qty: ex.qty + qty);
      } else {
        _lines.add(SaleLine(
          productId: productId,
          barcode: barcode,
          name: name,
          qty: qty,
          qeyd: '',
        ));
      }
    });
    _incCount(productId);
    return true; // ✅ əlavə olundu
  }


  Future<void> _editLine(int index) async {
    final line = _lines[index];
    final qtyCtrl = TextEditingController(text: line.qty.toString());
    final qeydCtrl = TextEditingController(text: line.qeyd);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: const Text('Düzəliş et'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onTap: () =>
                  qtyCtrl.selection =
                      TextSelection(
                          baseOffset: 0, extentOffset: qtyCtrl.text.length),
                  decoration: const InputDecoration(
                    labelText: 'Miqdar',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: qeydCtrl, // ✅
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Qeyd',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Ləğv et')),
              FilledButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yadda saxla')),
            ],
          ),
    );

    if (ok != true) return;

    final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? line.qty;
    final ln = qeydCtrl.text.trim();

    setState(() {
      _lines[index] = line.copyWith(qty: qty, qeyd: ln);
    });
    if (mounted) FocusScope.of(context).requestFocus(_irFocus); // ⬅️ əlavə et
  }

  Future<void> _deleteLine(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: const Text('Məhsulu sil'),
            content: const Text('Bu məhsulu silmək istəyirsiniz?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Xeyr')),
              FilledButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('Bəli, sil')),
            ],
          ),
    );
    if (ok == true) {
      final pid = _lines[index].productId;
      setState(() {
        _lines.removeAt(index);
        _addedCounts.remove(pid); // ✅ məhsul tam silinibsə sayğacı da sil
      });
      if (mounted) FocusScope.of(context).requestFocus(_irFocus); // ⬅️ əlavə et
    }
  }


  Future<void> _playDingSound1() async {
    await _audioPlayer1.play(AssetSource('sounds/not.mp3'));
  }

  Future<void> _scanAndAddProduct() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (barcode == null || barcode
        .trim()
        .isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('mallar_data');
    if (jsonStr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
            'Məhsul siyahısı boşdur. “Məlumatları yenilə” edin.')),
      );
      return;
    }

    final List<dynamic> allRaw = jsonDecode(jsonStr);
    final List<Map<String, dynamic>> all = allRaw
        .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
        .cast<Map<String, dynamic>>()
        .toList();

    // ... _scanAndAddProduct() daxilində, parsed != null olduqda:
    final parsed = _parseScaleBarcode(barcode);
    if (parsed != null) {
      final plu = parsed.plu;
      final qty = parsed.qty;


      // ✅ Məhsulu PLU-ya görə tap
      final matchedScale = all.firstWhere(
            (m) {
          final mPlu = _toInt(
              m['plu']); // 'plu' sahəsi DB-dən gəlir deyə dedino
          return mPlu != null && mPlu == plu;
        },
        orElse: () => {},
      );


      if (matchedScale.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              'Tərəzi barkodu üçün məhsul tapılmadı (PLU: $plu)')),
        );
        return;
      }

      // ⚠️ productId serverə göndəriləcək idn-dir – obyektin idn sahəsindən götürürük
      final productId = _toInt(matchedScale['idn']);
      if (productId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Məhsulda idn tapılmadı.')),
        );
        return;
      }

      final name = matchedScale['adi']?.toString() ?? '';
      final barkod = matchedScale['barkod']?.toString() ?? ''; // baza barkod

      await _askQtyAndAdd(
        productId: productId,
        // ✅ server üçün idn
        barcode: barkod.isNotEmpty ? barkod : barcode,
        // göstərim üçün
        name: name,
        presetQty: qty,
        bypassDialog: true, // dialoqsuz əlavə
      );

      if (!mounted) return;
      /* ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('“$name” (${qty.toStringAsFixed(3)}) əlavə olundu')),
      );*/
      return;
    }

    final matched = all.firstWhere(
          (m) => (m['barkod']?.toString() ?? '') == barcode,
      orElse: () => {},
    );


    if (matched.isEmpty) {
      await _playDingSound1();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barkod tapılmadı: $barcode')),
      );
      return;
    }

    final idn = (matched['idn'] as num?)?.toInt();
    final name = matched['adi']?.toString() ?? '';
    final barkod = matched['barkod']?.toString() ?? '';

    if (idn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Məhsul ID tapılmadı.')),
      );
      return;
    }

    await _askQtyAndAdd(
      productId: idn,
      barcode: barkod,
      name: name,
      // adi barkod üçün dialoq açılacaq (presetQty vermədik)
    );

    if (!mounted) return;
    /* ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('“$name” əlavə olundu')),
    );*/
  }


  bool _isScaleBarcode(String bc) {
    // Adətən 13 rəqəm və 20/22 prefix
    if (bc.length != 13) return false;
    return bc.startsWith('$globaleded') || bc.startsWith('$globalceki');
  }

  // 13 rəqəm, prefix globaleded/globalceki; PLU: [3..6], Miqdar: [7..11] (/1000)
  ({int plu, double qty})? _parseScaleBarcode(String bc) {
    try {
      if (!_isScaleBarcode(bc)) return null;
      final pluStr = bc.substring(3, 7); // əvvəl idn götürürdün, indi PLU
      final qtyStr = bc.substring(7, 12);
      final plu = int.parse(pluStr);
      final qty = int.parse(qtyStr) / 1000.0;
      if (qty <= 0) return null;
      return (plu: plu, qty: qty);
    } catch (_) {
      return null;
    }
  }


  Future<void> _submit() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Məhsul əlavə olunmayıb.')),
      );
      return;
    }
    if (_fromWarehouseId == null || _toWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Göndərən və Qəbul anbarı seçilməyib.')),
      );
      return;
    }
    if (_fromWarehouseId == _toWarehouseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Göndərən və Qəbul anbarı eyni ola bilməz.')),
      );
      return;
    }
    if (_lines.any((e) => e.productId <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Məhsul id-si (idn) yoxdur.')),
      );
      return;
    }

    final payload = {
      'date': _date.toIso8601String(),
      'fromWarehouseId': _fromWarehouseId,
      'toWarehouseId': _toWarehouseId,
      'userId': globalTermname,
      'note': _noteCtrl.text.trim(),
      'lines': _lines
          .map((e) =>
      {
        'idn': e.productId,
        'qty': e.qty,
      })
          .toList(),
      'totalQty': _totalQty,
    };

    setState(() => _submitting = true);
    try {
      final base = await _getBaseUrl();
      final resp = await http
          .post(
        Uri.parse('$base/transfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        await _clearDraft();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer sənədi saxlanıldı')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xəta: ${resp.statusCode} — ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Şəbəkə xətası: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final canChangeDate = globalAllowDateChange; // qlobaldan oxu

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      backgroundColor: const Color(0xFFF3F4F6),

      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // ✅ Overlay + Gizli TextField + Kontent
        child: Stack(
          children: [


            // 1) Sənin mövcud kontentin
            _loadingLookups
                ? const Center(child: CircularProgressIndicator())
                : _lookupError != null
                ? Center(child: Text('Yükləmə xətası: $_lookupError'))
                : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(6),
                children: [
                  // HEADER KARTI
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        children: [
                          // 1-ci sıra: Tarix
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 160,
                                child: IgnorePointer(
                                  ignoring: !canChangeDate,
                                  child: Opacity(
                                    opacity: canChangeDate ? 1 : 0.5,
                                    child: _HeaderTile(
                                      label: 'Tarix',
                                      value: df.format(_date),
                                      onTap: canChangeDate
                                          ? _pickDate
                                          : () {},
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 50),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 2-ci sıra: Mənbə + Təyinat anbarı
                          Row(
                            children: [
                              Expanded(
                                child: _HeaderDropdownGeneric(
                                  label: 'Göndərən anbar',
                                  selectedId: _fromWarehouseId,
                                  items: _fromWarehouses,
                                  onChanged: (id) {
                                    setState(() =>
                                    _fromWarehouseId = id);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HeaderDropdownGeneric(
                                  label: 'Qəbul anbarı',
                                  selectedId: _toWarehouseId,
                                  items: _toWarehouses,
                                  onChanged: (id) {
                                    setState(
                                            () => _toWarehouseId = id);
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // 4-cü sıra: Qeyd
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _noteCtrl,
                                  style:
                                  const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    labelText: 'Qeyd',
                                    labelStyle: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                    enabledBorder:
                                    OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.black54,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // LİST KARTI
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 1,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: Row(
                            children: [
                              // ⬅️ Barkod sahəsi (görünən, fokus alıb işləyəcək)
                              Expanded(
                                child: TextField(
                                  controller: _irCtrl,
                                  focusNode: _irFocus,               // fokus verəcəksən: tap/scan
                                  keyboardType: TextInputType.none,  // OSK açılmasın
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Barkod',
                                    prefixIcon: const Icon(Icons.barcode_reader, size: 18, color: Colors.black87),
                                    suffixIcon: (_irCtrl.text.isNotEmpty)
                                        ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _irCtrl.clear();
                                        FocusScope.of(context).requestFocus(_irFocus); // fokus saxla
                                      },
                                    )
                                        : null,
                                    border: const OutlineInputBorder(),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(width: 1.6, color: Colors.black87),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  onSubmitted: (_) => _commitIrCtrl(), // skaner Enter göndərirsə
                                ),
                              ),

                              const SizedBox(width: 8),

                              // ➕ Əlavə et
                              FilledButton.icon(
                                onPressed: _submitting ? null : _openProductPicker,
                                icon: const Icon(Icons.add, size: 12),
                                label: const Text('Əlavə et', style: TextStyle(fontSize: 12)),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(80, 34),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),

                              const SizedBox(width: 6),

                              // 🔍 Skan et (kamera)
                              FilledButton.icon(
                                onPressed: _submitting ? null : _scanAndAddProductLoop,
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: const Text('Skan et', style: TextStyle(fontSize: 12)),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(80, 34),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),


                        const Divider(height: 1),
                        if (_lines.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Siyahı boşdur.'),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics:
                            const NeverScrollableScrollPhysics(),
                            itemCount: _lines.length,
                            separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final l = _lines[index];
                              final addCount =
                                  _addedCounts[l.productId] ?? 1;
                              return Dismissible(
                                key: ValueKey(
                                    '${l.productId}-$index'),
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(
                                      left: 12),
                                  child: const Icon(Icons.delete,
                                      color: Colors.white),
                                ),
                                direction:
                                DismissDirection.startToEnd,
                                confirmDismiss: (_) async {
                                  await _deleteLine(index);
                                  return false;
                                },
                                child: ListTile(
                                  title: Text(l.name),
                                  subtitle: Text(
                                    'Barkod: ${l.barcode}\n'
                                        'Miqdar: ${_fmt18_3(l.qty)}\n'
                                        'Qeyd: ${l.qeyd}\n'
                                        'Qutu sayı: $addCount',
                                  ),

                                  onTap: () => _editLine(index),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              12, 10, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Sətir: $_lineCount',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Miqdar: ${_fmt18_3(_totalQty)}',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Qutu sayı: $_totalAddedCount',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // TOTAL + ACTIONS
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                              _submitting ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Icon(Icons.check),
                              label: Text(_submitting
                                  ? 'Göndərilir...'
                                  : 'Təsdiqlə'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),


          ],
        ),
      ),
    );
  }


  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }
}


/// ==== Köməkçi UI vidcetləri ====


// Ümumi şrift ölçüsü üçün sabit
const double kGlobalBaseFontSize = 13.0; // Vahid şrift ölçüsü

// Tarix üçün kliklənən tile
class _HeaderTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _HeaderTile({
    super.key, // super.key əlavə etdim
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: kGlobalBaseFontSize - 1, // label bir az kiçik
          color: Colors.black87,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black54),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12), // kassa field ilə eyni hündürlük
          child: Row(
            children: [
              const Icon(Icons.event, size: 18, color: Colors.black87), // istəsən silə bilərsən
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value, // df.format(_date) gəlir
                  style: TextStyle(
                    fontSize: kGlobalBaseFontSize, // əsas mətn ölçüsü
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderDropdownGeneric extends StatelessWidget {
  final String label;
  final dynamic selectedId; // int və ya String ola bilər
  final List<LookupItem> items;
  final ValueChanged<dynamic?> onChanged; // int və ya String ola bilər
  final bool enabled;

  const _HeaderDropdownGeneric({
    super.key, // super.key əlavə etdim
    required this.label,
    required this.selectedId,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: kGlobalBaseFontSize - 1, // Label bir az daha kiçik
          color: Colors.black87,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black54),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), // Padding-i bir az tənzimlədim
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>( // value və onChanged-in tipi dynamic oldu
          value: selectedId,
          isExpanded: true,
          iconSize: 18,iconEnabledColor: Colors.black87,
          style: TextStyle(
            fontSize: kGlobalBaseFontSize, // Seçilmiş elementin mətni
            color: Colors.black87,
          ),
          items: items.map((e) {
            return DropdownMenuItem<dynamic>( // value tipi dynamic oldu
              value: e.id,
              child: Text(
                e.name,
                style: TextStyle(
                  fontSize: kGlobalBaseFontSize,fontWeight: FontWeight.w500, // Siyahıdakı elementlərin mətni
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis, // Uzun mətnlər üçün
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}


// 🔎 Müştəri üçün axtarışlı picker (bottom sheet ilə)
class _CustomerSearchPicker extends StatelessWidget {
  final String label;
  final String valueText; // göstərilən seçilmiş dəyər
  final List<LookupItem> items;
  final ValueChanged<LookupItem?> onSelected;

  // valueTextFontSize və labelFontSize parametrləri qaldı,
  // amma əgər təyin edilməsələr kGlobalBaseFontSize istifadə olunacaq.
  final double? valueTextFontSize;
  final double? labelFontSize;

  const _CustomerSearchPicker({
    super.key,
    required this.label,
    required this.valueText,
    required this.items,
    required this.onSelected,
    this.valueTextFontSize,
    this.labelFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        label: Text(
          label,
          style: TextStyle(fontSize: labelFontSize ?? kGlobalBaseFontSize -1, color: Colors.black87), // Label bir az kiçik
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
      child: InkWell(
        onTap: () => _openSearch(context),
        child: Row(
          children: [
            //const Icon(Icons.person_search, size: 18),
            //const SizedBox(width: 8),
            Expanded(
              child: Text(
                valueText,
                style: TextStyle(fontSize: valueTextFontSize ?? kGlobalBaseFontSize, color:  Colors.black87), // Əsas mətn
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down,size: 18,color: Colors.black87,),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    List<LookupItem> filtered = List.of(items);
    final ctrl = TextEditingController();
    // Tema-nı burada almağa ehtiyac yoxdur, birbaşa TextStyle istifadə edəcəyik

    final selected = await showModalBottomSheet<LookupItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 8,
          ),
          child: StatefulBuilder(
            builder: (ctx, setMS) {
              void doFilter(String q) {
                final query = q.toLowerCase().trim();
                setMS(() {
                  filtered = items.where((e) =>
                  e.name.toLowerCase().contains(query) ||
                      e.id.toString().toLowerCase().contains(query) // id-ni də kiçik hərflə axtar
                  ).toList();
                });
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Müştəri seç',
                      style: GoogleFonts.poppins(
                          fontSize: kGlobalBaseFontSize, // Başlıq üçün əsas ölçü
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: TextStyle(fontSize: kGlobalBaseFontSize, color: Colors.black87), // Daxil edilən mətn
                      cursorColor: Colors.black87,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Axtar',
                        labelStyle: TextStyle(fontSize: kGlobalBaseFontSize -1), // Label bir az kiçik
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      ),
                      onChanged: doFilter,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: MediaQuery.of(ctx).size.height * 0.5, // Hündürlüyü tənzimləyə bilərsiniz
                      child: filtered.isEmpty
                          ? Center(child: Text('Nəticə tapılmadı', style: TextStyle(fontSize: kGlobalBaseFontSize -1 ))) // Kiçik mətn
                          : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final it = filtered[i];
                          return ListTile(
                            leading: const Icon(Icons.person_outline, size: 20),
                            title: Text(
                              it.name,
                              style: TextStyle(fontSize: kGlobalBaseFontSize), // Siyahı elementi
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            dense: true,
                            onTap: () => Navigator.pop(ctx, it),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (context.mounted && selected != null) { // selected null ola bilər, onSelected-i çağırmazdan əvvəl yoxla
      onSelected(selected);
    } else if (context.mounted && selected == null) {
      onSelected(null); // İstifadəçi heç nə seçməyibsə null göndər
    }
  }
}
