import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'main.dart'; // globalIp, globalPort üçün

class MusteriHesabatiPage extends StatefulWidget {
  const MusteriHesabatiPage({super.key});

  @override
  State<MusteriHesabatiPage> createState() => _MusteriHesabatiPageState();
}

class _MusteriHesabatiPageState extends State<MusteriHesabatiPage> {
  DateTime _date1 = DateTime.now();
  DateTime _date2 = DateTime.now();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _data = [];
  late KassaDataSource _dataSource;

  final NumberFormat _numFmt = NumberFormat('#,##0.00', 'en_US');



  double _totalLastNC = 0.0; // Son Qalıq MV cəmi üçün
  @override
  void initState() {
    super.initState();
    _dataSource = KassaDataSource([], notifyParent: _refreshTotals);
    _loadData(search: _searchCtrl.text);

  }

  Future<void> _pickDate1() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date1,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date1 = picked);
    _loadData(search: _searchCtrl.text);

  }

  Future<void> _pickDate2() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date2,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date2 = picked);
    _loadData(search: _searchCtrl.text);
  }

  Future<void> _loadData({String search = ''}) async {
    if (globalIp == null || globalPort == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
          'http://$globalIp:$globalPort/api/contractorbalancesale'
              '?date1=${DateFormat('yyyy-MM-dd').format(_date1)}'
              '&date2=${DateFormat('yyyy-MM-dd').format(_date2)}'
              '&search=$search'
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List) {
          _data = List<Map<String, dynamic>>.from(data);
          _dataSource.updateData(_data);
        } else {
          _error = 'Serverdən gözlənilməyən cavab.';
        }
      } else {
        _error = 'Xəta kodu: ${resp.statusCode}';
      }
    } catch (e) {
      _error = 'Şəbəkə xətası: $e';
    } finally {
      _loading = false;
      _refreshTotals();
      if (mounted) setState(() {});
    }
  }





  void _refreshTotals() {
    double sumIn = 0;
    double sumOut = 0;
    double sumLast = 0;
    double sumLastNC = 0; // Yeni cəm dəyişəni

    for (final m in _dataSource.rowsMap) {
      // Əgər 'xus' == 24 olan sətir sizin bazadan gələn 'Cəm' sətirdirsə,
      // onu təkrar cəmləməmək üçün 'if (m['xus'] != 24)' şərti qoya bilərsiniz.
      sumIn += _toDouble(m['in_amount']);
      sumOut += _toDouble(m['out_amount']);
      sumLast += _toDouble(m['last_amount']);
      sumLastNC += _toDouble(m['last_amount_nc']); // Doğru sütunu cəmləyirik
    }

    setState(() {
      _totalLastNC = sumLastNC; // UI-da görünən dəyəri yeniləyirik
    });
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  Future<void> fetchData(String search) async {
    final url = Uri.parse(
        'http://$globalIp:$globalPort/api/contractorbalancesale'
            '?date1=${DateFormat('yyyy-MM-dd').format(_date1)}'
            '&date2=${DateFormat('yyyy-MM-dd').format(_date2)}'
            '&search=$search'
    );

    final response = await http.get(url);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Müştəri satış hesabatı'),
        backgroundColor: Colors.white,

        // ... digər AppBar tənzimləmələri
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(

                child: Padding(
                  padding: const EdgeInsets.all(0),
                  // 🟢 Column istifadə edirik ki, tarixlər və axtarış alt-alta düşsün
                  child: Column(

                    children: [
                      // 1. Tarix seçimi hissəsi
                      Row(
                        children: [
                          _HeaderTile(
                            label: 'Tarix',
                            value: DateFormat('dd.MM.yyyy').format(_date1),
                            icon: Icons.date_range,
                            onTap: _pickDate1,
                          ),
                          const SizedBox(width: 8),
                          _HeaderTile(
                            label: 'Tarix',
                            value: DateFormat('dd.MM.yyyy').format(_date2),
                            icon: Icons.event,
                            onTap: _pickDate2,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12), // Aradakı məsafə

                      // 2. Axtarış (Search) hissəsi
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Musteri adına görə axtar...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onChanged: (val) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();

                          _debounce = Timer(const Duration(milliseconds: 500), () {
                            _loadData(search: val);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : SfDataGrid(
                    source: _dataSource,
                    columnWidthMode: ColumnWidthMode.fill,
                    gridLinesVisibility: GridLinesVisibility.both,
                    headerGridLinesVisibility: GridLinesVisibility.both,
                    columns: [
                      GridColumn(columnName: 'xus', width: 0, label: _header('xus')),
                      GridColumn(columnName: 'name', width: 200, label: _header('Kontragent')),
                      GridColumn(columnName: 'quantity', width: 80, label: _header('Miqdar')),
                      GridColumn(columnName: 'unit_name', width: 80, label: _header('Ölçü vahidi')),
                      GridColumn(columnName: 'price', width: 80, label: _header('Qiymət')),
                      GridColumn(columnName: 'currency', width: 80, label: _header('Valyuta')),
                      GridColumn(columnName: 'first_amount', width: 120, label: _header('İlk məbləğ|Əsas')),
                      GridColumn(columnName: 'first_vat_amount', width: 120, label: _header('İlk məbləğ|ƏDV')),
                      GridColumn(columnName: 'out_amount', width: 120, label: _header('Məxaric|Əsas')),
                      GridColumn(columnName: 'out_vat_amount', width: 120, label: _header('Məxaric|ƏDV')),
                      GridColumn(columnName: 'in_amount', width: 120, label: _header('Mədaxil|Əsas')),
                      GridColumn(columnName: 'in_vat_amount', width: 120, label: _header('Mədaxil|ƏDV')),
                      GridColumn(columnName: 'last_amount', width: 120, label: _header('Qalıq|Əsas')),
                      GridColumn(columnName: 'last_vat_amount', width: 120, label: _header('Qalıq|ƏDV')),
                      GridColumn(columnName: 'expeditor', width: 120, label: _header('Expeditor')),
                      GridColumn(columnName: 'tax_number', width: 120, label: _header('VÖEN')),
                      GridColumn(columnName: 'last_amount_mv', width: 120, label: _header('Qalıq MV')),
                      GridColumn(columnName: 'note', width: 300, label: _header('Qeyd')),
                      GridColumn(columnName: 'other', width: 300, label: _header('Digər')),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /* Text('Cəmi sətir: ${_dataSource.rowsCount}',
                      style: GoogleFonts.poppins(fontSize: 13)),*/
                  /*Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Son Qalıq ƏV: ${_numFmt.format(_totalLastNC)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ],
                  ),*/

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String title) => Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
  );
}

class KassaDataSource extends DataGridSource {
  List<DataGridRow> _rows = [];
  List<Map<String, dynamic>> _rowsMap = [];
  final VoidCallback? notifyParent;

  KassaDataSource(List<Map<String, dynamic>> source, {this.notifyParent}) {
    updateData(source);
  }

  List<Map<String, dynamic>> get rowsMap => _rowsMap;
  int get rowsCount => _rowsMap.length;

  void updateData(List<Map<String, dynamic>> source) {
    _rowsMap = source;
    _rows = _rowsMap.map<DataGridRow>((m) {
      return DataGridRow(cells: [


        DataGridCell<int>(columnName: 'xus', value: m['xus'] ?? 0),
        DataGridCell(columnName: 'name', value: m['name']),
        DataGridCell(columnName: 'quantity', value: _toDouble(m['quantity'])),
        DataGridCell(columnName: 'unit_name', value: m['unit_name']),
        DataGridCell(columnName: 'price', value: _toDouble(m['price'])),
        DataGridCell(columnName: 'currency', value: m['currency']),
        DataGridCell(columnName: 'first_amount', value: _toDouble(m['first_amount'])),
        DataGridCell(columnName: 'first_vat_amount', value: _toDouble(m['first_vat_amount'])),
        DataGridCell(columnName: 'out_amount', value: _toDouble(m['out_amount'])),
        DataGridCell(columnName: 'out_vat_amount', value: _toDouble(m['out_vat_amount'])),
        DataGridCell(columnName: 'in_amount', value: _toDouble(m['in_amount'])),
        DataGridCell(columnName: 'in_vat_amount', value: _toDouble(m['in_vat_amount'])),
        DataGridCell(columnName: 'last_amount', value: _toDouble(m['last_amount'])),
        DataGridCell(columnName: 'last_vat_amount', value: _toDouble(m['last_vat_amount'])),
        DataGridCell(columnName: 'expeditor', value: m['expeditor']),
        DataGridCell(columnName: 'tax_number', value: m['tax_number']),
        DataGridCell(columnName: 'last_amount_mv', value: _toDouble(m['last_amount_mv'])),
        DataGridCell(columnName: 'note', value: m['note']),
        DataGridCell(columnName: 'other', value: m['other']),
      ]);
    }).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (notifyParent != null) notifyParent!();
    });
    notifyListeners();
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final NumberFormat fmt = NumberFormat('#,##0.00', 'en_US');

    // "xus" sütununun dəyərini tapırıq
    final int status = row.getCells()
        .firstWhere((c) => c.columnName == 'xus')
        .value as int;

    // Əgər status 1-dirsə row boz (grey.shade100), deyilsə ağ olsun
    final Color rowBgColor = status == 24 ? Colors.grey.shade100 : Colors.white;

    return DataGridRowAdapter(
      cells: row.getCells().map((c) {
        final name = c.columnName;
        final val = c.value;

        // "xus" sütununu ekranda göstərmirik
        if (name == 'xus') return const SizedBox.shrink();

        bool isAmount = name.contains('amount');

        return Container(
          alignment: isAmount ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: rowBgColor, // Bütün sətir eyni rəngdə olur
          child: Text(
            isAmount ? fmt.format(val ?? 0) : (val?.toString() ?? ''),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.black,
              // Əgər status 1-dirsə yazıları qalın (bold) edə bilərsiz (istəyə bağlı)
              fontWeight: status == 24 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }


}


class _HeaderTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderTile({required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                  Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
