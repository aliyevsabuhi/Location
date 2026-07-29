import 'dart:convert';
import 'package:aliyev_apk/malgonder.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart' show globalIp, globalPort, globalAllowDateChange, globalTermname,globalceki, globaleded;

final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
const double kGlobalBaseFontSize = 13.0;

class TelebnamesenedlerPage extends StatefulWidget {
  const TelebnamesenedlerPage({super.key});

  @override
  State<TelebnamesenedlerPage> createState() => _TelebnamesenedlerPageState();
}
int _boolToInt(dynamic value) {
  if (value == null) return 0;
  if (value is bool) return value ? 1 : 0;
  if (value is num) return value.toInt();
  return 0;
}
class _TelebnamesenedlerPageState extends State<TelebnamesenedlerPage> {
  bool _loading = true;
  String? _error;
  List<TelebHeader> _headers = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  TextEditingController _searchDocController = TextEditingController();
  TextEditingController _searchCustomerController = TextEditingController();
  List<TelebHeader> _filteredHeaders = [];

  BluetoothDevice? _printer;
  bool _btConnected = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadHeaders();
    _loadLookups();
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

  Future<void> _loadHeaders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final base = 'http://$globalIp:$globalPort';
    final url = Uri.parse(
        '$base/telebnamedoc?userId=$globalTermname&start=${DateFormat('yyyy-MM-dd').format(_startDate)}&end=${DateFormat('yyyy-MM-dd').format(_endDate)}');

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List;
        final items = list
            .map((e) => TelebHeader.fromMap(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _headers = items;
          _filteredHeaders = items; // axtarış üçün əsas siyahı
          _loading = false;
        });
      } else {
        setState(() {
          _error = "Xəta: ${resp.statusCode}";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Server xətası: $e";
        _loading = false;
      });
    }
  }

  Future<void> _loadLookups() async {
    try {
      final base = await _getBaseUrl();
      final response = await http
          .get(Uri.parse('$base/user?userId=$globalTermname'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) throw Exception('Lookup yüklənmə xətası');

      final userJson = jsonDecode(response.body) as List;
      setState(() {
        _username = userJson.isNotEmpty ? userJson.first['name'].toString() : null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<String> _getBaseUrl() async {
    if (globalIp == null || globalPort == null) {
      throw Exception('Server IP/Port təyin olunmayıb.');
    }
    String host =
    globalIp!.trim().replaceAll(RegExp(r'^https?://', caseSensitive: false), '');
    String port = globalPort!.toString().trim();
    if (host == '127.0.0.1' || host.toLowerCase() == 'localhost') host = '10.0.2.2';
    return 'http://$host:$port';
  }

  // ===================== TARİX SEÇİCİ =====================
  Widget _buildDateFilters() {
    final df = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: _HeaderTile(
              label: 'Başlanğıc',
              value: df.format(_startDate),
              onTap: _pickStartDate,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: _HeaderTile(
              label: 'Son',
              value: df.format(_endDate),
              onTap: _pickEndDate,
            ),
          ),
        ],
      ),
    );
  }

  void _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _loadHeaders();
      });
    }
  }

  void _filterList() {
    final docQuery = _searchDocController.text.toLowerCase();
    final customerQuery = _searchCustomerController.text.toLowerCase();

    setState(() {
      _filteredHeaders = _headers.where((h) {
        final docMatch = (h.documentNo ?? '').toLowerCase().contains(docQuery);
        final customerMatch = (h.layiheadi ?? '').toLowerCase().contains(customerQuery);
        return docMatch && customerMatch;
      }).toList();
    });
  }


  void _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _loadHeaders();
      });
    }
  }

  // ===================== SƏTİRLƏR TABLOSU =====================
  Widget _buildLinesTable(List<SatisLine> lines) {
    if (lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text("Sətir tapılmadı"),
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

  Widget _buildSearchFields() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchDocController,
              decoration: InputDecoration(
                labelText: 'Sənəd nömrəsi ilə axtar',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.numbers),
                isDense: true,
              ),
              onChanged: (_) => _filterList(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCustomerController,
              decoration: InputDecoration(
                labelText: 'Sorğu nömrəsi ilə axtar',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person_search),
                isDense: true,
              ),
              onChanged: (_) => _filterList(),
            ),
          ),
        ],

      ),


    );

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tələbnamə sənədləri")),
      body: Column(
        children: [


          _buildDateFilters(),
          _buildSearchFields(), // 🔍 yeni axtarış sahələri



          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
              onRefresh: _loadHeaders,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _filteredHeaders.length,
                itemBuilder: (ctx, i) {
                  final h = _filteredHeaders[i];
                  return Card(
                      color: _statusColor(h.status),
                  elevation: 2,
                  child: InkWell(
                /*  onTap: () {
                  Navigator.push(
                  context,
                  MaterialPageRoute(
                  builder: (_) => MalgonderPage(
                  telebId: h.idn,
                  documentNo: h.documentNo,
                  customerId: h.customer,
                  ),
                  ),
                  );
                  },*/
                    child: ExpansionTile(
                      title: Text(
                        "${h.documentNo ?? ''} — ${h.date != null ? DateFormat('dd.MM.yyyy').format(h.date!) : ''}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Əməkdaş: ${h.ekspeditor}"),
                          Text("Kontragent: ${h.customerName}"),
                          Text("Soğu nömrəsi: ${h.contract}"),
                          Text("Layihə: ${h.layiheadi}"),
                          Text("İşin təsviri: ${h.isintesviri}"),
                          Text("Təcili: ${h.urgent}"),
                          if (h.status == 0)
                            Text("Gözləmədə"),
                          if (h.status == 1)
                            Text("Ödənilib"),




                          if ((h.note ?? '').isNotEmpty)
                            Text("Anbar qeydi: ${h.note}"),
                          if ((h.note2 ?? '').isNotEmpty)
                            Text("Müştəri qeydi: ${h.note2}"),
                        ],
                      ),
                      children: [_buildLinesTable(h.lines)],
                    ),
                  ));

                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                    leading: const Icon(Icons.edit, color: Colors.blueAccent),
                    title: const Text("Düzəliş et"),
                    /*onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SifarisPage(sened: h)),
                      ).then((r) { if (r == true) _loadHeaders(); });
                    },*/
                  ),
                ),

              if (h.status == 0)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.add_shopping_cart, color: Colors.green),
                    title: const Text("Göndər"),
                   /* onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MalgonderPage(sened: h, isSale: true)),
                      ).then((r) { if (r == true) _loadHeaders(); });
                    },*/
                  ),
                ),

            ],
          ),
        );
      },
    );
  }


}

// ===================== KÖMƏKÇİ WIDGET =====================
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

// ===================== MODEL SİNİFLƏRİ =====================
class TelebHeader {
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
  final String? insUser;
  final DateTime? insDate;
  final String? updUser;
  final DateTime? updDate;
  final String? contractAdd;
  final int? depo;
  final int? expeditor;
  final String? note2;
  final String? urgent;
  final String? ekspeditor;
  final int? allContractors;
  final List<SatisLine> lines;

  TelebHeader({
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
    this.insUser,
    this.insDate,
    this.updUser,
    this.updDate,
    this.contractAdd,
    this.depo,
    this.expeditor,
    this.note2,
    this.urgent,
    this.ekspeditor,
    this.allContractors,
    this.lines = const [],
  });

  factory TelebHeader.fromMap(Map<String, dynamic> m) {
    List<SatisLine> parsedLines = [];
    if (m['lines'] != null) {
      final list = m['lines'] is String ? jsonDecode(m['lines']) : m['lines'];
      parsedLines = (list as List).map((e) => SatisLine.fromMap(e)).toList();
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

    return TelebHeader(
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
      contract: _toInt(m['initiation_name']),
      insUser: m['ins_user']?.toString(),
      insDate: _parseDate(m['ins_date']),
      updUser: m['upd_user']?.toString(),
      updDate: _parseDate(m['upd_date']),
      contractAdd: m['contract_add']?.toString(),
      depo: _toInt(m['depo']),
      expeditor: _toInt(m['expeditor']),
      note2: m['note2']?.toString(),
      urgent: m['urgentn']?.toString(),
      ekspeditor: m['ekspeditor']?.toString(),
      allContractors: _toInt(m['all_contractors']),
      lines: parsedLines,
    );
  }

}

class SatisLine {
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

  SatisLine({
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

  factory SatisLine.fromMap(Map<String, dynamic> m) => SatisLine(
    idn: m['idn'] as int?,
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
