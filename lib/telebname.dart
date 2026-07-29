import 'dart:convert';
import 'package:aliyev_apk/main.dart' show globalIp, globalPort, globalAllowDateChange;
import 'package:audioplayers/audioplayers.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'barcode_scanner_page.dart';
import 'main.dart' show globalIp, globalPort, globalAllowDateChange, globalTermname,globalceki, globaleded;  // qlobal dəyərlər üçün
import 'dart:async';

// === BLUETOOTH PRINTER DƏYİŞƏNLƏRİ ===
BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
List<BluetoothDevice> _bluetoothDevices = []; // Adı _devices ilə qarışmasın deyə dəyişdim
BluetoothDevice? _selectedBluetoothDevice;
bool _isBluetoothConnected = false;
bool _isLoadingBluetoothAction = false; // Qoşulma/çap zamanı loading üçün



final AudioPlayer _audioPlayer1 = AudioPlayer();

/// ---- MODELLƏR ----



final List<LookupItem> _iade = [
  LookupItem(id: 0, name: 'Tələb'),
  LookupItem(id: 1, name: 'İadə'),
];


// 🔎 Axtarışlı seçim pəncərəsi (bottom sheet ilə) - ÜMUMİ VİDCET
class _SearchableLookupPicker extends StatelessWidget {
  final String label;           // Inputun labeli (Müştəri, Anbar və s.)
  final String modalTitle;      // Axtarış pəncərəsinin başlığı
  final String valueText;       // Seçilmiş dəyərin mətni
  final List<LookupItem> items; // Axtarış ediləcək siyahı
  final ValueChanged<LookupItem?> onSelected;
  final bool enabled;

  const _SearchableLookupPicker({
    super.key,
    required this.label,
    required this.modalTitle,
    required this.valueText,
    required this.items,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: InputDecorator(
        decoration: InputDecoration(
          label: Text(
            label,
            style: TextStyle(fontSize: kGlobalBaseFontSize - 1, color: Colors.black87),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black54),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: InkWell(
          onTap: enabled ? () => _openSearch(context) : null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  valueText,
                  style: TextStyle(fontSize: kGlobalBaseFontSize, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20, color: Colors.black87),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    List<LookupItem> filtered = List.of(items);
    final ctrl = TextEditingController();

    final selected = await showModalBottomSheet<LookupItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
                  filtered = items
                      .where((e) =>
                  e.name.toLowerCase().contains(query) ||
                      e.id.toString().contains(query))
                      .toList();
                });
              }

              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      modalTitle, // 👈 Dinamik başlıq
                      style: GoogleFonts.poppins(
                          fontSize: kGlobalBaseFontSize + 2,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: TextStyle(fontSize: kGlobalBaseFontSize, color: Colors.black87),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Axtar',
                        labelStyle: TextStyle(fontSize: kGlobalBaseFontSize - 1),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: const OutlineInputBorder(),
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      ),
                      onChanged: doFilter,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(child: Text('Nəticə tapılmadı', style: TextStyle(fontSize: kGlobalBaseFontSize - 1)))
                          : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final it = filtered[i];
                          return ListTile(
                            title: Text(
                              it.name,
                              style: TextStyle(fontSize: kGlobalBaseFontSize),
                            ),
                            //subtitle: Text('ID: ${it.id}', style: TextStyle(fontSize: kGlobalBaseFontSize-2, color: Colors.grey.shade600)),
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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

    if (context.mounted) {
      onSelected(selected);
    }
  }
}



class LookupItem {
  final int id;
  final String name;
  LookupItem({required this.id, required this.name});

  factory LookupItem.fromMap(Map<String, dynamic> m) => LookupItem(
    id: (m['idn'] as num).toInt(),
    name: (m['adi'] ?? '').toString(),
  );
}





class LookupItemderece {
  final int id;
  final String name;
  final double vat_percent;
  LookupItemderece({required this.id, required this.name, required this.vat_percent});

  factory LookupItemderece.fromMap(Map<String, dynamic> m) => LookupItemderece(
    id: (m['idn'] as num).toInt(),
    name: (m['adi'] ?? '').toString(),
    vat_percent: (m['vat_percent'] as num).toDouble(),
  );
}


class SaleLine {
  final int productId;
  final String barcode;
  final String name;
  final double price;
  final double qty;
  final String unit;
  final String qeyd;
  final int addCount;

  double edvAmount;    // ƏDV məbləği
  double totalAmount;  // Yekun məbləğ

  final double discountPercent;
  final double discountAmount;

  SaleLine({
    required this.productId,
    required this.barcode,
    required this.name,
    required this.price,
    required this.qty,
    required this.unit,
    required this.qeyd,
    this.addCount = 1,

    // İlkin dəyərlər
    this.edvAmount = 0.0,
    this.totalAmount = 0.0,

    this.discountPercent = 0.0,
    this.discountAmount = 0.0,

  });


  SaleLine copyWith({
    int? productId,
    String? barcode,
    String? name,
    double? price,
    double? qty,
    String? unit,
    String? qeyd,
    int? addCount,

    double? discountPercent,
    double? discountAmount,
  })
  {
    return SaleLine(
      productId: productId ?? this.productId,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      qeyd: qeyd ?? this.qeyd,
      addCount: addCount ?? this.addCount,

      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,

    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId, // 🔹 draft üçün
    'barcode': barcode,
    'name': name,
    'price': price,
    'qty': qty,
    'unit': unit,

    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
  };

  factory SaleLine.fromMap(Map<String, dynamic> m) => SaleLine(
    productId: (m['productId'] as num).toInt(),
    barcode: (m['barcode'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    price: (m['price'] as num).toDouble(),
    qty: (m['qty'] as num).toDouble(),
    unit: (m['unit_name'] ?? '').toString(),
    qeyd: (m['qeyd'] ?? '').toString(),
    addCount: (m['addCount'] as num).toInt(),

    discountPercent: (m['discountPercent'] as num? ?? 0.0).toDouble(),
    discountAmount: (m['discountAmount'] as num? ?? 0.0).toDouble(),

  );
}





final NumberFormat _qtyFmt18_3 = NumberFormat('#,###0.000', 'az'); // 1 234,56 kimi
String _fmt18_3(num v) => _qtyFmt18_3.format(v);

class TelebnamePage extends StatefulWidget {
  const TelebnamePage({super.key});

  @override
  State<TelebnamePage> createState() => _TelebnamePageState();
}

class _TelebnamePageState extends State<TelebnamePage> {
  final _formKey = GlobalKey<FormState>();


  List<LookupItem> _sorguNomreleri = []; // API-dən gələcək sorğu nömrələri siyahısı
  final TextEditingController _sorguNomresiCtrl = TextEditingController(); // Həm manual yazmaq, həm də seçimi göstərmək üçün
  bool _isFetchingSorguDetails = false;

  final TextEditingController _kontraAdiCtrl = TextEditingController();
  final TextEditingController _layiheAdiCtrl = TextEditingController();
  final TextEditingController _isinAdiCtrl = TextEditingController();


  // Header sahələri
  DateTime _date = DateTime.now();
  DateTime _date2 = DateTime.now();

  int? _selectedCustomerId;
  int? _selectedSorguId;
  String? _selectedCustomerName;

  int? _selectedCashDeskId;
  int? _selectedWarehouseId;

  int _selectediade = 0;

  bool _isUrgent = false;

  bool _showSorguFields = true;



  String _paymentType = 'Nisyə'; // 'Nağd' | 'Nisyə'

  // Lookup siyahıları (API-dən)
  List<LookupItem> _customers = [];
  List<LookupItem> _cashDesks = [];
  List<LookupItem> _warehouses = [];

  List<LookupItem> _classList = [];
  List<LookupItem> _propertyList = [];

  LookupItem? selectedProperty;
  LookupItem? selectedClass;


  // Satış sətirləri
  final List<SaleLine> _lines = [];

  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _noteCtrl2 = TextEditingController();



  final _discountPercentController = TextEditingController();
  final _discountAmountController = TextEditingController();



  double _subtotal = 0.0; // Sizin mövcud ara cəminiz

  double _subedv = 0.0; // Sizin mövcud ara cəminiz
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


  // Draft saxlanması üçün açar
  static const String _draftKey = 'telebname_draft';


  double get _totalQty => _lines.fold(0.0, (s, e) => s + e.qty);
  int get _lineCount => _lines.length;



  final Map<int, int> _addedCounts = {}; // productId -> neçə dəfə əlavə olunub

  void _incCount(int productId) {
    _addedCounts.update(productId, (v) => v + 1, ifAbsent: () => 1);

  }
  int get _totalAddedCount =>
      _addedCounts.values.fold(0, (sum, v) => sum + v);

  double _total = 0.0;


  // ===== BU SƏTRİ ƏLAVƏ EDİN VƏ YA DÜZGÜN YERDƏ OLDUĞUNU YOXLAYIN =====
  bool _isDownloadingProducts = false;
  // double get _total => _lines.fold(0.0, (sum, e) => sum + (e.price * e.qty));



  @override
  void initState() {
    super.initState();

    _irCtrl.addListener(_onIrCtrlChanged);

    _loadDraft().then((_) {
      _loadLookups();


      _discountPercentController.text = '0.00';
      _discountAmountController.text = '0.00';

      // Köhnə dinləyicini yeni funksiya ilə əvəz edin
      _discountPercentController.addListener(_recalculateAllTotals);
      _discountAmountController.addListener(_recalculateAllTotals);

      // Səhifə açılan kimi ilkin hesablamanı aparın
      _recalculateAllTotals();


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

    _discountPercentController.dispose();
    _discountAmountController.dispose();


    super.dispose();
  }
  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }



  // YENİ KÖMƏKÇİ FUNKSİYA
  String _warehouseNameById(int? id) {
    if (id == null) return 'Seçilməyib';
    return _warehouses.firstWhere((e) => e.id == id, orElse: () => LookupItem(id: id, name: 'ID: #$id')).name;
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

  double _discountedTotal = 0;
  double _edv = 0;
  double _yekun = 0;
  void _recalculateAllTotals() {
    // 1️⃣ Hər sətirin real məbləğini hesablayaq (qty daxil olmaqla)
    final newSubtotal = _lines.fold(0.0, (sum, e) {
      final lineBase =
          (((e.price-e.discountAmount) - ((e.price-e.discountAmount) * e.discountPercent / 100)) * e.qty);
      return sum + lineBase;
    });

    // 2️⃣ Ümumi endirimlər (əlavə olaraq, yuxarıdakı ümumi % və ya məbləğ)
    final percent = double.tryParse(_discountPercentController.text) ?? 0.0;
    final amount = double.tryParse(_discountAmountController.text) ?? 0.0;

    double discountedTotal = newSubtotal;

    if (percent > 0) {
      discountedTotal -= discountedTotal * percent / 100;
    }
    if (amount > 0) {
      discountedTotal -= amount;
    }

    if (discountedTotal < 0) discountedTotal = 0;

    double edv = 0.0;
    if (_selectedCashDeskId == 2) {
      edv = discountedTotal * 0.18;
    }

    // 4️⃣ Yekun
    double yekun = discountedTotal + edv;

    setState(() {
      _subtotal = newSubtotal;        // Məhsulların ümumi məbləği (miqdarla)
      _discountedTotal = discountedTotal;
      _edv = edv;
      _yekun = yekun;
    });
  }


  Future<void> _fetchAndFillSorguDetails(String sorguId) async {
    if (sorguId.trim().isEmpty) return;

    setState(() {
      _isFetchingSorguDetails = true;
      _kontraAdiCtrl.text = 'Yüklənir...';
      _layiheAdiCtrl.text = 'Yüklənir...';
      _isinAdiCtrl.text = 'Yüklənir...';
    });

    try {
      final base = await _getBaseUrl();
      final url = Uri.parse('$base/sorguid?sorguId=${Uri.encodeComponent(sorguId)}');
      final resp = await http.get(url).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final dynamic decodedBody = jsonDecode(resp.body);
        Map<String, dynamic>? data;

        if (decodedBody is Map<String, dynamic>) {
          data = decodedBody;
        } else if (decodedBody is List && decodedBody.isNotEmpty) {
          if (decodedBody[0] is Map<String, dynamic>) {
            data = decodedBody[0] as Map<String, dynamic>;
          }
        }

        if (data != null) {
          setState(() {
            _kontraAdiCtrl.text = data?['kontraadi']?.toString() ?? 'Məlumat yoxdur';
            _layiheAdiCtrl.text = data?['layiheadi']?.toString() ?? 'Məlumat yoxdur';
            _isinAdiCtrl.text = data?['isinadi']?.toString() ?? 'Məlumat yoxdur';
          });
        } else {
          throw Exception('API-dan gələn cavab formatı səhvdir və ya boşdur.');
        }
      } else {
        final errorBody = jsonDecode(resp.body);
        throw Exception('Server xətası: ${resp.statusCode} - ${errorBody['error'] ?? resp.reasonPhrase}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _kontraAdiCtrl.text = "Xəta baş verdi";
          _layiheAdiCtrl.text = "Xəta baş verdi";
          _isinAdiCtrl.text = "Xəta baş verdi";
        });
        print({e.toString()});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sorğu məlumatları yüklənərkən xəta: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingSorguDetails = false);
      }
    }

    if (_sorguNomresiCtrl.text != '' && _showSorguFields == true) {
      _downloadMallarsorgu();
    }
  }










  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });

    try {
      final base = await _getBaseUrl();

      // Endpointlərin adlarını bir siyahıda saxlayaq
      final endpoints = {
        'Müştəri': '$base/musteri?userId=$globalTermname',
        'Tələb Növü': '$base/telebnovu',
        'Anbar': '$base/anbar?userId=$globalTermname',
        'Class': '$base/class',
        'Properties': '$base/properties',
        'Sorğu Nömrələri': '$base/sorgu-nomreleriuser?userId=$globalTermname',
      };

      // Sorğuları paralel göndəririk
      final responses = await Future.wait(
          endpoints.values.map((url) => http.get(Uri.parse(url)))
      );

      // --- DİAQNOSTİKA KODU ---
      // Hər bir sorğunun nəticəsini yoxlayaq və çap edək
      bool allOk = true;
      print("===== LOOKUP SORĞU NƏTİCƏLƏRİ =====");
      for (int i = 0; i < responses.length; i++) {
        final endpointName = endpoints.keys.elementAt(i);
        final response = responses[i];
        print("Endpoint: $endpointName | Status: ${response.statusCode}");
        if (response.statusCode != 200) {
          print("   -> XƏTA: Cavab Body: ${response.body}");
          allOk = false;
        }
      }
      print("====================================");

      // Əgər hər hansı birində problem varsa, xəta veririk
      if (!allOk) {
        throw Exception('Lookup yüklənməsi zamanı bəzi sorğular uğursuz oldu. Detallar üçün konsola baxın.');
      }
      // ------------------------------------

      // JSON-ları parse et
      final custJson = jsonDecode(responses[0].body) as List;
      final kassJson = jsonDecode(responses[1].body) as List;
      final anbJson = jsonDecode(responses[2].body) as List;
      final classJson = jsonDecode(responses[3].body) as List;
      final propJson = jsonDecode(responses[4].body) as List;
      final sorguJson = jsonDecode(responses[5].body) as List;

      // Map et
      final customers = custJson.map((e) => LookupItem.fromMap(e)).toList();
      final kassas = kassJson.map((e) => LookupItem.fromMap(e)).toList();
      final anbars = anbJson.map((e) => LookupItem.fromMap(e)).toList();
      final classes = classJson.map((e) => LookupItem.fromMap(e)).toList();
      final properties = propJson.map((e) => LookupItem.fromMap(e)).toList();
      final sorgular = sorguJson.map((e) => LookupItem(id: int.tryParse(e['idn'].toString()) ?? 0, name: e['name'].toString())).toList();

      // State-i təyin et
      setState(() {
        _customers = customers;
        _cashDesks = kassas;
        _warehouses = anbars;
        _classList = classes;
        _propertyList = properties;
        _sorguNomreleri = sorgular;

        _selectedCashDeskId ??= _cashDesks.isNotEmpty ? _cashDesks.first.id : null;
        _selectedWarehouseId ??= _warehouses.isNotEmpty ? _warehouses.first.id : null;
      });
    } catch (e) {
      setState(() => _lookupError = e.toString());
    } finally {
      setState(() => _loadingLookups = false);
    }

    // Əgər anbar seçilibsə, malları yüklə
    if (_selectedWarehouseId != null) {
      await _downloadMallar();
    }
  }







  Future<void> _downloadMallar() async {

    final url = Uri.parse('http://$globalIp:$globalPort/mallarqaliqreserv?userId=$_selectedWarehouseId');
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


  Future<void> _downloadMallarsorgu() async {

    final url = Uri.parse(
        'http://$globalIp:$globalPort/mallartelebname'
            '?anbarId=$_selectedWarehouseId'
            '&sorguId=$_selectedSorguId'
    );
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
        final unit = matchedScale['unit_name']?.toString() ?? '';

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
              unit: unit,
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
        _recalculateAllTotals();

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
      final unit = matched['unit_name']?.toString() ?? '';
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
            unit: unit,
            qeyd: '',
          ));
        }
      });
      _incCount(idn);

      if (!mounted) return;
      /*ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“$name” (1) əlavə olundu')),
      );*/

      _recalculateAllTotals();

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

  Future<void> _pickDate2() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date2,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _date2 = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date2.hour,
        _date2.minute,
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

    if(_sorguNomresiCtrl.text=='' &&  _showSorguFields == true) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar() // əvvəlki mesajı gizlə
        ..showSnackBar(
          const SnackBar(content: Text('Sorğu seçilməyib')),
        );
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
                    /*  IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.black54),
                      tooltip: 'Təmizlə',
                      onPressed: () {
                        setState(() {
                          nameOrCodeCtrl.clear();
                          doFilter();
                        });
                      },
                    ),
                    */
                  ],
                  ),
                  ),

                    const SizedBox(width: 10),

                    // 🔹 Marka
                    Expanded(
                      child: Row(
                        children: [

                          Expanded(
                            child: DropdownSearch<LookupItem>(
                              items: _propertyList,
                              selectedItem: selectedProperty,
                              itemAsString: (item) => item.name,
                              popupProps: const PopupProps.menu(
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Marka axtar...',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              dropdownDecoratorProps: const DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  labelText: 'Marka',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(width: 1.6, color: Colors.black54),
                                  ),
                                  labelStyle: TextStyle(color: Colors.black54),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  selectedProperty = value;
                                  doFilter();
                                });
                              },
                              clearButtonProps: const ClearButtonProps(isVisible: true),
                            ),
                          ),

                          // Sol təmizlə düyməsi
                          /* IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.black54),
                  tooltip: 'Təmizlə',
                  onPressed: () {
                    setState(() {
                      selectedProperty = null;
                      doFilter();
                    });
                  },
                ),
                */
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
                                child: DropdownSearch<LookupItem>(
                                  items: _classList,
                                  selectedItem: selectedClass,
                                  itemAsString: (item) => item.name,
                                  popupProps: const PopupProps.menu(
                                    showSearchBox: true,
                                    searchFieldProps: TextFieldProps(
                                      decoration: InputDecoration(
                                        hintText: 'Tip axtar...',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  dropdownDecoratorProps: const DropDownDecoratorProps(
                                    dropdownSearchDecoration: InputDecoration(
                                      labelText: 'Tip',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(width: 1.6, color: Colors.black54),
                                      ),
                                      labelStyle: TextStyle(color: Colors.black54),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedClass = value;
                                      doFilter();
                                    });
                                  },
                                  clearButtonProps: const ClearButtonProps(isVisible: true),
                                ),
                              ),

                              // Sol təmizlə düyməsi
                              /*  IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.black54),
                  tooltip: 'Təmizlə',
                  onPressed: () {
                    setState(() {
                      selectedClass = null;
                      doFilter();
                    });
                  },
                ),
                */
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

                            // _askQtyAndAdd nəticəsini yoxla
                            final added = await _askQtyAndAdd(
                              productId: idn,
                              barcode: barkod,
                              name: name,
                              price: price,
                              unit: unit,
                            );

                            if (added) {
                              setMS(() => justAdded.add(idn)); //
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

  Future<bool> _askQtyAndAdd({
    required int productId,
    required String barcode,
    required String name,
    required double price,
    double? presetQty,
    double? presetPrice,
    required String unit,
    bool bypassDialog = false,
  }) async {
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
            unit: unit,
            qeyd: '',
          ));
        }
      });
      _incCount(productId);
      return true;
    }

    final qtyCtrl = TextEditingController(text: (presetQty ?? 1).toString());
    final discountPercentCtrl = TextEditingController(text: '0');
    final discountAmountCtrl = TextEditingController(text: '0');

    const double edvFaiz = 18.0;


    double edvsizqiymeti =0.00;


    // İlkin qiymətlər
    final double edvsizQiymet = price / (1 + edvFaiz / 100);
    final double edvliQiymet = price * (1 + edvFaiz / 100);

    final priceCtrl = TextEditingController(
      text: (_selectedCashDeskId == 2 ? edvsizQiymet : price).toStringAsFixed(2),
    );
    final edvliCtrl = TextEditingController(
      text: edvliQiymet.toStringAsFixed(2),
    );
    final edvsizCtrl = TextEditingController(
      text: (_selectedCashDeskId == 2 ? price : edvsizQiymet).toStringAsFixed(2),
    );

    edvsizqiymeti=double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;

    void updateEdvFields({String? source}) {
      double qiymet = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
      double edvli = double.tryParse(edvliCtrl.text.replaceAll(',', '.')) ?? 0.0;
      double edvsiz = double.tryParse(edvsizCtrl.text.replaceAll(',', '.')) ?? 0.0;

      if (source == 'price') {
        if (_selectedCashDeskId == 2) {
          // ƏDV-siz qiymətdən ƏDV-li hesabla
          edvsizCtrl.text = (qiymet * (1 + edvFaiz / 100)).toStringAsFixed(2);
        } else {
          edvliCtrl.text = (qiymet * (1 + edvFaiz / 100)).toStringAsFixed(2);
          edvsizCtrl.text = (qiymet / (1 + edvFaiz / 100)).toStringAsFixed(2);
        }
      } else if (source == 'edvsiz') {
        // ƏDV-siz qiymətdən hesablama
        if (_selectedCashDeskId == 2) {
          qiymet = edvsiz / (1 + edvFaiz / 100);
          priceCtrl.text = qiymet.toStringAsFixed(2);
        } else {
          qiymet = edvsiz * (1 + edvFaiz / 100);
          priceCtrl.text = qiymet.toStringAsFixed(2);
          edvliCtrl.text = (qiymet * (1 + edvFaiz / 100)).toStringAsFixed(2);
        }
      } else if (source == 'edvli') {
        // ƏDV-li qiymətdən hesablama
        qiymet = edvli / (1 + edvFaiz / 100);
        priceCtrl.text = qiymet.toStringAsFixed(2);
        edvsizCtrl.text = (qiymet / (1 + edvFaiz / 100)).toStringAsFixed(2);
      }
    }

    updateEdvFields();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        String? errorText;
        double total = 0.0;

        final totalSumCtrl = TextEditingController(text: '0.00');

        void calculateTotal() {
          final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final priceVal = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final discountVal = double.tryParse(discountAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;

          final sum = qty * (priceVal-discountVal);
          total = sum;

          totalSumCtrl.text = sum.toStringAsFixed(2);
        }

        calculateTotal();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Əlavə et'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Miqdar
                    TextField(
                      controller: qtyCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Miqdar',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () {
                        qtyCtrl.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: qtyCtrl.text.length,
                        );
                      },
                    /*  onChanged: (_) {
                        setState(() {
                          calculateTotal();
                        });
                      },*/
                    ),
                  /*  const SizedBox(height: 12),

                    // Qiymət
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onTap: () {
                        priceCtrl.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: priceCtrl.text.length,
                        );
                      },
                      onChanged: (_) {
                        updateEdvFields(source: 'price');
                        setState(() {
                          calculateTotal();
                        });
                      },
                      decoration: InputDecoration(
                        labelText: _selectedCashDeskId == 2
                            ? 'Satış qiyməti (ƏDV-siz)'
                            : 'Satış qiyməti',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_selectedCashDeskId == 2)
                      TextField(
                        controller: edvsizCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onTap: () {
                          edvsizCtrl.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: edvsizCtrl.text.length,
                          );
                        },
                        onChanged: (_) {
                          updateEdvFields(source: 'edvsiz');
                          setState(() {
                            calculateTotal();
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Satış qiyməti (ƏDV-li)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // 💰 Endirim və Ümumi məbləğ yan-yana
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: discountAmountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onTap: () {
                              discountAmountCtrl.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: discountAmountCtrl.text.length,
                              );
                            },
                            onChanged: (_) {
                              setState(() {
                                calculateTotal();
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Endirim (AZN)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 🔹 Yekun məbləğ göstərilir
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Yekun məbləğ: ${total.toStringAsFixed(2)} AZN',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    */

                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(errorText!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Ləğv et'),
                ),
                FilledButton(
                  onPressed: () {
                    final enteredPrice =
                        double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? price;
                   /* if (enteredPrice < edvsizqiymeti) {
                      setState(() {
                        errorText =
                        'Qiyməti azaltmaq olmaz! Minimum qiymət: ${edvsizqiymeti.toStringAsFixed(2)} AZN';
                      });
                      return;
                    }
                    */
                    Navigator.pop(context, true);
                  },
                  child: const Text('Əlavə et'),
                ),
              ],
            );
          },
        );
      },
    );



    if (ok != true) return false;

    final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? (presetQty ?? 1.0);
    final enteredPrice =
        double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? (presetPrice ?? price);
    final discPercent =
        double.tryParse(discountPercentCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final discAmount =
        double.tryParse(discountAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;

    setState(() {
      final idx = _lines.indexWhere((e) => e.productId == productId);
      if (idx != -1) {
        final ex = _lines[idx];
        _lines[idx] = ex.copyWith(qty: ex.qty + qty, price: enteredPrice);
      } else {
        _lines.add(SaleLine(
          productId: productId,
          barcode: barcode,
          name: name,
          price: enteredPrice,
          qty: qty,
          unit: unit,
          qeyd: '',
          discountPercent: discPercent,
          discountAmount: discAmount,
        ));
      }
    });
    _incCount(productId);
    _recalculateAllTotals();
    return true;
  }




  Future<void> _editLine(int index) async {
    final line = _lines[index];

    final qtyCtrl = TextEditingController(text: line.qty.toString());
    final discountPercentCtrl = TextEditingController(text: line.discountPercent?.toString() ?? '0');
    final discountAmountCtrl = TextEditingController(text: line.discountAmount?.toString() ?? '0');
    final qeydCtrl = TextEditingController(text: line.qeyd);

    const double edvFaiz = 18.0;

    // İlkin qiymətlər
    final double edvliQiymet = line.price * (1 + edvFaiz / 100);
    final priceCtrl = TextEditingController( text: (_selectedCashDeskId == 2 ? line.price : line.price).toStringAsFixed(2), );
    final edvsizCtrl = TextEditingController( text: (_selectedCashDeskId == 2 ? edvliQiymet : edvliQiymet).toStringAsFixed(2), );
    final edvliCtrl = TextEditingController(text: edvliQiymet.toStringAsFixed(2));


    void updateEdvFields({String? source}) {
      double qiymet = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
      double edvli = double.tryParse(edvliCtrl.text.replaceAll(',', '.')) ?? 0.0;
      double edvsiz = double.tryParse(edvsizCtrl.text.replaceAll(',', '.')) ?? 0.0;

      if (source == 'price') {
        if (_selectedCashDeskId == 2) {
          // ƏDV-siz qiymətdən ƏDV-li hesabla
          edvsizCtrl.text = (qiymet * (1 + edvFaiz / 100)).toStringAsFixed(2);
        } else {
          edvliCtrl.text = (qiymet * (1 + edvFaiz / 100)).toStringAsFixed(2);
          edvsizCtrl.text = (qiymet / (1 + edvFaiz / 100)).toStringAsFixed(2);
        }
      } else if (source == 'edvsiz') {
        if (_selectedCashDeskId == 2) {
          qiymet = edvsiz / (1 + edvFaiz / 100);
          priceCtrl.text = qiymet.toStringAsFixed(2);
        } else {
          qiymet = edvsiz * (1 + edvFaiz / 100);
          priceCtrl.text = qiymet.toStringAsFixed(2);
          edvliCtrl.text = (qiymet * (1 + edvFaiz / 100)).toStringAsFixed(2);
        }
      } else if (source == 'edvli') {
        qiymet = edvli / (1 + edvFaiz / 100);
        priceCtrl.text = qiymet.toStringAsFixed(2);
        edvsizCtrl.text = (qiymet / (1 + edvFaiz / 100)).toStringAsFixed(2);
      }
    }

    updateEdvFields();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        String? errorText;

        double total = 0.0;


        double edvsizqiymeti =0.00;
        edvsizqiymeti=line.price;

        final totalSumCtrl = TextEditingController(text: '0.00');

        void calculateTotal() {
          final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final priceVal = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final discountVal = double.tryParse(discountAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;

          final sum = qty * (priceVal-discountVal);
          total = sum;

          totalSumCtrl.text = sum.toStringAsFixed(2);
        }

        calculateTotal();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Düzəliş et'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: qtyCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Miqdar',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () => qtyCtrl.selection =
                          TextSelection(baseOffset: 0, extentOffset: qtyCtrl.text.length),
                    ),
                    const SizedBox(height: 12),

                    // ƏDV-siz qiymət (əsas sahə)
                   /* TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onTap: () => priceCtrl.selection =
                          TextSelection(baseOffset: 0, extentOffset: priceCtrl.text.length),
                      onChanged: (_) => updateEdvFields(source: 'price'),
                      decoration: InputDecoration(
                        labelText: _selectedCashDeskId == 2
                            ? 'Satış qiyməti (ƏDV-siz)'
                            : 'Satış qiyməti',
                        border: const OutlineInputBorder(),
                      ),

                    ),
                    const SizedBox(height: 12),

                    if (_selectedCashDeskId == 2)
                      TextField(
                        controller: edvsizCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onTap: () => edvsizCtrl.selection =
                            TextSelection(baseOffset: 0, extentOffset: edvsizCtrl.text.length),
                        onChanged: (_) => updateEdvFields(source: 'edvsiz'),
                        decoration: const InputDecoration(
                          labelText: 'Satış qiyməti (ƏDV-li)',
                          border: OutlineInputBorder(),
                        ),

                      ),

                    const SizedBox(height: 12),
                    // 💰 Endirim və Ümumi məbləğ yan-yana
                    Row(
                      children: [

                        Expanded(
                          child: TextField(
                            controller: discountAmountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onTap: () {
                              discountAmountCtrl.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: discountAmountCtrl.text.length,
                              );
                            },
                            onChanged: (_) {
                              setState(() {
                                calculateTotal();
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Endirim (AZN)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qeydCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Qeyd',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 🔹 Yekun məbləğ göstərilir
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Yekun məbləğ: ${total.toStringAsFixed(2)} AZN',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ),
*/

                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(errorText!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Ləğv et'),
                ),
                FilledButton(
                  onPressed: () {
                    final enteredPrice =
                        double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? line.price;
                    /* if (enteredPrice < edvsizqiymeti) {
                      setState(() {
                        errorText = 'Qiyməti azaltmaq olmaz! Minimum qiymət: ${edvsizqiymeti.toStringAsFixed(2)} AZN';
                      });
                      return;
                    }*/
                    Navigator.pop(context, true);
                  },
                  child: const Text('Yadda saxla'),
                ),
              ],
            );
          },
        );
      },
    );


    if (ok != true) return;

    final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? line.qty;
    final enteredPrice = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? line.price;
    final discPercent = double.tryParse(discountPercentCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final discAmount = double.tryParse(discountAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final ln = qeydCtrl.text.trim();

    setState(() {
      _lines[index] = line.copyWith(
        qty: qty,
        price: enteredPrice,
        qeyd: ln,
        discountPercent: discPercent,
        discountAmount: discAmount,
      );
    });

    _recalculateAllTotals();
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
        final unit = matchedScale['unit_name']?.toString() ?? '';

        await _askQtyAndAdd(
          productId: productId,
          barcode: barkod.isNotEmpty ? barkod : barcode,
          name: name,
          price: price,
          presetQty: qty,
          unit: unit,
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
      final unit = matched['unit_name']?.toString() ?? '';

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
        unit: unit,
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
        _addedCounts.remove(pid);
      });

      _recalculateAllTotals(); // <-
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

  Future<void> _performTestPrint() async {
    if (!_isBluetoothConnected || _selectedBluetoothDevice == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Əvvəlcə Bluetooth printer seçin və qoşulun.")),
        );
      }
      _showBluetoothDeviceListDialog(); // Cihaz seçmə dialoqunu aç
      return;
    }

    if(!mounted) return;
    setState(() => _isLoadingBluetoothAction = true);

    try {
      bluetooth.printCustom("Soffen Mobile - Test Çapı", 3, 1); // Başlıq, böyük, mərkəz
      bluetooth.printNewLine();
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printLeftRight("Tarix:", DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()), 1);
      bluetooth.printCustom("Bu bir test mesajıdır.", 1, 0); // Normal, sola
      bluetooth.printNewLine();
      // QR kod çapı bəzi printerlərdə problem yarada bilər, əmin deyilsinizsə kommentə alın
      // bluetooth.printQRcode("https://soffensystems.com", 200, 200, 1);
      // bluetooth.printNewLine();
      bluetooth.paperCut(); // Kağızı kəs (əgər dəstəklənirsə)
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Test çapı göndərildi.")),
        );
      }
    } catch (e) {
      debugPrint("Çap zamanı xəta: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Çap zamanı xəta: $e")),
        );
      }
    } finally {
      if(mounted) setState(() => _isLoadingBluetoothAction = false);
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

    /*// 1) Əvvəl tərəzi barkodu olub-olmadığını yoxla
    final parsed = _parseScaleBarcode(barcode);
    if (parsed != null) {
      final idn = parsed.idn;
      final qty = parsed.qty; // məsələn 0.220

      // Tərəzi barkodu məhsulun idn-i ilə gəlir → idn ilə tapırıq
      final matchedScale = all.firstWhere(
            (m) => (m['idn'] as num?)?.toInt() == idn,
        orElse: () => {},
      );

      if (matchedScale.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tərəzi barkodu üçün məhsul tapılmadı (idn: $idn)')),
        );
        return;
      }

      final name   = matchedScale['adi']?.toString() ?? '';
      final barkod = matchedScale['barkod']?.toString() ?? ''; // baza barkod
      final price  = double.tryParse(matchedScale['satis']?.toString() ?? '') ?? 0.0;

      // Dialoq açmadan birbaşa əlavə etmək istəyiriksə:
      await _askQtyAndAdd(
        productId: idn,
        barcode: barkod.isNotEmpty ? barkod : barcode, // baza barkod (yoxdursa oxunan)
        name: name,
        price: price,
        presetQty: qty,
        presetPrice: price,
        bypassDialog: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“$name” (${qty.toStringAsFixed(3)}) əlavə olundu')),
      );
      return; // artıq bitdi
    }*/


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
      final unit = matchedScale['unit_name']?.toString() ?? ''; // baza barkod

      await _askQtyAndAdd(
        productId: productId,                   // ✅ server üçün idn
        barcode: barkod.isNotEmpty ? barkod : barcode, // göstərim üçün
        name: name,
        price: price,
        presetQty: qty,
        unit: unit,                         // tərəzi barkodundan gələn miqdar
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
    final unit = matched['unit_name']?.toString() ?? '';

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
      unit: unit,
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

    if (_lines.any((e) => e.productId <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Məhsul id-si (idn) yoxdur.')),
      );
      return;
    }

    if (_isUrgent && _noteCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Təcili tələblər üçün qeyd hissəsi minimum 10 simvol olmalıdır.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final payload = {
      'date1': _date.toIso8601String(),
      'date2': _date2.toIso8601String(),
      'telebnovu': _selectedCashDeskId,
      'kind': _selectediade,
      'warehouseId': _selectedWarehouseId,
      'userId' : globalTermname,
      'note': _noteCtrl.text.trim(),
      'sorgunomresi': _selectedSorguId,
      'tecili': _isUrgent ? 1 : 0, // boolean-ı int-ə çeviririk (true -> 1, false -> 0)

      'lines': _lines.map((e) => {
        'idn': e.productId,
        'qty': e.qty,
        'qeyd': e.qeyd,
      }).toList(),
      'total': _total,
    };

    setState(() => _submitting = true);
    try {
      final base = await _getBaseUrl();
      final resp = await http
          .post(
        Uri.parse('$base/telebname'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        await _clearDraft();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tələbnamə sənədi təsdiqləndi')),

        );
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
        title: const Text('Tələbnamə'),
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


                              const SizedBox(width: 8),

                              SizedBox(
                                width: 160,
                                child: _HeaderTile(
                                  label: 'Tələb olunan tarix',
                                  value: df.format(_date2),
                                  onTap: _pickDate2 ,
                                ),


                              ),


                              const SizedBox(width: 50),


                            ],



                          ),



                          const SizedBox(height: 8),

                          // 2-ci sıra: Müştəri (tam en)
                        /*  _CustomerSearchPicker(
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
                          const SizedBox(height: 8),*/

                          // 3-cü sıra: Kassa + Anbar (vardı, saxlayırıq)

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start, // Xəttatlığı qoruyur
                            children: [
                              Expanded(
                                child: _HeaderDropdownGeneric(
                                  label: 'Növ',
                                  selectedId: _selectedCashDeskId,
                                  items: _cashDesks,
                                  onChanged: (id) {
                                    setState(() {
                                      _selectedCashDeskId = id;
                                      if (id == 1) {
                                        _showSorguFields = false;
                                        _sorguNomresiCtrl.clear();
                                        _kontraAdiCtrl.clear();
                                        _layiheAdiCtrl.clear();
                                        _isinAdiCtrl.clear();
                                      }
                                      else
                                      {
                                        _showSorguFields = true;

                                      }
                                      // ============================
                                    });
                                    _recalculateAllTotals();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                // ANBAR ÜÇÜN YENİ AXTARIŞLI PİCKER
                                child: _SearchableLookupPicker(
                                  label: 'Anbar',
                                  modalTitle: 'Anbar seçin',
                                  valueText: _warehouseNameById(_selectedWarehouseId), // Köməkçi funksiyadan istifadə
                                  items: _warehouses,
                                  enabled: !_isDownloadingProducts, // Yüklənərkən deaktiv olsun
                                  onSelected: (item) {
                                    final id = item?.id;
                                    // Əgər seçim dəyişibsə, məhsulları yenidən yüklə

                                    if (id != null && id != _selectedWarehouseId) {
                                      setState(() => _selectedWarehouseId = id);
                                      if (_selectedSorguId != null && _showSorguFields == true) {
                                        _downloadMallarsorgu();
                                      }
                                      if (_showSorguFields == false) {
                                        _downloadMallar();
                                      }
                                    }

                                  },
                                ),
                              ),
                              // Yükləmə indikatoru yerində qalır
                              if (_isDownloadingProducts)
                                const Padding(
                                  padding: EdgeInsets.only(left: 12.0, top: 12.0), // Yuxarıdan boşluq
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          if (_showSorguFields) ...[
                            Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _SearchableLookupPicker(
                                  label: 'Sorğu nömrəsi',
                                  modalTitle: 'Sorğu nömrəsi seçin',
                                  valueText: _sorguNomresiCtrl.text.isEmpty
                                      ? 'Seçin və ya daxil edin'
                                      : _sorguNomresiCtrl.text,
                                  items: _sorguNomreleri,

                                  enabled: _selectedCashDeskId != 1,

                                  onSelected: (item) {
                                    if (_selectedCashDeskId != 1) {
                                      if (item != null) {
                                        setState(() {
                                          _lines.clear();
                                          _addedCounts.clear();
                                          _sorguNomresiCtrl.text = item.name;
                                          _selectedSorguId=item.id;

                                        });

                                        _fetchAndFillSorguDetails(item.name);
                                        _downloadMallarsorgu();

                                      } else {
                                        setState(() {
                                          _sorguNomresiCtrl.clear();
                                          _kontraAdiCtrl.clear();
                                          _layiheAdiCtrl.clear();
                                          _isinAdiCtrl.clear();
                                          _selectedSorguId=0;
                                        });
                                      }
                                    }
                                  },
                                ),
                              ),

                              const SizedBox(width: 8),
                              Expanded(
                                child: _HeaderDropdownGeneric(
                                  label: 'Növ',
                                  selectedId: _selectediade,
                                  items: _iade,
                                  onChanged: (id) {
                                    setState(() {
                                      _selectediade = id;

                                      if (id == 1)
                                      { // Geri


                                      } else { // 0 → Tələb


                                      }
                                    });

                                    _recalculateAllTotals();
                                  },
                                ),
                              ),

                              if (_isFetchingSorguDetails)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.0),
                                  ),
                                ),

                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isUrgent = !_isUrgent;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _isUrgent,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            _isUrgent = value ?? false;
                                          });
                                        },
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const Text(
                                        'Təcili',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8), // Sahələr arasında boşluq

                          // ==== YENİ ƏLAVƏ EDİLƏN SAHƏLƏR ====
                          // Kontragent Adı
                          TextFormField(
                            controller: _kontraAdiCtrl,
                            readOnly: true, // Redaktəni bağlayır
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                            decoration: InputDecoration(
                              labelText: 'Kontragent',
                              labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade200, // Read-only olduğunu bildirmək üçün arxa fon
                            ),
                          ),
                          const SizedBox(height: 8),


                          // Layihə Adı
                          TextFormField(
                            controller: _layiheAdiCtrl,
                            readOnly: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                            decoration: InputDecoration(
                              labelText: 'Layihə',
                              labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade200,
                            ),
                          ),
                          const SizedBox(height: 8),


                          // İşin Adı
                          TextFormField(
                            controller: _isinAdiCtrl,
                            readOnly: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                            decoration: InputDecoration(
                              labelText: 'İşin adı',
                              labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade200,
                            ),
                          ),



                          const SizedBox(height: 8),
],
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

                        /*  const SizedBox(height: 8),
                          //  5-ci sıra: Qeyd
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _noteCtrl2,
                                  style: const TextStyle(fontSize: 12), // 🔹 daxil edilən mətn balaca
                                  decoration: InputDecoration(
                                    labelText: 'Müştəri qeydi',
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
                          */

                        ],
                      ),
                    ),
                  ),

                  //const SizedBox(height: 16),
                  const SizedBox(height: 8),

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
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _lines.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final l = _lines[index];
                              final addCount = _addedCounts[l.productId] ?? 1;


                              final baseAmount = (((l.price-l.discountAmount) - ((l.price-l.discountAmount) * l.discountPercent / 100) ) * l.qty);

                              final edvAmount = baseAmount * 0.18;
                              final totalAmount = baseAmount + edvAmount;


                              l.edvAmount = edvAmount;
                              l.totalAmount = totalAmount;

                              return Dismissible(

                                key: ValueKey('${l.productId}-$index'),
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 12),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),



                                // Sola sürüşdürəndə (düzəliş)
                                secondaryBackground: Container(
                                  color: Colors.blue,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 12),
                                  child: const Icon(Icons.edit, color: Colors.white),
                                ),

                                direction: DismissDirection.horizontal, // hər iki istiqamət aktiv olsun

                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.startToEnd) {
                                    // sağa sürüşdürəndə sil
                                    await _deleteLine(index);
                                    return false; // widget siyahıdan çıxmasın
                                  } else if (direction == DismissDirection.endToStart) {
                                    // sola sürüşdürəndə düzəliş
                                    await _editLine(index);
                                    return false;
                                  }
                                  return false;
                                },

                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Sol tərəf (başlıq və məlumatlar)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l.name,
                                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                                  'Barkod: ${l.barcode}\n'
                                                  //'Qiymət: ${l.price.toStringAsFixed(2)} AZN | '
                                                      'Miqdar: ${_fmt18_3(l.qty)} | ${l.unit}\n'
                                                    //  'Endirim: ${l.discountAmount?.toStringAsFixed(2) ?? '0.00'} AZN\n'
                                                  //'Güzəşt: ${l.discountPercent?.toStringAsFixed(2) ?? '0.00'}% | Endirim: ${l.discountAmount?.toStringAsFixed(2) ?? '0.00'} AZN\n'
                                                  'Qeyd: ${l.qeyd ?? '-'}\n'
                                                  'Qutu sayı: $addCount',
                                              style: GoogleFonts.poppins(fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Sağ tərəf (məbləğlər)
                                      const SizedBox(width: 8),
                                    /*  Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Məbləğ: ${(l.price * l.qty).toStringAsFixed(2)} AZN',
                                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700),
                                          ),
                                          Text(
                                            'Endirimli məbləğ: ${(l.qty*(l.price-l.discountAmount)).toStringAsFixed(2)} AZN',
                                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700),
                                          ),
                                          if (_selectedCashDeskId == 2)
                                            Text(
                                              'ƏDV (18%): ${edvAmount.toStringAsFixed(2)} AZN',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.orangeAccent,
                                              ),
                                            )
                                         else
                                          Text(
                                            'ƏDV (18%): 0.00 AZN',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.orangeAccent,
                                            ),
                                          ),
                                          const SizedBox(height: 2),

                                          if (_selectedCashDeskId == 2)
                                            Text(
                                              'Yekun: ${(totalAmount).toStringAsFixed(2)} AZN',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.green.shade700,
                                              ),
                                            )
                                          else
                                            Text(
                                              'Yekun: ${(totalAmount-edvAmount).toStringAsFixed(2)} AZN',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                        ],
                                      ),
                                      */
                                    ],
                                  ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /*Row(
                            children: [
                              Text('Məbləğ:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('${_subtotal.toStringAsFixed(2)} AZN',
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // 3. GÜZƏŞT SAHƏSİNİ TEXTFIELD İLƏ ƏVƏZ EDİN
                          Row(
                            children: [
                              Text('Güzəşt (%):', style: GoogleFonts.poppins(fontSize: 14)),
                              const Spacer(),
                              SizedBox(
                                width: 80,
                                height: 40,
                                child: TextFormField(
                                  controller: _discountPercentController,
                                  textAlign: TextAlign.right,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 12),
                                  onTap: () {
                                    // 🔹 Xanaya klik ediləndə bütün mətni seç
                                    _discountPercentController.selection = TextSelection(
                                      baseOffset: 0,
                                      extentOffset: _discountPercentController.text.length,
                                    );
                                  },
                                  decoration: InputDecoration(
                                    labelText: '%',
                                    labelStyle: const TextStyle(fontSize: 16, color: Colors.black87),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Colors.black54),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          /*const SizedBox(height: 8),

                          Row(
                            children: [
                              Text('Endirim (AZN):', style: GoogleFonts.poppins(fontSize: 14)),
                              const Spacer(),
                              SizedBox(
                                width: 80,
                                height: 40,
                                child: TextFormField(
                                  controller: _discountAmountController,
                                  textAlign: TextAlign.right,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 12),
                                  onTap: () {
                                    // 🔹 Xanaya klik ediləndə bütün mətni seç
                                    _discountAmountController.selection = TextSelection(
                                      baseOffset: 0,
                                      extentOffset: _discountAmountController.text.length,
                                    );
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'AZN',
                                    labelStyle: const TextStyle(fontSize: 16, color: Colors.black87),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Colors.black54),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          */
                          const Divider(height: 20, thickness: 1),
                          Row(
                            children: [
                              Text('Endirimli məbləğ:', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text('${_discountedTotal.toStringAsFixed(2)} AZN',
                                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            ],
                          ),
                          const SizedBox(height: 16),


                          Row(
                            children: [
                              Text(
                                'ƏDV (18%):',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (_selectedCashDeskId == 2)
                                Text(
                                  '${_edv.toStringAsFixed(2)} AZN',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else
                                Text(
                                  '0.00 AZN',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),

*/
                       /*   const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('Yekun:', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              if (_selectedCashDeskId == 2)
                              Text('${_yekun.toStringAsFixed(2)} AZN',
                                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple))
                              else
                                Text('${(_yekun-_edv).toStringAsFixed(2)} AZN',
                                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            ],
                          ),

*/
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _submitting ? null : _submit,
                                  icon: _submitting
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
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


