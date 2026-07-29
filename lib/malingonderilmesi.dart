import 'dart:convert';
import 'dart:io';
import 'package:aliyev_apk/sifarissenedler_page.dart';
import 'package:aliyev_apk/telebnameler.dart';
import 'package:aliyev_apk/telebnamesenedler_page.dart';
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
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'main.dart' show globalIp, globalPort, globalAllowDateChange, globalTermname,globalceki, globaleded, kSavedPrinterAddrKey, kSavedPrinterNameKey, globalUsername;  // qlobal dəyərlər üçün
import 'dart:async';




final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

final AudioPlayer _audioPlayer1 = AudioPlayer();


BluetoothDevice? _printer;
bool _btConnecting = false;
bool _btConnected  = false;

bool _isDownloadingProducts = false;

List<BluetoothDevice> _bluetoothDevices = []; // Adı _devices ilə qarışmasın deyə dəyişdim
BluetoothDevice? _selectedBluetoothDevice;
bool _isBluetoothConnected = false;
bool _isLoadingBluetoothAction = false;





class _SearchableLookupPicker extends StatelessWidget {
  final String label;
  final String modalTitle;
  final String valueText;
  final List<LookupItem> items;
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
  final double qtysay;
  final String qeyd;
  final String unit;
  final int addCount;

  final double tqty;
  final double tqtysay;

  SaleLine({
    required this.productId,
    required this.barcode,
    required this.name,
    required this.price,
    required this.qty,
    required this.qtysay,
    required this.qeyd,
    required this.unit,
    this.addCount = 1,

    required this.tqty,
    required this.tqtysay,

  });

  SaleLine copyWith({
    int? productId,
    String? barcode,
    String? name,
    double? price,
    double? qty,
    double? qtysay,
    String? qeyd,
    String? unit,
    int? addCount,
  }) {
    return SaleLine(
      productId: productId ?? this.productId,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      qtysay: qtysay ?? this.qtysay,
      qeyd: qeyd ?? this.qeyd,
      unit: unit ?? this.unit,
      addCount: addCount ?? this.addCount,

      tqty: tqty ?? this.tqty,
      tqtysay: tqtysay ?? this.tqtysay,
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'barcode': barcode,
    'name': name,
    'price': price,
    'qty': qty,
    'qtysay': qtysay,
    'qeyd': qeyd,
    'unit': unit,
    'addCount': addCount,
    'tqty': tqty,
    'tqtysay': tqtysay,
  };

  factory SaleLine.fromMap(Map<String, dynamic> m) => SaleLine(
    productId: (m['productId'] as num).toInt(),
    barcode: (m['barcode'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    price: (m['price'] as num).toDouble(),
    qty: (m['qty'] as num).toDouble(),
    qtysay: (m['qtysay'] as num? ?? 0).toDouble(),
    qeyd: (m['qeyd'] ?? '').toString(),
    unit: (m['unit'] ?? m['unit_name'] ?? '').toString(),
    addCount: (m['addCount'] as num? ?? 1).toInt(), // Null yoxlaması
    tqty: (m['tqty'] as num).toDouble(),
    tqtysay: (m['tqtysay'] as num? ?? 0).toDouble(),


  );
}

//================ ƏSAS SƏHİFƏ WIDGET-İ ================




final NumberFormat _qtyFmt18_3 = NumberFormat('0.00', 'az'); // 1 234,56 kimi
String _fmt18_3(num v) => _qtyFmt18_3.format(v);


final NumberFormat _qtyFmt18_2 = NumberFormat('0', 'az'); // 1 234,56 kimi
String _fmt18_2(num v) => _qtyFmt18_2.format(v);

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0); // Əgər 5.0-dırsa "5" göstər
  return v.toString(); // Əgər 5.5-dirsə "5.5" göstər
}
// Bu formatlayıcı kəsr hissələrini göstərir (maksimum 2 rəqəm)
final NumberFormat _qtyFmtDecimal = NumberFormat('0.##', 'az');
String _fmtDecimal(num v) => _qtyFmtDecimal.format(v);


/// ---- SƏHİFƏ ----


class MalingonderilmesiPage extends StatefulWidget {
  final TelebnameHeader? sened;
  final bool isSale;


  const MalingonderilmesiPage({super.key, this.sened,  this.isSale = false,});

  @override
  State<MalingonderilmesiPage> createState() => _MalingonderilmesiPageState();
}

class _MalingonderilmesiPageState extends State<MalingonderilmesiPage> {


  // Bu funksiyanı _MalingonderilmesiPageState class-ının içinə əlavə edin

  (String, Color) _buildSifarisTalebi(SaleLine line) {
    final double tqty = line.tqty; // Fərz edirik ki, SaleLine modelində bu dəyərlər var
    final double tqtysay = line.tqtysay;

    final Color sifarisColor = Colors.orange[800]!; // Sifariş üçün standart narıncı rəng
    final Color kenarColor = Colors.blueGrey;      // "Sifarişdən kənar" üçün yeni boz rəng

    final bool hasQty = tqty > 0;
    final bool hasQtySay = tqtysay > 0;

    if (hasQty && hasQtySay) {

      return ('Tələbnamə əsasında ${_fmt18_3(tqty)} ${line.unit} tələb olunur', sifarisColor);
    } else if (hasQty) {

      return ('Tələbnamə əsasında ${_fmt18_3(tqty)}  ${line.unit} tələb olunur', sifarisColor);
    } else if (hasQtySay) {

      return ('Tələbnamə əsasında ${_fmt18_3(tqty)} ${line.unit} tələb olunur', sifarisColor);
    } else {

      return ('Tələbnamədən kənar', kenarColor);
    }
  }



  String _warehouseNameById(int? id) {
    if (id == null) return 'Seçilməyib';
    return _warehouses.firstWhere((e) => e.id == id, orElse: () => LookupItem(id: id, name: 'ID: #$id')).name;
  }
  String _warehousecNameById(int? id) {
    if (id == null) return 'Seçilməyib';
    return _warehousesc.firstWhere((e) => e.id == id, orElse: () => LookupItem(id: id, name: 'ID: #$id')).name;
  }

  final _formKey = GlobalKey<FormState>();

  List<LookupItem> _sorguNomreleri = []; // API-dən gələcək sorğu nömrələri siyahısı
  bool _isFetchingSorguDetails = false;

  final TextEditingController _kontraAdiCtrl = TextEditingController();
  final TextEditingController _telebnameNomresiCtrl = TextEditingController();
  final TextEditingController _sorguNomresiCtrl = TextEditingController();
  final TextEditingController _layiheAdiCtrl = TextEditingController();
  final TextEditingController _emekdasAdiCtrl = TextEditingController();
  final TextEditingController _isinAdiCtrl = TextEditingController();
  final TextEditingController _warehouseNameCtrl = TextEditingController();

  // Header sahələri
  DateTime _date = DateTime.now();
  DateTime _date2 = DateTime.now();

  int? _selectedCustomerId;
  int? _selectedSorguId;
  String? _selectedCustomerName;

  int? _selectedCashDeskId;
  int? _selectedWarehouseId;
  int? _selectedWarehousecId;

  bool _isUrgent = false;



  bool _showSorguDetails = false;

  String _paymentType = 'Nisyə'; // 'Nağd' | 'Nisyə'

  List<LookupItem> _customers = [];
  List<LookupItem> _cashDesks = [];
  List<LookupItem> _warehouses = [];
  List<LookupItem> _warehousesc = [];

  List<LookupItem> _classList = [];
  List<LookupItem> _propertyList = [];

  LookupItem? selectedProperty;
  LookupItem? selectedClass;

  // Sətirlər və UI vəziyyəti
  String? _username;
  final List<SaleLine> _lines = [];
  final TextEditingController _noteCtrl = TextEditingController();
  bool _loadingLookups = true;
  String? _lookupError;
  bool _submitting = false;

  // İR Skaner dəyişənləri
  final FocusNode _irFocus = FocusNode();
  final TextEditingController _irCtrl = TextEditingController();
  Timer? _irCtrlTimer;
  DateTime? _irCtrlLastAt;
  static const int _irCtrlGapMs = 300;

  // Draft
  static const String _draftKey = 'sifaris_draft';

// Vizual debug/overlay üçün
  String _irDebugBuffer = '';
  String? _lastScanned;

  String? _lastCommitted;
  DateTime? _lastCommittedAt;





  double get _totalQty => _lines.fold(0.0, (s, e) => s + e.qty);
  int get _lineCount => _lines.length;

  final Map<int, int> _addedCounts = {}; // productId -> neçə dəfə əlavə olunub

  void _incCount(int productId) {
    _addedCounts.update(productId, (v) => v + 1, ifAbsent: () => 1);
  }

  int get _totalAddedCount =>
      _addedCounts.values.fold(0, (sum, v) => sum + v);

  //double get _total => _lines.fold(0.0, (sum, e) => sum + (e.price * e.qty));


  double get _total => _lines.fold(
    0.0,
        (sum, e) => sum + (e.qty == 0 ? (e.price * e.qtysay) : (e.price * e.qty)),
  );


  @override
  void initState() {
    super.initState();
    _irCtrl.addListener(_onIrCtrlChanged);

    // Bütün ilkin yükləmələri vahid bir funksiyada birləşdiririk
    _initializePage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_irFocus);
    });
    _irFocus.addListener(() {
      if (_irFocus.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    });
  }
  // sifaris.dart faylında bu funksiyanı tapıb dəyişin

  // sifaris.dart faylında bu funksiyanı tapıb tam əvəz edin

  Future<void> _initializePage() async {
    // 1. ƏVVƏLCƏ bütün lookup siyahılarını serverdən yükləyirik.
    //    Bu funksiya bitənə qədər gözləyirik.
    await _loadLookups();

    // Əgər səhifə artıq mövcud deyilsə, davam etməyə ehtiyac yoxdur.
    if (!mounted) return;

    // 2. YALNIZ BUNDAN SONRA, əgər düzəliş rejimindəyiksə,
    //    sənəddən gələn məlumatları sahələrə doldururuq.
    if (widget.sened != null && widget.isSale == true) {
      _populateFieldsFromSened(widget.sened!);
    }
    else if (widget.isSale == false) {
      _populateFieldsFromSenedduz(widget.sened!);
    }
    else {
      // 3. Əks halda, yeni sənəd üçün qaralamanı (draft) yükləyirik.
      await _loadDraft();
    }
  }




  void _populateFieldsFromSened(TelebnameHeader sened) {

    setState(() {
      final int? sorguNomresi = sened.contract;

      if (sorguNomresi != null && sorguNomresi > 0) {
        _showSorguDetails = true; // Sahələri göstər
        _sorguNomresiCtrl.text = sorguNomresi.toString();
        _kontraAdiCtrl.text = sened.customerName ?? '';
        _layiheAdiCtrl.text = sened.layiheadi ?? '';
        _isinAdiCtrl.text = sened.isintesviri ?? '';
      } else {
        _showSorguDetails = false;
        _sorguNomresiCtrl.clear();
        _kontraAdiCtrl.clear();
        _layiheAdiCtrl.clear();
        _isinAdiCtrl.clear();
      }
      _date = sened.date ?? DateTime.now();
      _date2 = sened.telebdate ?? DateTime.now();
      _noteCtrl.text = sened.note ?? '';
      _selectedCustomerId = sened.customer;
      _selectedCustomerName = sened.customerName;
      _telebnameNomresiCtrl.text = sened.documentNo.toString();
      _sorguNomresiCtrl.text=sened.contract.toString() ?? '';
      _kontraAdiCtrl.text = sened.customerName ?? '';
      _layiheAdiCtrl.text = sened.layiheadi ?? '';
      _isinAdiCtrl.text = sened.isintesviri ?? '';
      _emekdasAdiCtrl.text = sened.ekspeditor ?? '';
      // 1. Giriş anbarının ID-sini sənəddən gələn `depo` ID-si ilə təyin edirik.
      _selectedWarehouseId = sened.depo;

      // 2. Çıxış anbarını isə hələlik seçilməmiş saxlayırıq (və ya defolt dəyər veririk).
      //    Siz burada biznes məntiqinizə uyğun olaraq istənilən anbarı təyin edə bilərsiniz.
      //    Məsələn, həmişə ilk anbar çıxış olsun deyə:
      _selectedWarehousecId ??= _warehouses.isNotEmpty ? _warehouses.first.id : null;

      // 3. Giriş anbarının adını ekranda göstərmək üçün controller-i doldururuq.
      //    Bu addım artıq _warehouseNameById funksiyası mövcud olduğu üçün işləyəcək.
      if (_selectedWarehouseId != null) {
        _warehouseNameCtrl.text = _warehouseNameById(_selectedWarehouseId);
      }

      _lines.clear();
      _addedCounts.clear();

      _lines.addAll(sened.lines.map((sifarisLine) {
        _addedCounts.update(sifarisLine.idn ?? 0, (value) => value + 1, ifAbsent: () => 1);

        return SaleLine(

          productId: sifarisLine.idn ?? 0,
          barcode: sifarisLine.barcode ?? '',
          name: sifarisLine.malName ?? '',
          price: 0,
          qty:  0.00,
          qtysay: 0.0, // <-- ƏKSİK OLAN PARAMETR
          unit: sifarisLine.vahid ?? '', // <-- ƏKSİK OLAN PARAMETR
          qeyd: '',
          tqty: sifarisLine.quantity ?? 0,
          tqtysay: 0, // <-- Defolt dəyər olaraq 0 veririk

        );


      }));

    });

    if (_selectedCustomerId != null) {
      _downloadMallar();
    }

  }


  void _populateFieldsFromSenedduz(TelebnameHeader sened) {

    setState(() {
      final int? sorguNomresi = sened.contract;

      if (sorguNomresi != null && sorguNomresi > 0) {
        _showSorguDetails = true; // Sahələri göstər
        _sorguNomresiCtrl.text = sorguNomresi.toString();
        _kontraAdiCtrl.text = sened.customerName ?? '';
        _layiheAdiCtrl.text = sened.layiheadi ?? '';
        _isinAdiCtrl.text = sened.isintesviri ?? '';
      } else {
        _showSorguDetails = false;
        _sorguNomresiCtrl.clear();
        _kontraAdiCtrl.clear();
        _layiheAdiCtrl.clear();
        _isinAdiCtrl.clear();
      }
      _date = sened.date ?? DateTime.now();
      _date2 = sened.telebdate ?? DateTime.now();
      _noteCtrl.text = sened.note ?? '';
      _selectedCustomerId = sened.customer;
      _selectedCustomerName = sened.customerName;
      _telebnameNomresiCtrl.text = sened.documentNo.toString();
      _sorguNomresiCtrl.text=sened.contract.toString() ?? '';
      _kontraAdiCtrl.text = sened.customerName ?? '';
      _layiheAdiCtrl.text = sened.layiheadi ?? '';
      _isinAdiCtrl.text = sened.isintesviri ?? '';
      _emekdasAdiCtrl.text = sened.ekspeditor ?? '';

      _selectedWarehouseId = sened.depo;

      _selectedWarehousecId ??= _warehouses.isNotEmpty ? _warehouses.first.id : null;

      if (_selectedWarehouseId != null) {
        _warehouseNameCtrl.text = _warehouseNameById(_selectedWarehouseId);
      }

      _lines.clear();
      _addedCounts.clear();

      _lines.addAll(sened.lines.map((sifarisLine) {
        _addedCounts.update(sifarisLine.idn ?? 0, (value) => value + 1, ifAbsent: () => 1);

        return SaleLine(

          productId: sifarisLine.idn ?? 0,
          barcode: sifarisLine.barcode ?? '',
          name: sifarisLine.malName ?? '',
          price: 0,
          qty:  sifarisLine.quantity_given ?? 0,
          qtysay: 0.0, // <-- ƏKSİK OLAN PARAMETR
          unit: sifarisLine.vahid ?? '', // <-- ƏKSİK OLAN PARAMETR
          qeyd: '',
          tqty: sifarisLine.quantity ?? 0,
          tqtysay: 0, // <-- Defolt dəyər olaraq 0 veririk

        );


      }));

    });

    if (_selectedCustomerId != null) {
      _downloadMallar();
    }

  }




  static const String kSavedPrinterAddrKey = 'saved_printer_address';

  /// Cütləşdirilmiş siyahıda MAC-ə görə cihazı tapır (tapmasa null qaytarır)
  BluetoothDevice? _findByAddress(List<BluetoothDevice> list, String addr) {
    try {
      return list.firstWhere((d) => (d.address ?? '') == addr);
    } catch (_) {
      return null;
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
      final bonded = await bluetooth.getBondedDevices();

      final prefs = await SharedPreferences.getInstance();
      final addr = prefs.getString(kSavedPrinterAddrKey);
      if (addr == null || addr.isEmpty) return;

      final match = _findByAddress(bonded, addr);
      if (match == null) return;

      _printer = match;

      final isConn = await bluetooth.isConnected ?? false;
      if (!isConn) {
        if (_btConnecting) return;
        _btConnecting = true;
        await bluetooth.connect(match);
      }
      setState(() => _btConnected = true);
    } catch (e) {
      setState(() => _btConnected = false);
    } finally {
      _btConnecting = false;
    }
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



  // sifaris.dart faylında _loadLookups funksiyasını bu kodla TAM ƏVƏZ EDİN

  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });

    try {
      final base = await _getBaseUrl();

      final endpoints = {
        'Müştəri': '$base/musteri?userId=$globalTermname',
        'Tələb Növü': '$base/telebnovu',
        'Anbar': '$base/anbar?userId=$globalTermname',
        'Class': '$base/class',
        'Properties': '$base/properties',
        'Sorğu Nömrələri': '$base/sorgu-nomreleri',
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
      final anbJsonc = jsonDecode(responses[2].body) as List;

      // Map et
      final customers = custJson.map((e) => LookupItem.fromMap(e)).toList();
      final kassas = kassJson.map((e) => LookupItem.fromMap(e)).toList();
      final anbars = anbJson.map((e) => LookupItem.fromMap(e)).toList();
      final classes = classJson.map((e) => LookupItem.fromMap(e)).toList();
      final properties = propJson.map((e) => LookupItem.fromMap(e)).toList();
      final anbarsc = anbJsonc.map((e) => LookupItem.fromMap(e)).toList();

      // ===== DƏYİŞİKLİK BURADADIR =====
      // Bu sətir daha təhlükəsizdir. 'idn' və 'name' sahələrinin mövcudluğunu yoxlayır.
      final sorgular = sorguJson.map((e) {
        final id = int.tryParse(e['idn']?.toString() ?? '');
        final name = e['name']?.toString() ?? 'Adsız';
        if (id != null) {
          return LookupItem(id: id, name: name);
        }
        return null; // Əgər id parse edilə bilmirsə, elementi ötür.
      }).whereType<LookupItem>().toList(); // Yalnız null olmayan elementləri saxla.
      // ================================

      // State-i təyin et
      setState(() {
        _customers = customers;
        _cashDesks = kassas;
        _warehouses = anbars;
        _classList = classes;
        _propertyList = properties;
        _sorguNomreleri = sorgular;

        _warehousesc = anbarsc;

        // Bu hissənin dəyişməz qaldığından əmin olun
        _selectedCashDeskId ??= _cashDesks.isNotEmpty ? _cashDesks.first.id : null;
        _selectedWarehouseId ??= _warehouses.isNotEmpty ? _warehouses.first.id : null;
        _selectedWarehousecId ??= _warehousesc.isNotEmpty ? _warehousesc.first.id : null;
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




  @override
  void dispose() {
    _irCtrl.removeListener(_onIrCtrlChanged);
    _irCtrl.dispose();
    _irFocus.dispose();
    _irCtrlTimer?.cancel();
    _noteCtrl.dispose();
    super.dispose();
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(
                'Məhsul siyahısı boşdur. “Məlumatları yenilə” edin.')),
          );
        return;
      }

      if(_selectedCustomerId==null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(
                'Müştəri seçilməyib')),
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
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(
                  'Tərəzi barkodu üçün məhsul tapılmadı (PLU: $plu)')),
            );
          return;
        }

        final productId = _toInt(matchedScale['idn']);
        if (productId == null) {
          await _playDingSound1();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
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
              qtysay: 0, // <-- Əlavə edildi
              qeyd: '',
              unit: unit,
              tqty: 0,     // <-- Əlavə edildi
              tqtysay: 0, // <-- Əlavə edildi
            ));
          }
        });
        _incCount(productId);

        await _askQtyAndAdd(
          productId: productId,
          barcode: barkod.isNotEmpty ? barkod : barcode,
          name: name,
          price: price,
          presetQty: qty,
          presetQtysay: 0,
          presetPrice: price,
          bypassDialog: true,
        );


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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar() // əvvəlki mesajı gizlə
          ..showSnackBar(
            SnackBar(content: Text('Barkod tapılmadı : $barcode')),
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar() // əvvəlki mesajı gizlə
          ..showSnackBar(
            const SnackBar(content: Text('Məhsul ID tapılmadı.')),
          );
        return;
      }

      setState(() async {
        final idx = _lines.indexWhere((e) => e.productId == idn);
        if (idx != -1) {
          final ex = _lines[idx];
          _lines[idx] = ex.copyWith(qty: ex.qty + 1);
        } else {
          _lines.add(SaleLine( // <--- Sinif adı düzəldildi
            productId: idn,
            barcode: barkod,
            name: name,
            price: price,
            qty: 1,
            qtysay: 0, // <-- Əlavə edildi
            qeyd: '',
            unit: unit,
            tqty: 0,     // <-- Əlavə edildi
            tqtysay: 0, // <-- Əlavə edildi
          ));


        await _askQtyAndAdd(
          productId: idn,
          barcode:  barkod,
          name: name,
          price: price,
          presetQty: 1,
          presetQtysay: 0,
          presetPrice: price,
          bypassDialog: true,
          cekieded: 1,
        );


         }
      });
      _incCount(idn);

      if (!mounted) return;
      /*ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“$name” (1) əlavə olundu')),
      );*/
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
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

  Future<void> _handleScannedBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('mallar_data');
    if (jsonStr == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Məhsul siyahısı boşdur. “Məlumatları yenilə” edin.')),
          );
      }
      return;
    }

    final List<dynamic> allRaw = jsonDecode(jsonStr);
    final List<Map<String, dynamic>> all = allRaw
        .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
        .cast<Map<String, dynamic>>()
        .toList();

    // 1) tərəzi barkodu?
    final parsed = _parseScaleBarcode(code);
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
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('Tərəzi barkodu üçün məhsul tapılmadı (PLU: $plu)')),
            );
        }
        return;
      }

      final productId = _toInt(matchedScale['idn']);
      if (productId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Məhsulda idn tapılmadı.')),
            );
        }
        return;
      }

      final name   = matchedScale['adi']?.toString() ?? '';
      final barkod = matchedScale['barkod']?.toString() ?? '';
      final price  = double.tryParse(matchedScale['satis']?.toString() ?? '') ?? 0.0;

      await _askQtyAndAdd(
        productId: productId,
        barcode: barkod.isNotEmpty ? barkod : code,
        name: name,
        price: price,
        presetQty: qty,
        presetQtysay: 0,
        presetPrice: price,
        bypassDialog: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('“$name” (${qty.toStringAsFixed(3)}) kq və (0) ədəd əlavə olundu')),
          );
      }
      return;
    }

    // 2) adi barkod
    final matched = all.firstWhere(
          (m) => (m['barkod']?.toString() ?? '') == code,
      orElse: () => {},
    );

    if (matched.isEmpty) {
      await _playDingSound1();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Barkod tapılmadı: $code')),
          );
      }
      return;
    }

    final idn    = (matched['idn'] as num?)?.toInt();
    final name   = matched['adi']?.toString() ?? '';
    final barkod = matched['barkod']?.toString() ?? '';
    final price  = double.tryParse(matched['satis']?.toString() ?? '') ?? 0.0;

    if (idn == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Məhsul ID tapılmadı.')),
          );
      }
      return;
    }

    final added = await _askQtyAndAdd(
      productId: idn,
      barcode: barkod,
      name: name,
      price: price,
    );

    if (added && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('“$name” əlavə olundu')),
        );
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


  Future<bool> _askQtyAndAdd({
    required int productId,
    required String barcode,
    required String name,
    required double price,
    String unit = '', // <--- YENİ PARAMET
    double? presetQty,
    double? presetQtysay,
    double? presetPrice,
    bool bypassDialog = false,
    int? cekieded,
  }) async {


    final qtyCtrl = TextEditingController(text: (presetQty ?? 1).toString());
    final qtysayCtrl = TextEditingController(text: (presetQtysay ?? 0).toString());
    final priceCtrl = TextEditingController(text: (presetPrice ?? price).toStringAsFixed(2));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      qtyCtrl.selection = TextSelection(baseOffset: 0, extentOffset: qtyCtrl.text.length);
    });



    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        String? errorText;

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
    final qtysay = double.tryParse(qtysayCtrl.text.replaceAll(',', '.')) ?? (presetQtysay ?? 0);
    final prc = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? (presetPrice ?? price);

    setState(() {
      final idx = _lines.indexWhere((e) => e.productId == productId);


      if(cekieded==1) {


        _lines.add(SaleLine(
          productId: productId,
          barcode: barcode,
          name: name,
          price: prc,
          qty: qty,
          qtysay: qtysay,
          qeyd: '',
          unit: unit,
          tqty: 0.0,
          tqtysay: 0.0,

        )

        );
      }
      else{
        _lines.add(SaleLine(
          productId: productId,
          barcode: barcode,
          name: name,
          price: prc,
          qty: qty,
          qtysay: qtysay,
          qeyd: '',
          unit: unit,
          tqty: 0.0,
          tqtysay: 0.0,
        )

        );

      }
    });
    _incCount(productId);
    return true;



  }

  // sifaris.dart faylında _editLine funksiyasını bu kodla TAM ƏVƏZ EDİN

  Future<void> _editLine(int index) async {
    final line = _lines[index];

    final qtyCtrl = TextEditingController(text: line.qty.toString());
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
    final ln = qeydCtrl.text.trim();

    setState(() {
      _lines[index] = line.copyWith(
        qty: qty,
        price: enteredPrice,
        qeyd: ln,
      );
    });

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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
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


  Future<void> _scanAndAddProductLoop() async {
    if(_selectedCustomerId!=null){
      while (mounted) {
        final barcode = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
        );

        if (barcode == null || barcode
            .trim()
            .isEmpty) break;

        final prefs = await SharedPreferences.getInstance();
        final jsonStr = prefs.getString('mallar_data');
        if (jsonStr == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text(
                  'Məhsul siyahısı boşdur. “Məlumatları yenilə” edin.')),
            );
          break;
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
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(
                    'Tərəzi barkodu üçün məhsul tapılmadı (PLU: $plu)')),
              );
            continue;
          }

          final productId = _toInt(matchedScale['idn']);
          if (productId == null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Məhsulda idn tapılmadı.')),
              );
            continue;
          }

          final name = matchedScale['adi']?.toString() ?? '';
          final barkod = matchedScale['barkod']?.toString() ?? '';
          final price = double.tryParse(
              matchedScale['satis']?.toString() ?? '') ?? 0.0;

          await _askQtyAndAdd(
            productId: productId,
            barcode: barkod.isNotEmpty ? barkod : barcode,
            name: name,
            price: price,
            presetQty: qty,
            presetQtysay: 0,
            presetPrice: price,
            bypassDialog: true,
          );

          if (!mounted) break;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(
                  '“$name” (${qty.toStringAsFixed(3)}) əlavə olundu')),
            );
          continue;
        }

        // 2) Adi barkod
        final matched = all.firstWhere(
              (m) => (m['barkod']?.toString() ?? '') == barcode,
          orElse: () => {},
        );

        if (matched.isEmpty) {
          await _playDingSound1();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('Barkod tapılmadı: $barcode')),
            );
          continue;
        }

        final idn = (matched['idn'] as num?)?.toInt();
        final name = matched['adi']?.toString() ?? '';
        final barkod = matched['barkod']?.toString() ?? '';
        final price = double.tryParse(matched['satis']?.toString() ?? '') ?? 0.0;

        if (idn == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Məhsul ID tapılmadı.')),
            );
          continue;
        }

        final added = await _askQtyAndAdd(
          productId: idn,
          barcode: barkod,
          name: name,
          price: price,
        );

        if (!mounted) break;

        if (added) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('“$name” əlavə olundu')),
            );
          continue;
        } else {
          break;
        }
      }
    }else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar() // əvvəlki mesajı gizlə
        ..showSnackBar(
          const SnackBar(content: Text('Müştəri seçilməyib')),
        );
      return;
    }
  }

  Future<void> _connectToBluetoothDevice(BluetoothDevice device) async {
    if (_isBluetoothConnected && _selectedBluetoothDevice?.address == device.address) {
      return;
    }
    if (_isBluetoothConnected) {
      await _disconnectFromBluetoothDevice();
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text("${device.name ?? 'Naməlum cihaz'}-a qoşuldu.")),
          );
      }
    } catch (e) {
      debugPrint("Bluetooth cihazına qoşularkən xəta: $e");
      if(mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text("Cihaza qoşularkən xəta: $e")),
          );
      }
    } finally {
      if(mounted) setState(() => _isLoadingBluetoothAction = false);
    }
  }

  void _showBluetoothDeviceListDialog() {
    _getPairedBluetoothDevices();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
                        Navigator.of(dialogContext).pop();
                        await _connectToBluetoothDevice(device);
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
                      Navigator.of(dialogContext).pop();
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text("Cihazdan ayrıldı.")),
          );
      }
    } catch (e) {
      debugPrint("Bluetooth cihazından ayrılarkən xəta: $e");
      if(mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
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
    return i == -1 ? '-' : list[i].name;
  }

  String _money(num v) => v.toStringAsFixed(2);
  String _qtyStr(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  String _azNormalize(String s) {
    return s
        .replaceAll('ə', 'e')
        .replaceAll('Ə', 'E');
  }

  void _p(String text, {int size = 1, int align = 0}) {
    final fixed = _azNormalize(text);
    bluetooth.printCustom(fixed, size, align, charset: 'windows-1254');
  }

  void _plr(String left, String right, {int size = 1}) {
    final l = _azNormalize(left);
    final r = _azNormalize(right);
    bluetooth.printLeftRight(l, r, size, charset: 'windows-1254');
  }

  Future<void> _ensurePrinterConnected() async {
    final isConn = await bluetooth.isConnected ?? false;
    if (isConn) return;

    if (_printer == null) {
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
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
      final useradi = _username;

      _p("SIFARIS", size: 3, align: 1);
      _p("---------------------------------------------------------", align: 1);
      _plr("Tarix:", df.format(_date));
      _plr("Ekspeditor:", useradi ?? '-');
      _plr("Musteri:", musteri);
      _plr("Anbar:", anbar);
      _plr("Odenis novu:", odenis);
      if (_paymentType == 'Nağd') { // ✅ burada da Nağd
        _plr("Kassa:", kassa);
      }
      _p("---------------------------------------------------------", align: 1);

      for (final l in _lines) {
        final addCount = _addedCounts[l.productId] ?? 0;
        _p(l.name, size: 1, align: 0); // Məhsul adı

        // Miqdarı və qiyməti 2 onluq işarə ilə formatla
        String formattedQty = l.qty.toStringAsFixed(2);
        String formattedPrice = l.price.toStringAsFixed(2); // _money(l.price) ilə eynidir

        final sol = "$formattedQty x $formattedPrice"; // Məsələn: "1.00 x 10.50"
        final sag = "${_money(l.price * l.qty)} AZN"; // Məsələn: "10.50 AZN"

        _plr(sol, sag, size: 1);
        if (addCount > 0) {
          _p("Qutu sayi: $addCount", size: 1, align: 0);
        }
        if (l.qeyd.trim().isNotEmpty) {
          _p("Qeyd: ${l.qeyd}", size: 0, align: 0);
        }

        bluetooth.printNewLine();
      }

      _p("---------------------------------------------------------", align: 1);
      _plr("Umumi qutu sayi:", "$_totalAddedCount", size: 2);
      _plr("CƏM:", "${_money(_total)} AZN", size: 2);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      bluetooth.paperCut();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text("Çap göndərildi.")),
          );
      }
    } catch (e) {
      debugPrint("Çap zamanı xəta: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
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

    if(_selectedCustomerId==null)

    {ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar() // əvvəlki mesajı gizlə
      ..showSnackBar(
        const SnackBar(content: Text('Müştəri seçilməyib')),
      );
    return;

    }

    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (barcode == null || barcode.trim().isEmpty) return;
    await _handleScannedBarcode(barcode);
  }







  bool _isScaleBarcode(String bc) {
    if (bc.length != 13) return false;
    return bc.startsWith('$globaleded') || bc.startsWith('$globalceki');
  }

  ({int plu, double qty})? _parseScaleBarcode(String bc) {
    try {
      if (!_isScaleBarcode(bc)) return null;
      final pluStr = bc.substring(3, 7);
      final qtyStr = bc.substring(7, 12);
      final plu = int.parse(pluStr);
      final qty = int.parse(qtyStr) / 100.0;
      if (qty <= 0) return null;
      return (plu: plu, qty: qty);
    } catch (_) {
      return null;
    }
  }




  Future<void> _createPdf() async {
    String borcValue = "0.00 AZN";
    String customerNameToDisplay = _selectedCustomerName ?? ""; // Müştəri adının ilkin dəyəri

    // 1. Müştəri adının boş olmadığını və sonunda "AZN" olduğunu yoxlayırıq
    if (_selectedCustomerName != null && _selectedCustomerName!.endsWith(" AZN")) {
      // 2. Sətri boşluqlara görə bölürük
      final parts = _selectedCustomerName!.split(' ');

      // 3. Ən azı iki hissənin olduğundan əmin oluruq (məbləğ və "AZN")
      if (parts.length >= 2) {
        // Sondan ikinci element məbləğdir, sonuncu isə "AZN"
        final amount = parts[parts.length - 2];
        final currency = parts[parts.length - 1];

        // Məbləğin rəqəm formatında olub-olmadığını yoxlaya bilərik
        if (double.tryParse(amount) != null) {
          borcValue = "$amount $currency";

          // 4. Müştərinin təmiz adını əldə edirik (borc məlumatını çıxarırıq)
          // Bütün hissələrdən son iki elementi (məbləğ və AZN) çıxarıb qalanını birləşdiririk.
          customerNameToDisplay = parts.sublist(0, parts.length - 2).join(' ');
        }
      }
    }

    final pdf = pw.Document();
    final ttf = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
    final font = pw.Font.ttf(ttf);
    final payment = _paymentType == 'Nağd' ? "Nağd" : "Nağdsız";

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Center(
            child: pw.Text(
              "BuğaƏt Məhsulları Sifariş",
              style: pw.TextStyle(font: font, fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Divider(),
          pw.Text("Tarix: ${_date.toIso8601String()}", style: pw.TextStyle(font: font)),

          // 5. PDF-də müştərinin təmiz adını göstəririk
          pw.Text("Müştəri: $customerNameToDisplay", style: pw.TextStyle(font: font)),
          //pw.Text("Sürücü: $_selectedSurucuName", style: pw.TextStyle(font: font)),
          //pw.Text("Ekspeditor: $globalUsername", style: pw.TextStyle(font: font)),
          pw.Text("Ödəniş növü: $payment", style: pw.TextStyle(font: font)),
          if (_noteCtrl.text.trim().isNotEmpty)
            pw.Text("Qeyd: ${_noteCtrl.text.trim()}", style: pw.TextStyle(font: font)),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.Table.fromTextArray(
            headers: [
              'Məhsul',
              'Çəki',
              'Say',
              'Əza',
              'Əza Növ',
              'Qiymət',
              'Məbləğ', // Bu sütun dəyişəcək
              'Qeyd'
            ],
            data: _lines.map((line) {
              // ================== DƏYİŞİKLİK BURADADIR ==================
              // Hər bir sətir üçün məbləği hesablamaq üçün eyni məntiqi tətbiq edirik.
              final double lineTotal = line.qty == 0
                  ? (line.price * line.qtysay) // Say üzrə hesablama
                  : (line.price * line.qty);   // Çəki üzrə hesablama

              return [
                line.name.toString(),
                line.qty.toString() + ' kg',
                line.qtysay.toString() + ' əd',
                line.price.toStringAsFixed(2) + ' AZN',
                lineTotal.toStringAsFixed(2) + ' AZN', // Düzgün hesablanmış məbləği istifadə edirik
                line.qeyd ?? "",
              ];
              // ==========================================================
            }).toList(),
            headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(font: font),
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              // `_total` və yeni əldə edilmiş `borcValue` istifadə olunur
              "Cəmi: ${_total.toStringAsFixed(2)} AZN\nƏvvəlki Borc: $borcValue",
              style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }


  Future<String?> _askPrintConfirmation() async {
    if (!mounted) return null;

    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Əməliyyat uğurla təsdiqləndi'),
        content: const Text('Çap əməliyyatı seçin:'),
        actions: [
          // Ləğv
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Ləğv'),
          ),

          // PDF-ə çıxart
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, 'pdf'),
            child: const Text('PDF-ə çıxart'),
          ),

          // Çap et
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'print'),
            child: const Text('Çap et'),
          ),
        ],
      ),
    );

    return res; // 'pdf', 'print' və ya 'cancel'
  }


  //// START_SIFARIS_DART_SUBMIT_CHANGE

  // sifarissenedler_page.dart faylına bu kodu köçürün



  // Bu funksiya köhnə _submit funksiyalarını əvəz edir
  Future<void> _submit() async {
    // Səhifənin "Satış" rejimində olub-olmadığını yoxlayırıq
    if (widget.isSale) {
      // Əgər satışdırsa, satış üçün olan funksiyanı çağırırıq
      await _submitSatis();
    } else {
      // Əgər satış DEYİLSƏ (yəni sifarişdir), sifariş üçün olan funksiyanı çağırırıq
      await _submitSifaris();
    }
  }



  Future<void> _submitSifaris() async {

    if (_submitting) return;

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Məhsul əlavə olunmayıb.')),
        );
      return;
    }
    if (_selectedCustomerId == null ||
        _selectedCashDeskId == null ||
        _selectedWarehouseId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Müştəri/Kassa/Anbar seçilməyib.')),
        );
      return;
    }
    if (_lines.any((e) => e.productId <= 0)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Məhsul id-si (idn) yoxdur.')),
        );
      return;
    }

    setState(() => _submitting = true);

    // ================== YENİ MƏNTİQİN BAŞLANĞICI ==================

    // 1. Redaktə rejimindəyiksə (widget.sened null deyil) true, əks halda false.
    final bool isEditing = widget.sened != null;

    // 2. Serverə göndəriləcək məlumatları (payload) hazırlayırıq.
    final payload = {
      // Redaktə rejimində sənədin ID-sini də göndəririk.
      if (isEditing)
      'idn': widget.sened!.idn,
      'date': _date.toIso8601String(),
      'customerId': _selectedCustomerId,
      'cashdeskId': _selectedCashDeskId,
      'warehouseId': _selectedWarehouseId,


      'userId': globalTermname,
      'payment': _paymentType == 'Nağd' ? 0 : 1,
      'note': _noteCtrl.text.trim(),
      'lines': _lines
          .map((e) =>
      {
        'idn': e.productId,
        'qty': e.qty,
        'qtysay': e.qtysay,
        'price': e.price,
        'qeyd': e.qeyd,
      })
          .toList(),
      'total': _total,
    };

    bool ok = false;
    try {
      final base = await _getBaseUrl();
      http.Response resp;

      // 3. Redaktə rejiminə görə uyğun sorğunu göndəririk.
      if (isEditing) {
        // ================== DÜZƏLİŞ (UPDATE) SORĞUSU ==================
        final senedId = widget.sened!.idn;
        final url = Uri.parse('$base/ss/$senedId'); // Məs: /sifaris/123

        print('Düzəliş sorğusu göndərilir: PUT $url');
        print('Payload: ${jsonEncode(payload)}');

        resp = await http
            .put( // HTTP PUT metodu ilə
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
            .timeout(const Duration(seconds: 45));
      } else {
        // ================== YENİ YARATMA (CREATE) SORĞUSU ==================
        final url = Uri.parse('$base/sifaris');

        print('Yeni sənəd sorğusu göndərilir: POST $url');
        print('Payload: ${jsonEncode(payload)}');

        resp = await http
            .post( // HTTP POST metodu ilə
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
            .timeout(const Duration(seconds: 45));
      }

      // 4. Serverdən gələn cavabı emal edirik.
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        await _clearDraft(); // Qaralamanı təmizlə
        if (!mounted) return;

        // Uğurlu əməliyyat mesajı
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
                content: Text(isEditing
                    ? 'Sifariş sənədində dəyişikliklər yadda saxlandı'
                    : 'Yeni sifariş sənədi təsdiqləndi')),
          );

        // Çap və ya PDF seçimlərini soruş
        final action = await _askPrintConfirmation();
        if (action == 'pdf') {
          await _createPdf();
        } else if (action == 'print') {
          _printReceiptDetached();
        }

        ok = true;
        Navigator.pop(
            context, true); // Geri qayıdırıq (true ilə nəticə qaytarırıq)
        return;
      } else {
        // Xəta mesajı
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(
                'Server xətası: ${resp.statusCode} — ${resp.body}')),
          );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Şəbəkə xətası: $e')),
        );
    }

    if (mounted) {
      setState(() => _submitting = false);
    }
  }




  // Yeni Satış yaratmaq üçün
  Future<void> _submitSatis() async {
    // Bu, sizin ikinci göndərdiyiniz _submit funksiyasıdır.
    // Heç bir dəyişiklik etmədən olduğu kimi bura köçürün.
    if (_submitting) return;

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Məhsul əlavə olunmayıb.')),
        );
      return;
    }
    if (_lines.any((e) => e.productId <= 0)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Məhsul id-si (idn) yoxdur.')),
        );
      return;
    }

    setState(() => _submitting = true);

    final payload = {
      'date1': _date.toIso8601String(),
      'date2': _date.toIso8601String(),
      'cixisanbari': _selectedWarehouseId,
      'girisanbari': _selectedWarehousecId,
      'telebnomresi': _telebnameNomresiCtrl.text ?? '',
      'sorgunomresi': int.tryParse(_sorguNomresiCtrl.text) ?? 0,
      'userId' : globalTermname,
      'note': _noteCtrl.text.trim(),
      'lines': _lines.map((e) => {
        'idn': e.productId,
        'qty': e.qty,
        'qtysay': e.qtysay,
        'price': e.price,
        'qeyd': e.qeyd,
      }).toList(),
      'total': _total,
    };

    try {
      final base = await _getBaseUrl();
      final resp = await http.post(
        Uri.parse('$base/malgonder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        await _clearDraft();
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Satış sənədi təsdiqləndi')));

        final action = await _askPrintConfirmation();
        if (action == 'pdf') await _createPdf();
        else if (action == 'print') _printReceiptDetached();

        Navigator.pop(context, true);
        return;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Xəta: ${resp.statusCode} — ${resp.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Şəbəkə xətası: $e')));
    }

    if (mounted) {
      setState(() => _submitting = false);
    }
  }





//// END_SIFARIS_DART_SUBMIT_CHANGE


  void _printReceiptDetached() {
    Future.microtask(() async {
      try {
        await _printReceipt();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Çap xətası: $e')),
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final canChangeDate = globalAllowDateChange;

    final String pageTitle = widget.isSale
        ? 'Malın göndərilməsi'
        : (widget.sened != null ? 'Malın göndərilməsi' : 'Malın göndərilməsi');

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle), // 2. Tə
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
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        children: [
                          // 1-ci sıra: Tarix + Ödəniş növü
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
                                // ANBAR ÜÇÜN YENİ AXTARIŞLI PİCKER
                                child: _SearchableLookupPicker(
                                  label: 'Çıxış anbarı',
                                  modalTitle: 'Anbar seçin',
                                  valueText: _warehouseNameById(_selectedWarehousecId), // Köməkçi funksiyadan istifadə
                                  items: _warehousesc,
                                  enabled: !_isDownloadingProducts, // Yüklənərkən deaktiv olsun
                                  onSelected: (item) {
                                    final id = item?.id;
                                    // Əgər seçim dəyişibsə, məhsulları yenidən yüklə
                                    if (id != null && id != _selectedWarehousecId) {
                                      setState(() => _selectedWarehousecId = id);
                                      _downloadMallar();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                // ANBAR ÜÇÜN YENİ AXTARIŞLI PİCKER
                                child: _SearchableLookupPicker(
                                  label: 'Giriş anbarı',
                                  modalTitle: 'Anbar seçin',
                                  valueText: _warehouseNameById(_selectedWarehouseId),
                                  items: _warehouses,
                                  enabled: !_isDownloadingProducts, // Yüklənərkən deaktiv olsun
                                  onSelected: (item) {
                                    final id = item?.id;
                                    // Əgər seçim dəyişibsə, məhsulları yenidən yüklə
                                    if (id != null && id != _selectedWarehouseId) {
                                      setState(() => _selectedWarehouseId = id);
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
                          //  5-ci sıra: Qeyd
                          // ... build() metodu içindəki Card-ın daxilində...

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 1-ci TextFormField Expanded ilə əhatə olunub
                              Expanded(
                                child: TextFormField(
                                  controller: _telebnameNomresiCtrl,
                                  readOnly: true, // Redaktəni bağlayır
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  decoration: InputDecoration(
                                    labelText: 'Tələbnamə sənədi',
                                    labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.grey.shade200, // Read-only olduğunu bildirmək üçün arxa fon
                                  ),
                                ),
                              ),
          if (_showSorguDetails) ...[

            const SizedBox(width: 8),
                              // 2-ci TextFormField Expanded ilə əhatə olunub

                              Expanded(

                                child: TextFormField(
                                  controller: _sorguNomresiCtrl,
                                  readOnly: true, // Redaktəni bağlayır
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  decoration: InputDecoration(
                                    labelText: 'Sorğu nömrəsi',
                                    labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.grey.shade200, // Read-only olduğunu bildirmək üçün arxa fon
                                  ),
                                ),
                              ),
                            ],

    ],
                          ),
  // Sahələr arasında boşluq
                          if (_showSorguDetails) ...[

                            const SizedBox(height: 8),
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

               ],

                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emekdasAdiCtrl,
                            readOnly: true, // Redaktəni bağlayır
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                            decoration: InputDecoration(
                              labelText: 'Əməkdaş',
                              labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade200, // Read-only olduğunu bildirmək üçün arxa fon
                            ),
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
                                // ---- YUXARIDAKI KODU BU KODLA ƏVƏZ EDİN ----

                                child: ListTile(
                                  // `title` parametrini Column ilə əvəz edirik
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 1. "Sifarişli" yazısı
                                      // Köhnə Text widget-ını bu yeni kodla əvəz edin
                                      // ListTile içərisindəki köhnə Text widget-ını bununla əvəz edin

                                      Builder(
                                        builder: (context) {
                                          // Funksiyanı çağırıb həm mətni, həm də rəngi alırıq
                                          final (text, color) = _buildSifarisTalebi(l);

                                          // Aldığımız məlumatlarla Text widget-ını qururuq
                                          return Text(
                                            text,
                                            style: TextStyle(
                                              color: color, // Rəngi dinamik olaraq təyin edirik
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          );
                                        },
                                      ),
                                      // 2. Məhsulun adı
                                      Text(l.name),
                                      // İki yazı arasında kiçik bir boşluq
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                  subtitle: Text(
                                        'Barkod: ${l.barcode}\n'
                                        'Miqdar: ${_fmt18_3(l.qty)} | ${l.unit}\n'
                                        'Qeyd: ${l.qeyd}\n'
                                        'Qutu sayı: $addCount',
                                  ),
                                  // `isThreeLine` artıq subtitle-ın uzunluğuna görə avtomatik tənzimlənəcək,
                                  // amma saxlamağın ziyanı yoxdur.
                                  isThreeLine: true,
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

                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const SizedBox(width: 6),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _submitting ? null : _submit,
                                  icon: _submitting
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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

class _HeaderTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _HeaderTile({
    super.key,
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
          fontSize: kGlobalBaseFontSize - 1,
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.event, size: 18, color: Colors.black87),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: kGlobalBaseFontSize,
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
  final dynamic selectedId;
  final List<LookupItem> items;
  final ValueChanged<dynamic?> onChanged;
  final bool enabled;
  final bool allowNull; // <-- YENİ PARAMETR

  const _HeaderDropdownGeneric({
    super.key,
    required this.label,
    required this.selectedId,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.allowNull = false, // <-- Defolt olaraq false
  });

  @override
  Widget build(BuildContext context) {
    // Əgər null-a icazə yoxdursa və ID siyahıda yoxdursa, onu null et
    final effectiveSelectedId = (allowNull == false &&
        selectedId != null &&
        items.every((item) => item.id != selectedId))
        ? null
        : selectedId;
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
          value: effectiveSelectedId,
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



// 🔎 Surucu üçün axtarışlı picker (bottom sheet ilə)
class _SurucuSearchPicker extends StatelessWidget {
  final String label;
  final String valueText; // göstərilən seçilmiş dəyər
  final List<LookupItem> items;
  final ValueChanged<LookupItem?> onSelected;

  // valueTextFontSize və labelFontSize parametrləri qaldı,
  // amma əgər təyin edilməsələr kGlobalBaseFontSize istifadə olunacaq.
  final double? valueTextFontSize;
  final double? labelFontSize;

  const _SurucuSearchPicker({
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
                      'Sürücü seç',
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


