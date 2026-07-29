import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Fayl əməliyyatları üçün
import 'package:aliyev_apk/malingonderilmesi.dart';
import 'package:aliyev_apk/sifaris.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Font üçün
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'main.dart' show globalIp, globalPort, globalTermname, globalUsername;

// ==== YENİ İMPORTLAR ====
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
// =========================

// Köməkçi vidcet və sabitləri yuxarıya çıxarırıq
const double kGlobalBaseFontSize = 13.0;

// ... (TelebnameHeader və SifarisLine sinifləri olduğu kimi qalır)
class TelebnameHeader {
  final int idn;
  final String? documentNo;
  final DateTime? date;
  final DateTime? telebdate;
  final int? customer;
  final String? customerName;
  final String? layiheadi;
  final String? isintesviri;
  final double? discount;
  final double? discountAmount;
  final double? amount;
  final double? summary;
  final double? totalSum;
  final double? nationalCurrencySum;
  final int? docConfirm;
  final int? reqkind;
  final String? note;
  final DateTime? salesDate;
  final int? status;
  final double? quantity;
  final double? salesQuantity;
  final double? balanceQuantity;
  final double? returnedQuantity;
  final String? currency;
  final double? rate;
  final int? vatRate;
  final int? vatIncluded;
  final double? vatPercent;
  final double? vatAmount;
  final double? discountTotal;
  final int? contract;
  final String? contractadi;
  final String? insUser;
  final DateTime? insDate;
  final String? updUser;
  final DateTime? updDate;
  final String? contractAdd;
  final int? depo;
  final String? depoadi;
  final int? expeditor;
  final String? note2;
  final String? urgent;
  final String? ekspeditor;
  final int? allContractors;
  final List<SifarisLine> lines;

  TelebnameHeader({
    required this.idn,
    this.documentNo,
    this.date,
    this.telebdate,
    this.customer,
    this.customerName,
    this.layiheadi,
    this.isintesviri,
    this.discount,
    this.discountAmount,
    this.amount,
    this.summary,
    this.totalSum,
    this.nationalCurrencySum,
    this.docConfirm,
    this.reqkind,
    this.note,
    this.salesDate,
    this.status,
    this.quantity,
    this.salesQuantity,
    this.balanceQuantity,
    this.returnedQuantity,
    this.currency,
    this.rate,
    this.vatRate,
    this.vatIncluded,
    this.vatPercent,
    this.vatAmount,
    this.discountTotal,
    this.contract,
    this.contractadi,
    this.insUser,
    this.insDate,
    this.updUser,
    this.updDate,
    this.contractAdd,
    this.depo,
    this.depoadi,
    this.expeditor,
    this.note2,
    this.urgent,
    this.ekspeditor,
    this.allContractors,
    this.lines = const [],
  });

  factory TelebnameHeader.fromMap(Map<String, dynamic> m) {
    int? toInt(dynamic v) => (v == null) ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));
    double? toDouble(dynamic v) => (v == null) ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

    List<SifarisLine> parsedLines = [];
    if (m['lines'] != null) {
      try {
        final list = m['lines'] is String ? jsonDecode(m['lines']) : m['lines'];
        if (list is List) {
          parsedLines = list.map((e) => SifarisLine.fromMap(e as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        print("Sətirləri (lines) parse edərkən xəta: $e");
      }
    }

    int _boolToInt(dynamic value) {
      if (value == null) return 0;
      if (value is bool) return value ? 1 : 0;
      if (value is num) return value.toInt();
      return 0;
    }

    DateTime? _parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    int? _toInt(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v ? 1 : 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return TelebnameHeader(
      idn: _toInt(m['idn']) ?? 0,
      documentNo: m['document_no']?.toString(),
      date: _parseDate(m['date']),
      telebdate: _parseDate(m['requisition_date']),
      customer: _toInt(m['customer']),
      customerName: m['contractor_name']?.toString(),
      layiheadi: m['layiheadi']?.toString(),
      isintesviri: m['isintesviri']?.toString(),
      discount: _toDouble(m['discount']),
      discountAmount: _toDouble(m['discount_amount']),
      amount: _toDouble(m['amount']),
      summary: _toDouble(m['summary']),
      totalSum: _toDouble(m['total_sum']),
      nationalCurrencySum: _toDouble(m['national_currency_sum']),
      docConfirm: _toInt(m['doc_confirm']),
      reqkind: _toInt(m['req_kind']),
      note: m['note']?.toString(),
      salesDate: _parseDate(m['sales_date']),
      status: _boolToInt(m['status']),
      quantity: _toDouble(m['quantity']),
      salesQuantity: _toDouble(m['sales_quantity']),
      balanceQuantity: _toDouble(m['balance_quantity']),
      returnedQuantity: _toDouble(m['returned_quantity']),
      currency: m['currency']?.toString(),
      rate: _toDouble(m['rate']),
      vatRate: _toInt(m['vat_rate']),
      vatIncluded: _toInt(m['vat_included']),
      vatPercent: _toDouble(m['vat_percent']),
      vatAmount: _toDouble(m['vat_amount']),
      discountTotal: _toDouble(m['discount_total']),
      contract: _toInt(m['initiation']),
      contractadi: m['initiation_name'].toString(),
      insUser: m['ins_user']?.toString(),
      insDate: _parseDate(m['ins_date']),
      updUser: m['upd_user']?.toString(),
      updDate: _parseDate(m['upd_date']),
      contractAdd: m['contract_add']?.toString(),
      depo: _toInt(m['depo']),
      depoadi: m['depoadi']?.toString(),
      expeditor: _toInt(m['expeditor']),
      note2: m['note2']?.toString(),
      urgent: m['urgentn']?.toString(),
      ekspeditor: m['ekspeditor']?.toString(),
      allContractors: _toInt(m['all_contractors']),
      lines: parsedLines,
    );
  }
}
class SifarisLine {
  final int? idn;
  final int? fkProductSaleOrder;
  final String? code;
  final String? barcode;
  final double? quantity;
  final double? quantity_given;
  final double? cancel_quantity;
  final double? discountm;
  final double? discount;
  final double? amount;
  final double? vatPercent;
  final double? vatAmount;
  final double? summary;
  final String? malName;
  final String? vahid;
  final String? tip;
  final String? marka;

  SifarisLine({
    this.idn,
    this.fkProductSaleOrder,
    this.code,
    this.barcode,
    this.quantity,
    this.quantity_given,
    this.cancel_quantity,
    this.discountm,
    this.discount,
    this.amount,
    this.vatPercent,
    this.vatAmount,
    this.summary,
    this.malName,
    this.vahid,
    this.tip,
    this.marka,
  });

  factory SifarisLine.fromMap(Map<String, dynamic> m) {
    double? toDouble(dynamic v) => (v == null) ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    int? toInt(dynamic v) => (v == null) ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

    return SifarisLine(
      idn: m['product'] as int?,
      fkProductSaleOrder: m['fk_product_sale_order'] as int?,
      code: m['code']?.toString(),
      barcode: m['barcode']?.toString(),
      quantity: (m['quantity'] as num?)?.toDouble(),
      quantity_given: (m['quantity_given'] as num?)?.toDouble(),
      discount: (m['discount'] as num?)?.toDouble(),
      amount: (m['amount'] as num?)?.toDouble(),
      vatPercent: (m['vat_percent'] as num?)?.toDouble(),
      vatAmount: (m['vat_amount'] as num?)?.toDouble(),
      summary: (m['summary'] as num?)?.toDouble(),
      malName: m['mal_name']?.toString(),
      cancel_quantity: (m['cancel_quantity'] as num?)?.toDouble(),
      discountm: (m['discount'] as num?)?.toDouble(),
      vahid: m['vahid']?.toString(),
      tip: m['tip']?.toString(),
      marka: m['marka']?.toString(),
    );
  }
}


// ===================== ƏSAS SƏHİFƏ =====================

class TelebnamelerPage extends StatefulWidget {
  const TelebnamelerPage({super.key});

  @override
  State<TelebnamelerPage> createState() => _TelebnamelerPageState();
}

class _TelebnamelerPageState extends State<TelebnamelerPage> {
  bool _loading = true;
  String? _error;
  List<TelebnameHeader> _headers = [];
  bool _isSharing = false; // Paylaşma zamanı loading üçün

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  DateTime _startDate = DateTime.now().add(const Duration(days: 0));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));


  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  Future<String> _getBaseUrl() async {
    if (globalIp == null || globalPort == null) {
      throw Exception('Server IP/Port təyin olunmayıb.');
    }
    String host = globalIp!.trim().replaceAll(RegExp(r'^https?://'), '');
    String port = globalPort!.toString().trim();
    if (host == '127.0.0.1' || host.toLowerCase() == 'localhost') {
      host = '10.0.2.2';
    }
    return 'http://$host:$port';
  }

// Bu funksiyanı State class-ınızın daxilinə əlavə edin
  Future<void> _cancelDocument(int documentId) async {
    // Bu hissədə loading indicator göstərə bilərsiniz
    // setState(() => _isLoading = true);

    // Ləğv etmək üçün API endpoint-ini öz kodunuza uyğun dəyişin
    final url = Uri.parse('http://$globalIp:$globalPort/cancelsifaris');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'idn': documentId}),
      );

      if (response.statusCode == 200) {
        // Uğurlu olarsa, siyahını yenilə
        _loadHeaders();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sənəd uğurla ləğv edildi."), backgroundColor: Colors.green),
        );
      } else {
        // Xəta baş verərsə
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xəta baş verdi: ${response.body}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Şəbəkə və ya digər xətalar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Server xətası: $e"), backgroundColor: Colors.red),
      );
    } finally {
      // Loading indicator-u gizlədin
      // setState(() => _isLoading = false);
    }
  }

// Bu funksiyanı da State class-ınızın içinə əlavə edin
  void _showCancelConfirmationDialog(TelebnameHeader sened) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Təsdiq"),
          content: const Text("Bu sənədi ləğv etməyə əminsiniz?"),
          actions: <Widget>[
            // "Xeyr" düyməsi - sadəcə dialoqu bağlayır
            TextButton(
              child: const Text("Xeyr"),
              onPressed: () {
                Navigator.of(ctx).pop(); // Dialoqu bağla
              },
            ),
            // "Bəli" düyməsi - ləğv etmə funksiyasını çağırır
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Bəli, Ləğv et"),
              onPressed: () {
                Navigator.of(ctx).pop(); // Əvvəlcə dialoqu bağla
                _cancelDocument(sened.idn); // Sonra API sorğusunu göndər
              },
            ),
          ],
        );
      },
    );
  }


  // ==== AXTARIŞI SERVERƏ GÖNDƏRƏN FUNKSİYA ====
  Future<void> _loadHeaders() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final base = await _getBaseUrl();
      // URL-i dinamik olaraq qururuq
      var urlString = '$base/telebnamedoc?userId=$globalTermname&start=${DateFormat('yyyy-MM-dd').format(_startDate)}&end=${DateFormat('yyyy-MM-dd').format(_endDate)}';

      // ==========================================================
      // ==== DÜZƏLİŞ BURADADIR: Axtarış mətni serverə göndərilir ====
      // ==========================================================

      final query = _searchCtrl.text.trim();
      if (query.isNotEmpty) {
        urlString += '&searchQuery=${Uri.encodeComponent(query)}';
      }

      final url = Uri.parse(urlString);
      print("Sorğu göndərilir: $url"); // Test üçün URL-i konsola yazdır

      final resp = await http.get(url).timeout(const Duration(seconds: 45));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final list = json.decode(utf8.decode(resp.bodyBytes)) as List;
        final items = list.map((e) => TelebnameHeader.fromMap(e as Map<String, dynamic>)).toList();
        setState(() {
          _headers = items;
        });
      } else {
        setState(() {
          _error = "Server cavabı: ${resp.statusCode}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Şəbəkə xətası: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ================================================================
  //                YENİ PDF YARATMA VƏ PAYLAŞMA FUNKSİYASI
  // ================================================================
  Future<void> _createAndSharePdf(TelebnameHeader sened) async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      final pdf = pw.Document();
      final ttf = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
      final font = pw.Font.ttf(ttf);

      //final total = sened.lines.fold<double>(0.0, (sum, line) => sum + (line.qiymet ?? 0) * (line.miqdar ?? 0));





      String borcValue = "0.00 AZN";
      String customerNameToDisplay = sened.customerName ?? ""; // Müştəri adının ilkin dəyəri

      // 1. Müştəri adının boş olmadığını və sonunda "AZN" olduğunu yoxlayırıq
      if (sened.customerName != null && sened.customerName!.endsWith(" AZN")) {
        // 2. Sətri boşluqlara görə bölürük
        final parts = sened.customerName!.split(' ');

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


      // PDF-i fayl kimi yaddaşa yazırıq
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/sifaris_${sened.documentNo ?? sened.idn}.pdf");
      await file.writeAsBytes(await pdf.save());

      // Paylaşma menyusunu açırıq
      await Share.shareXFiles([XFile(file.path)], text: 'Sifariş Sənədi ${sened.documentNo}');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF paylaşarkən xəta: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }


  Color _statusColor(int? status) {
    switch (status) {
      case 0:
        return Colors.red.shade200; // Satilib
      case 1:
        return Colors.lightGreen; // Yari satilib
      case 2:
        return Colors.yellow; // Satilmayib
      case 3:
        return Colors.red.shade200; // Artiq satilib
      case 4:
        return Colors.redAccent; // Ləğv edilib
      default:
        return Colors.white; // Naməlum
    }
  }

  // ==== Axtarış mətnini "debounce" ilə idarə edən funksiya ====
  void _onSearchChanged(String query) {
    // Əgər əvvəlki taymer aktivdirsə, onu ləğv edirik
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Yeni bir taymer qururuq. İstifadəçi yazmağı dayandırdıqdan 500ms sonra işə düşəcək.
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Yalnız taymer bitəndən sonra _loadHeaders funksiyasını çağırırıq
      _loadHeaders();
    });
  }


  // Filtrləri göstərən Widget
  Widget _buildFilters() {
    final df = DateFormat('yyyy-MM-dd');
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _HeaderTile(label: 'Başlanğıc', value: df.format(_startDate), onTap: _pickStartDate)),
              const SizedBox(width: 8),
              Expanded(child: _HeaderTile(label: 'Son', value: df.format(_endDate), onTap: _pickEndDate)),
            ],
          ),
          const SizedBox(height: 8),
          // Müştəri axtarış filteri (TextField ilə)
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              labelText: 'Müştəri adı',
              hintText: 'Axtar...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              // Mətn sahəsini təmizləmək üçün 'X' düyməsi
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  _onSearchChanged(''); // Sorğunu dərhal təmizləyib yeniləyir
                },
              )
                  : null,
            ),
          ),
        ],
      ),
    );
  }


  void _pickStartDate() async {
    // ... (funksiya olduğu kimi qalır)
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _loadHeaders();
    }
  }

  void _pickEndDate() async {
    // ... (funksiya olduğu kimi qalır)
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _loadHeaders();
    }
  }

  Widget _buildLinesTable(List<SifarisLine> lines) {
    // ... (funksiya olduğu kimi qalır)
    if (lines.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text("Bu sənəd üçün sətir tapılmadı."))
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Kod")),
          DataColumn(label: Text("Məhsul")),
          DataColumn(label: Text("Vahid")),
          DataColumn(label: Text("Miqdar")),
          DataColumn(label: Text("Göndərilən miqdar")),
          DataColumn(label: Text("Ləğv miqdarı")),
        ],
        rows: lines.map((e) {
          // === ƏSAS DÜZƏLİŞ BURADADIR ===
          // Null ola biləcək dəyərlər üçün defolt olaraq 0 istifadə edirik


          return DataRow(
            cells: [
              DataCell(Text(e.code ?? '')),
              DataCell(Text(e.malName ?? '')),
              DataCell(Text(e.vahid ?? '')),
              DataCell(Text((e.quantity ?? 0).toStringAsFixed(2))),
              DataCell(Text((e.quantity_given ?? 0).toStringAsFixed(2))),
              DataCell(Text((e.cancel_quantity ?? 0).toStringAsFixed(2))),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tələbnamə sənədləri")),
      body: Stack( // Stack əlavə edirik ki, loading göstərə bilək
        children: [
          Column(
            children: [
              _buildFilters(),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                  onRefresh: _loadHeaders,
                  child: _headers.isEmpty
                      ? const Center(child: Text("Göstərilən tarix aralığında sənəd tapılmadı."))
                      : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _headers.length,
                    // ListView.builder içindəki itemBuilder-i bununla əvəz edin
                    itemBuilder: (ctx, i) {
                      final h = _headers[i];

                      return Card(
                        color: _statusColor(h.status),
                        elevation: 2,
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          childrenPadding: const EdgeInsets.only(bottom: 8),

                          // Başlıq
                          title: Text(
                            "${h.documentNo ?? ''} — ${DateFormat('dd.MM.yyyy').format(h.date!)}\n"
                                "Tələb olunan tarix — ${DateFormat('dd.MM.yyyy').format(h.telebdate!)}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),

                          // SubTitle (müştəri, satıcı, məbləğ...)
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((h.ekspeditor ?? '').isNotEmpty)
                                Text("Əməkdaş: ${h.ekspeditor}"),
                                if ((h.customerName ?? '').isNotEmpty)
                                Text("Kontragent: ${h.customerName}"),
                                if ((h.depoadi ?? '').isNotEmpty)
                                Text("Tələb olunan anbar: ${h.depoadi}"),
                                if ((h.contractadi ?? '').isNotEmpty)
                                Text("Sorğu: ${h.contractadi}"),
                                if ((h.layiheadi ?? '').isNotEmpty)
                                Text("Layihə: ${h.layiheadi}"),
                                if ((h.isintesviri ?? '').isNotEmpty)
                                Text("İşin təsviri: ${h.isintesviri}"),
                                if ((h.urgent ?? '').isNotEmpty)
                                Text("Təcili: ${h.urgent}"),
                                if (h.status == 0)
                                  Text("Gözləmədə"),
                                if (h.status == 1)
                                  Text("Ödənilib"),
                                if (h.status == 2)
                                  Text("Yarı ödənilib"),
                                if (h.status == 3)
                                  Text("Ləğv olunub"),
                                if (h.status == 4)
                                  Text("Artıq alınıb"),],

                            ),
                          ),

                          // SAĞ TƏRƏFDƏ ACTION DÜYMƏSİ
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert, color: Colors.black),
                            onPressed: () {
                              _showBottomActions(context, h);
                            },
                          ),

                          // AÇILAN HİSSƏ
                          children: [
                            Container(
                              color: Colors.white, // AĞ ARXAPLAN (sənin istədiyin kimi)
                              child: Column(
                                children: [
                                  const Divider(height: 1),
                                  _buildLinesTable(h.lines),
                                  const Divider(height: 1),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          // Paylaşma prosesi gedərkən göstəriləcək loading indicator
          if (_isSharing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("PDF hazırlanır...", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }


  void _showBottomActions(BuildContext context, dynamic h) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.4), // Şəffaf qaranlıq fon
      isScrollControlled: false,
      barrierColor: Colors.black54, // daha yumşaq overlay

      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white, // Alt panel ağ
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              // Üstdə dartmaq üçün indikator (estetik)
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 14),

              // Başlıq

              const Text(
                "Əməliyyatlar",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // LIST ITEMS – ripple effekti ilə

              if (h.status == 0)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.send, color: Colors.green),
                    title: const Text("Göndər"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MalingonderilmesiPage(sened: h, isSale: true)),
                      ).then((r) { if (r == true) _loadHeaders(); });
                    },
                  ),
                ),

              if (h.status == 2)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.send, color: Colors.green),
                    title: const Text("Göndər"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MalingonderilmesiPage(sened: h, isSale: false)),
                      ).then((r) { if (r == true) _loadHeaders(); });
                    },
                  ),
                ),

/*
              if (h.status == 0)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.cancel, color: Colors.red),
                    title: const Text("Ləğv et"),
                    onTap: () {
                      Navigator.pop(context);
                      _showCancelConfirmationDialog(h);
                    },
                  ),
                ),

              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.share, color: Colors.teal),
                  title: const Text("Paylaş (PDF)"),
                  onTap: () {
                    Navigator.pop(context);
                    _createAndSharePdf(h);
                  },
                ),
              ),
              */
            ],
          ),
        );
      },
    );
  }


}

// _HeaderTile vidceti olduğu kimi qalır...
class _HeaderTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _HeaderTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: kGlobalBaseFontSize - 1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.event, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}