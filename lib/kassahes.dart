import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'main.dart'; // globalIp, globalPort üçün

class KassaHesabatiPage extends StatefulWidget {
  const KassaHesabatiPage({super.key});

  @override
  State<KassaHesabatiPage> createState() => _KassaHesabatiPageState();
}

class _KassaHesabatiPageState extends State<KassaHesabatiPage> {
  DateTime _date1 = DateTime.now().subtract(const Duration(days: 7));
  DateTime _date2 = DateTime.now();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _data = [];
  late KassaDataSource _dataSource;

  final NumberFormat _numFmt = NumberFormat('#,##0.00', 'en_US');

  // Cəmlər
  double _sumIn = 0.0;
  double _sumOut = 0.0;
  double _sumLast = 0.0;

  @override
  void initState() {
    super.initState();
    _dataSource = KassaDataSource([], notifyParent: _refreshTotals);
    _loadData();
  }

  Future<void> _pickDate1() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date1,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date1 = picked);
    _loadData();
  }

  Future<void> _pickDate2() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date2,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date2 = picked);
    _loadData();
  }

  Future<void> _loadData() async {
    if (globalIp == null || globalPort == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        'http://$globalIp:$globalPort/api/cashDeskBalance'
            '?date1=${DateFormat('yyyy-MM-dd').format(_date1)}'
            '&date2=${DateFormat('yyyy-MM-dd').format(_date2)}'
            '&userId=$globalTermname', // Burada istəyə uyğun userId dəyiş
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
    for (final m in _dataSource.rowsMap) {
      sumIn += _toDouble(m['in_amount']);
      sumOut += _toDouble(m['out_amount']);
      sumLast += _toDouble(m['last_amount']);
    }
    setState(() {
      _sumIn = sumIn/2;
      _sumOut = sumOut/2;
      _sumLast = sumLast;
    });
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kassa Hesabatı'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
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
                      GridColumn(columnName: 'cash_desk_name', width: 200, label: _header('Kassa')),
                      GridColumn(columnName: 'currency', width: 80, label: _header('Valyuta')),
                      GridColumn(columnName: 'first_amount', width: 130, label: _header('İlkin Qalıq')),
                      GridColumn(columnName: 'in_amount', width: 120, label: _header('Mədaxil')),
                      GridColumn(columnName: 'out_amount', width: 120, label: _header('Məxaric')),
                      GridColumn(columnName: 'last_amount', width: 130, label: _header('Son Qalıq')),
                      GridColumn(columnName: 'note', width: 250, label: _header('Qeyd')),
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
        DataGridCell(columnName: 'cash_desk_name', value: m['cash_desk_name']),
        DataGridCell(columnName: 'currency', value: m['currency']),
        DataGridCell(columnName: 'first_amount', value: _toDouble(m['first_amount'])),
        DataGridCell(columnName: 'in_amount', value: _toDouble(m['in_amount'])),
        DataGridCell(columnName: 'out_amount', value: _toDouble(m['out_amount'])),
        DataGridCell(columnName: 'last_amount', value: _toDouble(m['last_amount'])),
        DataGridCell(columnName: 'note', value: m['note']),
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
    return DataGridRowAdapter(
      cells: row.getCells().map((c) {
        final name = c.columnName;
        final val = c.value;
        final style = TextStyle(fontSize: 13);
        final align = (name.contains('amount'))
            ? Alignment.centerRight
            : Alignment.centerLeft;
        final fmt = NumberFormat('#,##0.00', 'en_US');

        return Container(
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: (name.contains('amount'))
              ? Text(fmt.format(val ?? 0), style: style)
              : Text(val?.toString() ?? '', style: style),
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
