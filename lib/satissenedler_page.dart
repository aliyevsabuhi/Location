import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import 'main.dart' show globalIp, globalPort, globalAllowDateChange, globalTermname,globalceki, globaleded;

final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
const double kGlobalBaseFontSize = 13.0;

class SatisSenedlerPage extends StatefulWidget {
  const SatisSenedlerPage({super.key});

  @override
  State<SatisSenedlerPage> createState() => _SatisSenedlerPageState();
}
int _boolToInt(dynamic value) {
  if (value == null) return 0;
  if (value is bool) return value ? 1 : 0;
  if (value is num) return value.toInt();
  return 0;
}
class _SatisSenedlerPageState extends State<SatisSenedlerPage> {
  bool _loading = true;
  String? _error;
  List<SatisHeader> _headers = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();


  bool _isSharing = false; // Paylaşma zamanı loading üçün

  TextEditingController _searchDocController = TextEditingController();
  TextEditingController _searchCustomerController = TextEditingController();
  List<SatisHeader> _filteredHeaders = [];

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
        return Colors.lightGreen; // Satilib
      case 1:
        return Colors.lightBlue.shade100; // Yari satilib
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

  // ===================== DATA YÜKLƏNMƏ =====================
  Future<void> _loadHeaders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final base = 'http://$globalIp:$globalPort';
    final url = Uri.parse(
        '$base/satisdoc?userId=$globalTermname&start=${DateFormat('yyyy-MM-dd').format(_startDate)}&end=${DateFormat('yyyy-MM-dd').format(_endDate)}');


    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List;
        final items =
        list.map((e) => SatisHeader.fromMap(e as Map<String, dynamic>)).toList();
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


  String _pdfStatusText(int status) {
    switch (status) {
      case 0:
        return "Satılıb";
      case 1:
        return "Yarı satılıb";
      case 2:
        return "Satılmayıb";
      case 3:
        return "Artıq satılıb";
      case 4:
        return "Ləğv edilib";
      default:
        return "-";
    }
  }

  void _filterList() {
    final docQuery = _searchDocController.text.toLowerCase();
    final customerQuery = _searchCustomerController.text.toLowerCase();

    setState(() {
      _filteredHeaders = _headers.where((h) {
        final docMatch = (h.documentNo ?? '').toLowerCase().contains(docQuery);
        final customerMatch = (h.customerName ?? '').toLowerCase().contains(customerQuery);
        return docMatch && customerMatch;
      }).toList();
    });
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
            ],
          ),
        );
      },
    );
  }

  pw.Widget _underlinedRow(String label, String value, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("$label $value", style: pw.TextStyle(font: font, fontSize: 10)),
        pw.SizedBox(height: 1), // Mətnlə xətt arasında azca məsafə
        pw.Container(
          height: 0.5, // Xəttin qalınlığı
          color: PdfColors.black,
          width: double.infinity, // Səhifənin sonuna qədər uzanması üçün
        ),
        pw.SizedBox(height: 6), // Növbəti sətirə qədər olan boşluq
      ],
    );
  }
  Future<void> _createAndSharePdf(SatisHeader sened) async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      final pdf = pw.Document();
      final ttf = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
      final font = pw.Font.ttf(ttf);
      final boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSans-Bold.ttf"));

      // Müştəri adı və borc məntiqi (sizin mövcud koddan)
      String customerNameToDisplay = sened.customerName ?? "";
      if (sened.customerName != null && sened.customerName!.endsWith(" AZN")) {
        final parts = sened.customerName!.split(' ');
        if (parts.length >= 2) {
          customerNameToDisplay = parts.sublist(0, parts.length - 2).join(' ');
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                /// 1. TƏSDİQ EDİRƏM HİSSƏSİ (Üst 2 blok)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Sol Tərəf - Təhvil verən
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Təsdiq edirəm:             ", style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text("Təhvil verən adından       ", style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text("Pro Con izo MMC            ", style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text("Şahbazov Babaxan           ", style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.SizedBox(height: 10),
                        pw.Text("M.Y./İmza _________________", style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                    // Sağ Tərəf - Təhvil alan
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Təsdiq edirəm:              ", style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text("Təhvil alan adından         ", style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text(customerNameToDisplay, style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text(sened.director ?? "", style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.SizedBox(height: 10),
                        pw.Text("M.Y./İmza __________________", style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 25),

                /// 2. AKT NO VƏ TARİX
                pw.Center(
                  child: pw.Text(
                    "MALLARIN TƏHVİL-TƏSLİM AKTI No: ${sened.documentNo ?? ""}",
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                  ),
                ),
                pw.Center(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("Sifariş No: ${sened.order_idn ?? ""}", style: pw.TextStyle(font: boldFont, fontSize: 10)),
                      pw.Text(
                        DateFormat("dd.MM.yyyy").format(sened.date ?? DateTime.now()),
                        style: pw.TextStyle(font: boldFont, fontSize: 10),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                /// 3. MƏLUMATLAR (Yer, Alan, Verən)
                // Məlumat hissəsi
                _underlinedRow("Malların qəbul edildiyi yer (anbar, ticarət obyekti):", customerNameToDisplay, font),
                _underlinedRow("Təhvil alan:",  " ${sened.director ?? "       "} (müəssisənin, idarənin və təşkilatın adı)", font),
                _underlinedRow("Təhvil verən:", "Pro Con izo MMC Şahbazov Babaxan (müəssisənin, idarənin və təşkilatın adı)", font),
                _underlinedRow("Satış təmsilçisi:", sened.ekspeditor ?? "    ", font),
                _underlinedRow("Aktın tərtib edilməsinə əsas:", "${sened.muqavileadi ?? ""}", font),
                _underlinedRow("Mal və material:", "Tikinti materialları", font),
                _underlinedRow("Anbar:", sened.depoadi ?? "", font),
                _underlinedRow("Qeyd:", sened.note ?? "", font),

                pw.SizedBox(height: 15),

                /// 4. CƏDVƏL (Şablona uyğun başlıqlar)
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30), // №
                    1: const pw.FlexColumnWidth(4),   // Adı
                    2: const pw.FlexColumnWidth(1.5), // Ədəd Ölçü vahidi
                    3: const pw.FlexColumnWidth(1.5), // Miqdarı
                  },
                  children: [
                    // Cədvəl Başlığı
                    pw.TableRow(
                      children: [
                        _tableCell("№", font, isHeader: true),
                        _tableCell("Adı", font, isHeader: true),
                        _tableCell("Ölçü vahidi", font, isHeader: true),
                        _tableCell("Miqdarı", font, isHeader: true),
                      ],
                    ),
                    // Cədvəl Sətirləri
                    ...List.generate(sened.lines.length, (index) {
                      final e = sened.lines[index];
                      return pw.TableRow(
                        children: [
                          _tableCell("${index + 1}", font),
                          _tableCell(e.malName ?? "", font, alignLeft: true),
                          _tableCell(e.vahid ?? "", font),
                          _tableCell((e.quantity ?? 0).toStringAsFixed(2), font),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 40),

                /// 5. ALT İMZALAR
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _signatureLine("Təhvil verdim:  ", sened.res_person ?? "", font),
                    pw.SizedBox(height: 15),
                    _signatureLine("Təhvil aldım:       ", sened.dasima ?? "", font),
                    pw.SizedBox(height: 15),
                    _signatureLine("Təhvil aldım:", "", font), // Boş üçüncü şəxs üçün
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Fayl saxlama və paylaşma (sizin mövcud koddan)
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/təhvil_təslim_aktı_${sened.documentNo}.pdf");
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Təhvil-Təslim Aktı No: ${sened.documentNo}');

    } catch (e) {
      debugPrint("Xəta: $e");
    } finally {
      setState(() => _isSharing = false);
    }
  }

  /// Cədvəl xanaları üçün köməkçi funksiya
  pw.Widget _tableCell(String text, pw.Font font, {bool isHeader = false, bool alignLeft = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(
            font: font,
            fontSize: 9,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal
        ),
      ),
    );
  }

  /// İmza sətirləri üçün köməkçi funksiya
  pw.Widget _signatureLine(String label, String name, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text("$label ", style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Text(name, style: pw.TextStyle(font: font, fontSize: 10, decoration: pw.TextDecoration.underline)),
            pw.Spacer(),
            pw.Text("____________________", style: pw.TextStyle(font: font)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 80),
              child: pw.Text("(vəzifəsi, soyadı, adı, atasının adı)", style: pw.TextStyle(font: font, fontSize: 7)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 20),
              child: pw.Text("(imza və tarix)", style: pw.TextStyle(font: font, fontSize: 7)),
            ),
          ],
        ),
      ],
    );
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
          DataColumn(label: Text("Barkod")),
          DataColumn(label: Text("Vahid")),
          DataColumn(label: Text("Miqdar")),
          DataColumn(label: Text("Qiymət")),
          DataColumn(label: Text("Endirim AZN")),
          DataColumn(label: Text("Endirim %")),
          DataColumn(label: Text("Məbləğ")),
          DataColumn(label: Text("ƏDV")),
          DataColumn(label: Text("Cəmi")),
        ],
        rows: lines.map((e) {
          return DataRow(
            cells: [
              DataCell(Text(e.code ?? '')),
              DataCell(Text(e.malName ?? '')),
              DataCell(Text(e.barcode ?? '')),
              DataCell(Text(e.vahid ?? '')),
              DataCell(Text((e.quantity ?? 0).toStringAsFixed(2))),
              DataCell(Text((e.price ?? 0).toStringAsFixed(2))),
              DataCell(Text((e.disc_totalm ?? 0).toStringAsFixed(2))),
              DataCell(Text((e.discountm ?? 0).toStringAsFixed(2))),
              DataCell(Text((e.amount ?? 0).toStringAsFixed(2))),
              DataCell(Text((e.vatAmount ?? 0).toStringAsFixed(2))),
              DataCell(Text((e.summary ?? 0).toStringAsFixed(2))),
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
                labelText: 'Müştəri adı ilə axtar',
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
      appBar: AppBar(title: const Text("Satış sənədləri")),
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
                    child: ExpansionTile(
                      title: Text(
                        "${h.documentNo ?? ''} — ${h.date != null ? DateFormat('dd.MM.yyyy').format(h.date!) : ''}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Sifariş sənədi: ${h.contractAdd}"),
                          if ((h.customerName ?? '').isNotEmpty)
                          Text("Alıcı: ${h.customerName}"),
                          Text("Əməkdaş: ${h.ekspeditor}"),
                          Text("Məbləğ: ${(h.amount ?? 0).toStringAsFixed(2)} ${h.currency ?? ''}"),
                          Text("ƏDV: ${(h.vatAmount ?? 0).toStringAsFixed(2)} ${h.currency ?? ''}"),
                          Text("Yekun: ${(h.totalSum ?? 0).toStringAsFixed(2)} ${h.currency ?? ''}"),
                          if (h.status == 0)
                            Text("Satılıb"),
                          if (h.status == 1)
                            Text("Yarı satılıb"),
                          if (h.status == 2)
                            Text("Satılmayıb"),
                          if (h.status == 3)
                            Text("Artıq satılıb"),
                          if (h.status == 4)
                            Text("Ləğv edilib"),



                          if ((h.note ?? '').isNotEmpty)
                            Text("Anbar qeydi: ${h.note}"),
                          if ((h.note2 ?? '').isNotEmpty)
                            Text("Müştəri qeydi: ${h.note2}"),
                        ],
                      ),
                      children: [_buildLinesTable(h.lines)],
                      // SAĞ TƏRƏFDƏ ACTION DÜYMƏSİ
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.black),
                        onPressed: () {
                          _showBottomActions(context, h);
                        },
                      ),
                    ),
                  );

                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
              ),
            ),
          ),
        ],
      ),
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
class SatisHeader {
  final int idn;
  final String? documentNo;
  final String? order_idn;
  final DateTime? date;
  final int? customer;
  final String? director;
  final String? customerName;
  final double? discount;
  final double? discountAmount;
  final double? amount;
  final double? summary;
  final double? totalSum;
  final double? nationalCurrencySum;
  final int? docConfirm;
  final String? note;
  final String? res_person;
  final String? muqavileadi;
  final String? dasima;
  final String? depoadi;
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
  final int? urgent;
  final String? ekspeditor;
  final int? allContractors;
  final List<SatisLine> lines;

  SatisHeader({
    required this.idn,
    this.documentNo,
    this.order_idn,
    this.date,
    this.customer,
    this.director,
    this.customerName,
    this.discount,
    this.discountAmount,
    this.amount,
    this.summary,
    this.totalSum,
    this.nationalCurrencySum,
    this.docConfirm,
    this.note,
    this.res_person,
    this.muqavileadi,
    this.dasima,
    this.depoadi,
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

  factory SatisHeader.fromMap(Map<String, dynamic> m) {
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

    return SatisHeader(
      idn: _toInt(m['idn']) ?? 0,
      documentNo: m['document_no']?.toString(),
      order_idn: m['order_idn']?.toString(),
      date: _parseDate(m['date']),
      customer: _toInt(m['customer']),
      director: m['director']?.toString(),
      customerName: m['customer_name']?.toString(),
      discount: _toDouble(m['discount']),
      discountAmount: _toDouble(m['discount_amount']),
      amount: _toDouble(m['amount']),
      summary: _toDouble(m['summary']),
      totalSum: _toDouble(m['total_sum']),
      nationalCurrencySum: _toDouble(m['national_currency_sum']),
      docConfirm: _toInt(m['doc_confirm']),
      note: m['note']?.toString(),
      res_person: m['res_person']?.toString(),
      muqavileadi: m['muqavileadi']?.toString(),
      dasima: m['dasima']?.toString(),
      depoadi: m['depoadi']?.toString(),
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
      contract: _toInt(m['contract']),
      insUser: m['ins_user']?.toString(),
      insDate: _parseDate(m['ins_date']),
      updUser: m['upd_user']?.toString(),
      updDate: _parseDate(m['upd_date']),
      contractAdd: m['order_idn']?.toString(),
      depo: _toInt(m['depo']),
      expeditor: _toInt(m['expeditor']),
      note2: m['note2']?.toString(),
      urgent: _toInt(m['urgent']),
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
  final double? price;
  final double? disc_totalm;
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
    this.price,
    this.disc_totalm,
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
    price: (m['price'] as num?)?.toDouble(),
    discount: (m['discount'] as num?)?.toDouble(),
    amount: (m['amount'] as num?)?.toDouble(),
    vatPercent: (m['vat_percent'] as num?)?.toDouble(),
    vatAmount: (m['vat_amount'] as num?)?.toDouble(),
    summary: (m['summary'] as num?)?.toDouble(),
    malName: m['mal_name']?.toString(),
    disc_totalm: (m['disc_total'] as num?)?.toDouble(),
    discountm: (m['discount'] as num?)?.toDouble(),
    vahid: m['vahid']?.toString(),
    tip: m['tip']?.toString(),
    marka: m['marka']?.toString(),
  );
}
