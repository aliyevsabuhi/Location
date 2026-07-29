import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'main.dart'; // globalIp, globalPort üçün

class BalanshesanbPage extends StatefulWidget {
  const BalanshesanbPage({super.key});

  @override
  State<BalanshesanbPage> createState() => _BalanshesanbPageState();
}

class _BalanshesanbPageState extends State<BalanshesanbPage> {
  DateTime _date = DateTime.now();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _data = [];
  late ProductBalanceDataSource _dataSource;

  String? _sortColumn;
  bool _sortAscending = true;

  final NumberFormat _numFmt = NumberFormat('#,##0.00', 'en_US');
  final NumberFormat _qtyFmt = NumberFormat('#,##0.###', 'en_US');

  @override
  void initState() {
    super.initState();
    _dataSource = ProductBalanceDataSource([], notifyParent: _refreshTotals);
    _searchCtrl.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtApi(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtUi(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
    }
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _dataSource.updateData(_data);
    } else {
      final filtered = _data.where((m) {
        final name = (m['product_name'] ?? '').toString().toLowerCase();
        final code = (m['code'] ?? '').toString().toLowerCase();
        final barcode = (m['barcode'] ?? '').toString().toLowerCase();
        final depo = (m['depo_name'] ?? '').toString().toLowerCase();
        return name.contains(q) || code.contains(q) || barcode.contains(q) || depo.contains(q);
      }).toList();
      _dataSource.updateData(filtered);
    }
    _dataSource.notifyListeners();
  }

  Future<void> _loadData() async {
    if (globalIp == null || globalPort == null || globalIp!.isEmpty || globalPort!.isEmpty) {
      setState(() => _error = 'Server IP/Port təyin olunmayıb.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
          'http://$globalIp:$globalPort/api/productBalanceWareHouse?date2=${_fmtApi(_date)}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List) {
          _data = data.map((e) => Map<String, dynamic>.from(e)).toList();
          _sortColumn = 'product_name';
          _sortAscending = true;
          _sortData();
          _dataSource.updateData(_data);
        } else {
          _error = 'Serverdən gözlənilməyən cavab alındı.';
        }
      } else {
        _error = 'Xəta: ${resp.statusCode} — ${resp.body}';
      }
    } catch (e) {
      _error = 'Şəbəkə xətası: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  void _sortData() {
    if (_sortColumn == null) return;
    _data.sort((a, b) {
      final va = a[_sortColumn];
      final vb = b[_sortColumn];
      if (va == null && vb == null) return 0;
      if (va == null) return _sortAscending ? -1 : 1;
      if (vb == null) return _sortAscending ? 1 : -1;
      if (va is num && vb is num) {
        return _sortAscending ? va.compareTo(vb) : vb.compareTo(va);
      } else {
        return _sortAscending
            ? va.toString().toLowerCase().compareTo(vb.toString().toLowerCase())
            : vb.toString().toLowerCase().compareTo(va.toString().toLowerCase());
      }
    });
  }

  void _onColumnHeaderTap(String columnName) {
    setState(() {
      if (_sortColumn == columnName) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = columnName;
        _sortAscending = true;
      }
      _sortData();
      _dataSource.updateData(_data);
    });
  }

  // Cəmlər
  double _totalQuantity = 0.0;

  void _refreshTotals() {
    double total = 0.0;
    for (final m in _dataSource.rowsMap) {
      total += _toDouble(m['quantity']);
    }
    setState(() => _totalQuantity = total);
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balans hesabatı(Anbardar)'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: _HeaderTile(
                          label: 'Tarix',
                          value: _fmtUi(_date),
                          icon: Icons.event,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            labelText: 'Axtarış',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _loading ? null : _loadData,
                        icon: const Icon(Icons.calculate),
                        label: const Text('Hesabla'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: SfDataGrid(
                    source: _dataSource,
                    columnWidthMode: ColumnWidthMode.fill,
                    gridLinesVisibility: GridLinesVisibility.both,
                    headerGridLinesVisibility: GridLinesVisibility.both,
                    columns: [
                      GridColumn(
                        columnName: 'code',
                        width: 100,
                        label: _buildColHeader('Kod', 'code'),
                      ),
                      GridColumn(
                        columnName: 'barcode',
                        width: 140,
                        label: _buildColHeader('Barkod', 'barcode'),
                      ),
                      GridColumn(
                        columnName: 'product_name',
                        width: 260,
                        label: _buildColHeader('Məhsul', 'product_name'),
                      ),
                      GridColumn(
                        columnName: 'depo_name',
                        width: 200,
                        label: _buildColHeader('Anbar', 'depo_name'),
                      ),
                      GridColumn(
                        columnName: 'quantity',
                        width: 120,
                        label: _buildColHeader('Miqdar', 'quantity'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Cəmi miqdar: ${_qtyFmt.format(_totalQuantity)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColHeader(String title, String columnName) {
    final isSorted = _sortColumn == columnName;
    final icon =
    isSorted ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null;
    return InkWell(
      onTap: () => _onColumnHeaderTap(columnName),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(icon, size: 14),
          ],
        ],
      ),
    );
  }
}

class ProductBalanceDataSource extends DataGridSource {
  List<DataGridRow> _rows = [];
  List<Map<String, dynamic>> rowsMap = [];
  final VoidCallback? notifyParent;

  ProductBalanceDataSource(List<Map<String, dynamic>> source, {this.notifyParent}) {
    updateData(source);
  }

  void updateData(List<Map<String, dynamic>> source) {
    rowsMap = source;
    _rows = source.map<DataGridRow>((m) {
      return DataGridRow(cells: [
        DataGridCell(columnName: 'code', value: m['code'] ?? ''),
        DataGridCell(columnName: 'barcode', value: m['barcode'] ?? ''),
        DataGridCell(columnName: 'product_name', value: m['product_name'] ?? ''),
        DataGridCell(columnName: 'depo_name', value: m['depo_name'] ?? ''),
        DataGridCell(columnName: 'quantity', value: _toDouble(m['quantity'])),
      ]);
    }).toList();

    if (notifyParent != null) WidgetsBinding.instance.addPostFrameCallback((_) => notifyParent!());
    notifyListeners();
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map((c) {
        final val = c.value;
        if (c.columnName == 'quantity') {
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(NumberFormat('#,##0.###', 'en_US').format(val)),
          );
        }
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(val?.toString() ?? ''),
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

  const _HeaderTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
