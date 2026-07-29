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

final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

final AudioPlayer _audioPlayer1 = AudioPlayer();

BluetoothDevice? _printer;
bool _btConnecting = false;
bool _btConnected  = false;


// === BLUETOOTH PRINTER DƏYİŞƏNLƏRİ ===
List<BluetoothDevice> _bluetoothDevices = []; // Adı _devices ilə qarışmasın deyə dəyişdim
BluetoothDevice? _selectedBluetoothDevice;
bool _isBluetoothConnected = false;
bool _isLoadingBluetoothAction = false; // Qoşulma/çap zamanı loading üçün



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
  final double price;
  final double qty;
  final String qeyd;

  SaleLine({
    required this.productId,
    required this.barcode,
    required this.name,
    required this.price,
    required this.qty,
    required this.qeyd,
  });

  SaleLine copyWith({
    int? productId,
    String? barcode,
    String? name,
    double? price,
    double? qty,
    String? qeyd,
  }) {
    return SaleLine(
      productId: productId ?? this.productId,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      qeyd: qeyd ?? this.qeyd,
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId, // 🔹 draft üçün
    'barcode': barcode,
    'name': name,
    'price': price,
    'qty': qty,
  };

  factory SaleLine.fromMap(Map<String, dynamic> m) => SaleLine(
    productId: (m['productId'] as num).toInt(),
    barcode: (m['barcode'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    price: (m['price'] as num).toDouble(),
    qty: (m['qty'] as num).toDouble(),
    qeyd: (m['qeyd'] ?? '').toString(),
  );
}

/// ---- SƏHİFƏ ----


final NumberFormat _qtyFmt18_3 = NumberFormat('#,###0.000', 'az'); // 1 234,56 kimi
String _fmt18_3(num v) => _qtyFmt18_3.format(v);


class GeriPage extends StatefulWidget {
  const GeriPage({super.key});

  @override
  State<GeriPage> createState() => _GeriPageState();
}

class _GeriPageState extends State<GeriPage> {
  final _formKey = GlobalKey<FormState>();

  // Header sahələri
  DateTime _date = DateTime.now();

  int? _selectedCustomerId;
  String? _selectedCustomerName;

  int? _selectedCashDeskId;
  int? _selectedWarehouseId;

  String _paymentType = 'Nisyə'; // 'Nağd' | 'Nisyə'

  // Lookup siyahıları (API-dən)
  List<LookupItem> _customers = [];
  List<LookupItem> _cashDesks = [];
  List<LookupItem> _warehouses = [];

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
  Timer? _irCtrlTimer;
  DateTime? _irCtrlLastAt;
  static const int _irCtrlGapMs = 300; // sükutla tamamla

// Vizual debug/overlay üçün
  String _irDebugBuffer = '';
  String? _lastScanned;

// (istəsəniz duplikat skanların qarşısını almaq üçün)
  String? _lastCommitted;
  DateTime? _lastCommittedAt;



  // Draft saxlanması üçün aç
  static const String _draftKey = 'geri_draft';


  double get _totalQty => _lines.fold(0.0, (s, e) => s + e.qty);
  int get _lineCount => _lines.length;


  final Map<int, int> _addedCounts = {}; // productId -> neçə dəfə əlavə olunub

  void _incCount(int productId) {
    _addedCounts.update(productId, (v) => v + 1, ifAbsent: () => 1);
  }
  int get _totalAddedCount =>
      _addedCounts.values.fold(0, (sum, v) => sum + v);


  double get _total => _lines.fold(0.0, (sum, e) => sum + (e.price * e.qty));


  @override
  void initState() {
    super.initState();

    _irCtrl.addListener(_onIrCtrlChanged);

    _loadDraft().then((_) {
      _loadLookups();
      _autoConnectSavedPrinter();
    });


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
    _irCtrlTimer?.cancel();
    _irCtrl.dispose();
    _irFocus.dispose();
    super.dispose();
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static const String kSavedPrinterAddrKey = 'saved_printer_address';

  /// Cütləşdirilmiş siyahıda MAC-ə görə cihazı tapır (tapmasa null qaytarır)
  BluetoothDevice? _findByAddress(List<BluetoothDevice> list, String addr) {
    try {
      return list.firstWhere((d) => (d.address ?? '') == addr);
    } catch (_) {
      return null; // ✅ firstWhere orElse: null vermək olmaz, ona görə try/catch
    }
  }

  /// Yaddaşda saxlanmış MAC-ə əsasən cütləşdirilmiş siyahıdan cihazı qaytarır
  Future<BluetoothDevice?> _loadPreferredPrinter(List<BluetoothDevice> bonded) async {
    final prefs = await SharedPreferences.getInstance();
    final addr = prefs.getString(kSavedPrinterAddrKey);
    if (addr == null || addr.isEmpty) return null;
    return _findByAddress(bonded, addr);
  }


  Future<void> _autoConnectSavedPrinter() async {
    try {
      // 1) cütləşdirilmiş cihazları götür
      final bonded = await bluetooth.getBondedDevices();

      // 2) yaddaşdakı ünvanı tap
      final prefs = await SharedPreferences.getInstance();
      final addr = prefs.getString(kSavedPrinterAddrKey);

      if (addr == null || addr.isEmpty) return; // seçilməyib

      // 3) siyahıda həmin cihazı tap
      final match = _findByAddress(bonded, addr); // BluetoothDevice?
      if (match == null) return;
      _printer = match;
      await bluetooth.connect(match);

      if (match == null) return;

      _printer = match;

      // 4) artıq qoşuludursa, keç
      final isConn = await bluetooth.isConnected ?? false;
      if (isConn) {
        setState(() => _btConnected = true);
        return;
      }

      // 5) qoşul
      if (_btConnecting) return;
      _btConnecting = true;
      await bluetooth.connect(match);
      setState(() => _btConnected = true);
    } catch (e) {
      setState(() => _btConnected = false);
    } finally {
      _btConnecting = false;
    }
  }




  // 🔧 IP/Port yalnız global-dan; boşdursa xətaya çıx
  Future<String> _getBaseUrl() async {
    if (globalIp == null ||
        globalPort == null ||
        globalIp!.trim().isEmpty ||
        globalPort!.toString().trim().isEmpty) {
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

  /// LOOKUP-ları yüklə: /musteri, /kassa, /anbar
  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });

    try {
      final base = await _getBaseUrl();

      final responses = await Future.wait([
        http.get(Uri.parse('$base/kontra')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$base/kassa?userId=$globalTermname')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$base/anbar?userId=$globalTermname')).timeout(const Duration(seconds: 15)),
      ]);

      if (responses.any((r) => r.statusCode != 200)) {
        throw Exception('Lookup yüklənmə xətası (status != 200)');
      }

      final custJson = jsonDecode(responses[0].body) as List;
      final kassJson = jsonDecode(responses[1].body) as List;
      final anbJson = jsonDecode(responses[2].body) as List;

      final customers = custJson.map((e) => LookupItem.fromMap(e)).toList();
      final kassas = kassJson.map((e) => LookupItem.fromMap(e)).toList();
      final anbars = anbJson.map((e) => LookupItem.fromMap(e)).toList();

      setState(() {
        _customers = customers;
        _cashDesks = kassas;
        _warehouses = anbars;

        // Əgər draftdan ID-lər gəlməyibsə, ilk elementləri seç
        // _selectedCustomerId ??= _customers.isNotEmpty ? _customers.first.id : null;
        // _selectedCustomerName ??= _customers.isNotEmpty ? _customers.first.name : null;

        _selectedCashDeskId ??= _cashDesks.isNotEmpty ? _cashDesks.first.id : null;
        _selectedWarehouseId ??= _warehouses.isNotEmpty ? _warehouses.first.id : null;
      });
    } catch (e) {
      setState(() => _lookupError = e.toString());
    } finally {
      setState(() => _loadingLookups = false);
    }
  }



  bool _isDuplicateCommit(String code) {
    final now = DateTime.now();
    if (_lastCommitted == code &&
        _lastCommittedAt != null &&
        now.difference(_lastCommittedAt!).inMilliseconds < 300) {
      return true;
    }
    _lastCommitted = code;
    _lastCommittedAt = now;
    return false;
  }

  void _scheduleCtrlCommit() {
    _irCtrlTimer?.cancel();
    _irCtrlTimer = Timer(const Duration(milliseconds: _irCtrlGapMs + 50), () {
      if (_irCtrlLastAt == null) return;
      final ms = DateTime.now().difference(_irCtrlLastAt!).inMilliseconds;
      if (ms >= _irCtrlGapMs && _irCtrl.text.isNotEmpty) {
        _commitIrCtrl();
      }
    });
  }
  void _onIrCtrlChanged() {
    // Gizli inputa gələn canlı mətn
    final val = _irCtrl.text;
    _irCtrlLastAt = DateTime.now();
    _irDebugBuffer = val;
    setState(() {}); // overlay-də “Gələn: …” görünsün

    // ENTER/CR/LF varsa dərhal tamamla
    if (val.endsWith('\n') || val.endsWith('\r')) {
      _commitIrCtrl();
    } else {
      _scheduleCtrlCommit(); // yoxsa sükutla tamamlayacağıq
    }
  }

  void _commitIrCtrl() {
    var code = _irCtrl.text;
    // skaner çox vaxt ardıcıl \r\n ötürür
    code = code.replaceAll('\n', '').replaceAll('\r', '').trim();
    _irCtrl.clear();
    _irDebugBuffer = '';
    if (code.isEmpty) return;

    if (_isDuplicateCommit(code)) return; // ehtiyat üçün

    setState(() => _lastScanned = code);
    debugPrint('IR CTRL -> $code');

    // İstifadəçiyə də göstər
    /*ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Skan: $code')),
    );*/

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
        final price  = double.tryParse(matchedScale['satis']?.toString() ?? '') ?? 0.0;

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
              price: price,
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
      final price  = double.tryParse(matched['satis']?.toString() ?? '') ?? 0.0;
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
            price: price,
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

        _selectedCustomerId = (m['customerId'] as num?)?.toInt();
        _selectedCustomerName = (m['customerName'] ?? '') as String?;

        _selectedCashDeskId = (m['cashdeskId'] as num?)?.toInt();
        _selectedWarehouseId = (m['warehouseId'] as num?)?.toInt();

        _paymentType = (m['payment'] ?? _paymentType).toString();

        final arr = (m['lines'] as List<dynamic>? ?? [])
            .map((e) => SaleLine.fromMap(e as Map<String, dynamic>))
            .toList();
        _lines
          ..clear()
          ..addAll(arr);
      });
    } catch (_) {
      // ignore parse error
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'date': _date.toIso8601String(),
      'customerId': _selectedCustomerId,
      'customerName': _selectedCustomerName,
      'cashdeskId': _selectedCashDeskId,
      'warehouseId': _selectedWarehouseId,
      'userId' : globalTermname,
      'payment': _paymentType,
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
      setState(() => _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      ));
      //_saveDraft();
    }
  }

  /// ---- MƏHSUL SEÇİMİ (lokal mallar_data) ----
  Future<void> _openProductPicker() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('mallar_data');

    if (jsonStr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Məhsul siyahısı boşdur. “Məlumatları yenilə” edin.')),
      );
      return;
    }

    final List<dynamic> allRaw = jsonDecode(jsonStr) as List<dynamic>;
    final List<Map<String, dynamic>> all =
    allRaw.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v))).cast<Map<String, dynamic>>().toList();
    List<Map<String, dynamic>>? filtered = List.of(all);
    String query = '';
    //List<Map<String, dynamic>>? filtered = List.of(all as Iterable<Map<String, dynamic>>);

    final Set<int> justAdded = <int>{};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 8,
          ),
          child: StatefulBuilder(

            builder: (context, setMS) {
              void doFilter(String q) {
                query = q.toLowerCase().trim();
                setMS(() {
                  filtered = all.where((m) {
                    final name = (m['adi'] ?? '').toString().toLowerCase();
                    final barkod = (m['barkod'] ?? '').toString().toLowerCase();
                    return name.contains(query) || barkod.contains(query);
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

                  // 🔹 Axtarış inputu
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                    cursorColor: Colors.black54,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Ad və ya barkod axtar',
                      prefixIcon: Icon(Icons.search),
                      prefixIconColor: Colors.black54,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(width: 1.6, color: Colors.black54),
                      ),
                      labelStyle: TextStyle(color: Colors.black54),
                      hintStyle: TextStyle(color: Colors.black45),
                    ),
                    onChanged: doFilter,
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
                        final price =
                            double.tryParse(m?['satis']?.toString() ?? '') ?? 0.0;

                        return ListTile(
                          isThreeLine: true,
                          title: Text(name, style: const TextStyle(fontSize: 12)),
                          subtitle: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Barkod: $barkod  |  Qiymət: ${price.toStringAsFixed(2)} AZN',
                                style: const TextStyle(fontSize: 12),
                              ),

                              // 🔹 Əgər məhsulun özündə qeyd varsa
                              if ((m?['qeyd'] ?? '').toString().isNotEmpty)
                                Text(
                                  'Qeyd: ${(m?['qeyd'] ?? '').toString()}',
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),

                              // 🔹 Əlavə olunma mesajı
                              if (idn != null && justAdded.contains(idn))
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Əlavə olundu',
                                    style: TextStyle(fontSize: 12, color: Colors.green),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            if (idn == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Seçilən məhsulda idn tapılmadı.')),
                              );
                              return;
                            }

                            await _askQtyAndAdd(
                              productId: idn,
                              barcode: barkod,
                              name: name,
                              price: price,
                            );

                            setMS(() => justAdded.add(idn));
                            Future.delayed(const Duration(seconds: 2), () {
                              if (Navigator.of(ctx).mounted) {
                                setMS(() => justAdded.remove(idn));
                              }
                            });
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

  Future<bool> _askQtyAndAdd({
    required int productId,
    required String barcode,
    required String name,
    required double price,
    double? presetQty,
    double? presetPrice,
    bool bypassDialog = false,
  }) async {
    // Birbaşa əlavə (dialoq açmadan)
    if (bypassDialog && presetQty != null) {
      setState(() {
        final idx = _lines.indexWhere((e) => e.productId == productId);
        if (idx != -1) {
          final ex = _lines[idx];
          _lines[idx] = ex.copyWith(qty: ex.qty + presetQty, price: presetPrice ?? price);
        } else {
          _lines.add(SaleLine(
            productId: productId,
            barcode: barcode,
            name: name,
            price: presetPrice ?? price,
            qty: presetQty,
            qeyd: '', // qeyd sahən varsa uyğun doldur
          ));
        }
      });
      _incCount(productId);
      return true;
    }

    // ==== aşağısı sənin köhnə dialoqun (sadəcə default dəyərləri yenilədik) ====
    final qtyCtrl = TextEditingController(text: (presetQty ?? 1).toString());
    final priceCtrl = TextEditingController(text: (presetPrice ?? price).toStringAsFixed(2));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      qtyCtrl.selection = TextSelection(baseOffset: 0, extentOffset: qtyCtrl.text.length);
    });

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Miqdar / Qiymət'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onTap: () => qtyCtrl.selection =
                  TextSelection(baseOffset: 0, extentOffset: qtyCtrl.text.length),
              decoration: const InputDecoration(
                labelText: 'Miqdar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onTap: () => priceCtrl.selection =
                  TextSelection(baseOffset: 0, extentOffset: priceCtrl.text.length),
              decoration: const InputDecoration(
                labelText: 'Satış qiyməti',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv et')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Əlavə et')),
        ],
      ),
    );

    if (ok != true) return false; // ❌ istifadəçi ləğv etdi

    final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? (presetQty ?? 1.0);
    final prc = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? (presetPrice ?? price);

    setState(() {
      final idx = _lines.indexWhere((e) => e.productId == productId);
      if (idx != -1) {
        final ex = _lines[idx];
        _lines[idx] = ex.copyWith(qty: ex.qty + qty, price: prc);
      } else {
        _lines.add(SaleLine(
          productId: productId,
          barcode: barcode,
          name: name,
          price: prc,
          qty: qty,
          qeyd: '',
        ));
      }
    });
    _incCount(productId);
    return true; // ✅ əlavə olundu
  }

  Future<void> _scanAndAddProductLoop() async {
    while (mounted) {
      final barcode = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
      );

      // Kamera səhifəsindən geri çıxıbsa — döngünü bitir
      if (barcode == null || barcode.trim().isEmpty) break;

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('mallar_data');
      if (jsonStr == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Məhsul siyahısı boşdur. “Məlumatları yenilə” edin.')),
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
            SnackBar(content: Text('Tərəzi barkodu üçün məhsul tapılmadı (PLU: $plu)')),
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

        final name   = matchedScale['adi']?.toString() ?? '';
        final barkod = matchedScale['barkod']?.toString() ?? '';
        final price  = double.tryParse(matchedScale['satis']?.toString() ?? '') ?? 0.0;

        await _askQtyAndAdd(
          productId: productId,
          barcode: barkod.isNotEmpty ? barkod : barcode,
          name: name,
          price: price,
          presetQty: qty,
          presetPrice: price,
          bypassDialog: true,
        );

        if (!mounted) break;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('“$name” (${qty.toStringAsFixed(3)}) əlavə olundu')),
        );

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

      final idn    = (matched['idn'] as num?)?.toInt();
      final name   = matched['adi']?.toString() ?? '';
      final barkod = matched['barkod']?.toString() ?? '';
      final price  = double.tryParse(matched['satis']?.toString() ?? '') ?? 0.0;

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
        price: price,
      );

      if (!mounted) break;

      if (added) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('“$name” əlavə olundu')),
        );
        // ✅ OK basıldı — növbəti skana KEÇ
        continue;
      } else {
        // ❌ Ləğv olundu — döngünü dayandır
        break;
      }
    }
  }


  Future<void> _editLine(int index) async {
    final line = _lines[index];
    final qtyCtrl = TextEditingController(text: line.qty.toString());
    final priceCtrl = TextEditingController(text: line.price.toStringAsFixed(2));
    final qeydCtrl = TextEditingController(text: line.qeyd);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Düzəliş et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onTap: () => qtyCtrl.selection =
                  TextSelection(baseOffset: 0, extentOffset: qtyCtrl.text.length),
              decoration: const InputDecoration(
                labelText: 'Miqdar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onTap: () => priceCtrl.selection =
                  TextSelection(baseOffset: 0, extentOffset: priceCtrl.text.length),
              decoration: const InputDecoration(
                labelText: 'Satış qiyməti',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv et')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yadda saxla')),
        ],
      ),
    );

    if (ok != true) return;

    final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? line.qty;
    final prc = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? line.price;
    final ln  = qeydCtrl.text.trim();

    setState(() {
      _lines[index] = line.copyWith(qty: qty, price: prc, qeyd: ln);
    });
    // _saveDraft();
  }

  Future<void> _deleteLine(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Məhsulu sil'),
        content: const Text('Bu məhsulu silmək istəyirsiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Xeyr')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Bəli, sil')),
        ],
      ),
    );
    if (ok == true) {

      final pid = _lines[index].productId;
      setState(() {
        _lines.removeAt(index);
        _addedCounts.remove(pid); // ✅ məhsul tam silinibsə sayğacı da sil
      });
    }
  }

  Future<void> _getPairedBluetoothDevices() async {
    if(!mounted) return;
    setState(() => _isLoadingBluetoothAction = true);
    List<BluetoothDevice> devices = [];
    try {
      devices = await bluetooth.getBondedDevices();
    } catch (e) {
      debugPrint("Bluetooth cihazlarını alarkən xəta: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bluetooth cihazlarını alarkən xəta: $e")),
        );
      }
    }
    if (mounted) {
      setState(() {
        _bluetoothDevices = devices;
        _isLoadingBluetoothAction = false;
      });
    }
  }
  Future<void> _connectToBluetoothDevice(BluetoothDevice device) async {
    if (_isBluetoothConnected && _selectedBluetoothDevice?.address == device.address) {
      // Artıq bu cihaza qoşuluyuq
      return;
    }
    if (_isBluetoothConnected) {
      await _disconnectFromBluetoothDevice(); // Əvvəlki bağlantını kəs
    }

    if(!mounted) return;
    setState(() => _isLoadingBluetoothAction = true);
    try {
      await bluetooth.connect(device);
      if (mounted) {
        setState(() {
          _selectedBluetoothDevice = device;
          _isBluetoothConnected = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${device.name ?? 'Naməlum cihaz'}-a qoşuldu.")),
        );
      }
    } catch (e) {
      debugPrint("Bluetooth cihazına qoşularkən xəta: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cihaza qoşularkən xəta: $e")),
        );
      }
    } finally {
      if(mounted) setState(() => _isLoadingBluetoothAction = false);
    }
  }

  void _showBluetoothDeviceListDialog() {
    _getPairedBluetoothDevices(); // Hər dəfə dialoq açıldıqda siyahını yenilə

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // dialogContext istifadə edirik
        // Dialoq içindəki state-i idarə etmək üçün StatefulBuilder
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: const Text("Bluetooth Printer Seçin"),
              content: SizedBox(
                width: double.maxFinite,
                child: _isLoadingBluetoothAction
                    ? const Center(child: CircularProgressIndicator())
                    : _bluetoothDevices.isEmpty
                    ? const Center(
                  child: Text(
                    "Qoşulmuş cihaz tapılmadı.\nƏvvəlcə telefonun Bluetooth tənzimləmələrindən printeri qoşun.",
                    textAlign: TextAlign.center,
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _bluetoothDevices.length,
                  itemBuilder: (context, index) {
                    final device = _bluetoothDevices[index];
                    bool isCurrentlySelected = _selectedBluetoothDevice?.address == device.address;
                    return ListTile(
                      leading: Icon(
                        Icons.print_outlined,
                        color: (isCurrentlySelected && _isBluetoothConnected) ? Colors.green : null,
                      ),
                      title: Text(device.name ?? "Naməlum cihaz"),
                      subtitle: Text(device.address ?? "Ünvan yoxdur"),
                      selected: isCurrentlySelected && _isBluetoothConnected,
                      selectedTileColor: Colors.green.withOpacity(0.1),
                      onTap: () async {
                        Navigator.of(dialogContext).pop(); // Əvvəlcə bu dialoqu bağla
                        await _connectToBluetoothDevice(device);
                        // Qoşulduqdan sonra lazım gələrsə başqa bir əməliyyat
                      },
                      trailing: (isCurrentlySelected && _isBluetoothConnected)
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : _isLoadingBluetoothAction && _selectedBluetoothDevice?.address == device.address
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2,))
                          : null,
                    );
                  },
                ),
              ),
              actions: <Widget>[
                if (_isBluetoothConnected && _selectedBluetoothDevice != null)
                  TextButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop(); // Bu dialoqu bağla
                      await _disconnectFromBluetoothDevice();
                    },
                    child: const Text("AYRIL", style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text("BAĞLA"),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _disconnectFromBluetoothDevice() async {
    if(!mounted) return;
    setState(() => _isLoadingBluetoothAction = true);
    try {
      await bluetooth.disconnect();
      if (mounted) {
        setState(() {
          _isBluetoothConnected = false;
          _selectedBluetoothDevice = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cihazdan ayrıldı.")),
        );
      }
    } catch (e) {
      debugPrint("Bluetooth cihazından ayrılarkən xəta: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cihazdan ayrılarkən xəta: $e")),
        );
      }
    } finally {
      if(mounted) setState(() => _isLoadingBluetoothAction = false);
    }
  }
  String _nameById(List<LookupItem> list, int? id) {
    if (id == null) return '-';
    final i = list.indexWhere((e) => e.id == id);
    return i == -1 ? '-': list[i].name;
  }

  String _money(num v) => v.toStringAsFixed(2);
  String _qtyStr(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();


  // 1) Azərbaycan mətni türk kod cədvəlinə uyğunlaşdır
  String _azNormalize(String s) {
    return s
        .replaceAll('ə', 'e')
        .replaceAll('Ə', 'E');
  }

// 2) Mətni CP1254 (Windows-1254) ilə çap et
  void _p(String text, {int size = 1, int align = 0}) {
    final fixed = _azNormalize(text);
    // blue_thermal_printer 1.2.x-də charset dəstəyi var (bəzi forklarda):
    // əgər sənin versiyada parametr adı fərqlidirsə, uyğunlaşdır.
    bluetooth.printCustom(fixed, size, align, charset: 'windows-1254');
  }

// 3) Sol/Sağ sətir (əgər kitabxananın versiyasında charset parametri var)
  void _plr(String left, String right, {int size = 1}) {
    final l = _azNormalize(left);
    final r = _azNormalize(right);
    bluetooth.printLeftRight(l, r, size, charset: 'windows-1254');
  }

  Future<void> _ensurePrinterConnected() async {
    final isConn = await bluetooth.isConnected ?? false;
    if (isConn) return;

    if (_printer == null) {
      // Əgər bu səhifədə printer saxlanmıyıbsa, yaddaşdan yüklə
      final bonded = await bluetooth.getBondedDevices();
      _printer = await _loadPreferredPrinter(bonded);
    }
    if (_printer != null) {
      await bluetooth.connect(_printer!);
    }
  }
  Future<void> _printReceipt() async {
    await _ensurePrinterConnected();

    final isConn = await bluetooth.isConnected ?? false;
    if (!isConn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printerə qoşulmaq alınmadı.')),
      );
      return;
    }
    try {
      final df = DateFormat('dd.MM.yyyy HH:mm');
      final musteri = _selectedCustomerName ??
          (_selectedCustomerId != null ? '#$_selectedCustomerId' : '-');
      final anbar  = _nameById(_warehouses, _selectedWarehouseId);
      final kassa  = _paymentType == 'Nağd' ? _nameById(_cashDesks, _selectedCashDeskId) : '-';
      final odenis = _paymentType;

      _p("QAYTARMA", size: 3, align: 1);
      _p("---------------------------------------------------------", align: 1);
      _plr("Tarix:", df.format(_date));
      _plr("Müştəri:", musteri);
      _plr("Anbar:", anbar);
      _plr("Odəniş:", odenis);
      if (_paymentType == 'Nağd') {
        _plr("Kassa:", kassa);
      }
      _p("---------------------------------------------------------", align: 1);

      for (final l in _lines) {
        _p(l.name, size: 1, align: 0);
        final sol = "${_qtyStr(l.qty)} x ${_money(l.price)}";
        final sag = "${_money(l.price * l.qty)} AZN";
        _plr(sol, sag, size: 1);

        if ((l.qeyd).toString().trim().isNotEmpty) {
          _p("Qeyd: ${l.qeyd}", size: 0, align: 0);
        }
        bluetooth.printNewLine();
      }

      _p("---------------------------------------------------------", align: 1);
      _plr("CƏM:", "${_money(_total)} AZN", size: 2);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();


      // Kəsim dəstəklənirsə
      bluetooth.paperCut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Çap göndərildi.")),
        );
      }
    } catch (e) {
      debugPrint("Çap zamanı xəta: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Çap zamanı xəta: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingBluetoothAction = false);
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

    if (barcode == null || barcode.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('mallar_data');
    if (jsonStr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Məhsul siyahısı boşdur. “Məlumatları yenilə” edin.')),
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
          final mPlu = _toInt(m['plu']); // 'plu' sahəsi DB-dən gəlir deyə dedino
          return mPlu != null && mPlu == plu;
        },
        orElse: () => {},
      );


      if (matchedScale.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tərəzi barkodu üçün məhsul tapılmadı (PLU: $plu)')),
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

      final name   = matchedScale['adi']?.toString() ?? '';
      final barkod = matchedScale['barkod']?.toString() ?? ''; // baza barkod
      final price  = double.tryParse(matchedScale['satis']?.toString() ?? '') ?? 0.0;

      await _askQtyAndAdd(
        productId: productId,                   // ✅ server üçün idn
        barcode: barkod.isNotEmpty ? barkod : barcode, // göstərim üçün
        name: name,
        price: price,
        presetQty: qty,                         // tərəzi barkodundan gələn miqdar
        presetPrice: price,
        bypassDialog: true,                     // dialoqsuz əlavə
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“$name” (${qty.toStringAsFixed(3)}) əlavə olundu')),
      );
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
    final price = double.tryParse(matched['satis']?.toString() ?? '') ?? 0.0;

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
      price: price,
      // adi barkod üçün dialoq açılacaq (presetQty vermədik)
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('“$name” əlavə olundu')),
    );
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
      final pluStr = bc.substring(3, 7);   // əvvəl idn götürürdün, indi PLU
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
    if (_selectedCustomerId == null || _selectedCashDeskId == null || _selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Müştəri/Kassa/Anbar seçilməyib.')),
      );
      return;
    }
    if (_lines.any((e) => e.productId <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Məhsul id-si (idn) yoxdur.')),
      );
      return;
    }

    final payment = _paymentType == 'Nağd' ? 0 : 1;

    final payload = {
      'date': _date.toIso8601String(),
      'customerId': _selectedCustomerId,
      'cashdeskId': _selectedCashDeskId,
      'warehouseId': _selectedWarehouseId,
      'userId' : globalTermname,
      'payment': payment,
      'note': _noteCtrl.text.trim(),
      'lines': _lines
          .map((e) => {
        'idn': e.productId,
        'qty': e.qty,
        'price': e.price,
        'qeyd': e.qeyd,
      })
          .toList(),
      'total': _total,
    };
    setState(() => _submitting = true);
    try {
      final base = await _getBaseUrl();
      final resp = await http
          .post(
        Uri.parse('$base/geri'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        await _clearDraft();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Qaytarma sənədi təsdiqləndi')),
        );

        //await _printReceipt();

        Navigator.pop(context); // istəsən geriyə qayıt
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
        title: const Text('Qaytarma'),
    backgroundColor: Colors.white,
    elevation: 0,
    titleTextStyle: GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
    ),
    ),
    backgroundColor: const Color(0xFFF3F4F6),

    // ❌ RawKeyboardListener YOX — gizli TextField yetərlidir
    body: GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => FocusScope.of(context).requestFocus(_irFocus),

    // ✅ Overlay + Gizli TextField + Kontent
    child: Stack(
    children: [
    // 0) GİZLİ TEXTFIELD — ekranda, amma 1x1 ölçüdə və görünməz
    Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
    width: 1,
    height: 1,
    child: Focus(
    onFocusChange: (hasFocus) {
    if (hasFocus) {
    // Soft klaviaturanı bağla
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
    },
    child: TextField(
    controller: _irCtrl,
    focusNode: _irFocus,          // yalnız burda istifadə et
    autofocus: true,
    enableSuggestions: false,
    autocorrect: false,
    showCursor: false,
    decoration: const InputDecoration(
    isCollapsed: true,
    border: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    ),
    keyboardType: TextInputType.none,     // OSK açılmasın
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => _commitIrCtrl(),
    onTap: () => SystemChannels.textInput.invokeMethod('TextInput.hide'),
    ),
    ),
    ),
    ),
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
            // ... build() içində, HEADER KARTI hissəsində:
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    // 1-ci sıra: Tarix (dar) + Ödəniş növü (geniş)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                onTap: canChangeDate ? _pickDate : () {},

                              ),

                            ),

                          ),
                        ),


                        const SizedBox(width: 50),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Wrap(
                                spacing: 5,
                                children: [
                                  ChoiceChip(
                                    label: const Text(
                                      'Nağd',
                                      style: TextStyle(fontSize: 8, color: Colors.black87), // 🔹 yazı ölçüsü
                                    ),
                                    selected: _paymentType == 'Nağd',
                                    onSelected: (sel) {
                                      if (sel) {
                                        setState(() => _paymentType = 'Nağd');
                                        // _saveDraft();
                                      }
                                    },
                                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14), // 🔹 boşluqları azaldır
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // 🔹 minimum hündürlük
                                  ),
                                  ChoiceChip(
                                    label: const Text(
                                      'Nisyə',
                                      style: TextStyle(fontSize: 8, color: Colors.black87),
                                    ),
                                    selected: _paymentType == 'Nisyə',
                                    onSelected: (sel) {
                                      if (sel) {
                                        setState(() => _paymentType = 'Nisyə');
                                        // _saveDraft();
                                      }
                                    },
                                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),

                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 2-ci sıra: Müştəri (tam en)
                    _CustomerSearchPicker(
                      label: 'Müştəri',
                      valueText: _selectedCustomerName ??
                          (_selectedCustomerId != null ? '#$_selectedCustomerId' : 'Seçilməyib'),
                      items: _customers,
                      onSelected: (item) {
                        setState(() {
                          _selectedCustomerId = item?.id;
                          _selectedCustomerName = item?.name;
                        });
                        // _saveDraft();
                      },
                    ),
                    const SizedBox(height: 8),

                    // 3-cü sıra: Kassa + Anbar (vardı, saxlayırıq)

                    Row(
                      children: [
                        Expanded(
                          child: _HeaderDropdownGeneric(
                            label: 'Kassa',
                            selectedId: _selectedCashDeskId,
                            items: _cashDesks,
                            enabled: _paymentType == 'Nağd', // 🔸 Nağd = aktiv, Nisyə = deaktiv
                            onChanged: (id) {
                              setState(() => _selectedCashDeskId = id);

                              //_saveDraft();

                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HeaderDropdownGeneric(
                            label: 'Anbar',
                            selectedId: _selectedWarehouseId,
                            items: _warehouses,
                            onChanged: (id) {
                              setState(() => _selectedWarehouseId = id);
                              // _saveDraft();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    //  4-cü sıra: Qeyd
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _noteCtrl,
                            style: const TextStyle(fontSize: 12), // 🔹 daxil edilən mətn balaca
                            decoration: InputDecoration(
                              labelText: 'Qeyd',
                              labelStyle: const TextStyle(fontSize: 12,color: Colors.black87), // 🔹 label-i balacalaşdır
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.black54),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              //  isDense: true,
                              //contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), // Padding-i bir az tənzimlədim
                              //prefixIcon: Icon(Icons.notes, size: 18), // 🔹 ikon da balaca
                            ),
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
              ),
            ),

            //const SizedBox(height: 16),
            const SizedBox(height: 16),

            // LİST KARTI
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          icon: const Icon(Icons.qr_code_scanner, size: 16),
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
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _lines.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final l = _lines[index];
                        final addCount = _addedCounts[l.productId] ?? 1; // default: 1
                        return Dismissible(
                          key: ValueKey('${l.productId}-$index'),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 12),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (_) async {
                            await _deleteLine(index);
                            return false;
                          },
                          child: ListTile(
                            title: Text(l.name),
                            subtitle: Text(
                                'Barkod: ${l.barcode}\n'
                                'Qiymət: ${l.price.toStringAsFixed(2)} AZN | Miqdar: ${_fmt18_3(l.qty)}\n'
                                'Qeyd: ${l.qeyd.toString()}\n'
                                'Qutu sayı: $addCount'),
                            isThreeLine: true,
                            trailing: Text(
                              (l.price * l.qty).toStringAsFixed(2) + ' AZN',
                              style: GoogleFonts.poppins(fontSize: 14,fontWeight: FontWeight.w600),
                            ),
                            onTap: () => _editLine(index),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 8),

                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sətir: $_lineCount',
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Miqdar: ${_fmt18_3(_totalQty)}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Qutu sayı: $_totalAddedCount',
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Cəmi:',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${_total.toStringAsFixed(2)} AZN',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        /*Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _submitting ? null : _saveDraft,
                            icon: const Icon(Icons.save),
                            label: const Text('Qaralama'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _submitting ? null : _saveDraft,
                            icon: const Icon(Icons.save),
                            label: const Text('Qaralama'),
                          ),
                        ),*/
                        const SizedBox(width: 6),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.check),
                            label: Text(_submitting ? 'Göndərilir...' : 'Təsdiqlə'),
                          ),
                        ),
                      ],
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
        onTap: onTap, // 👈 tarixi seçmək üçün
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


