
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'main.dart'; // globalIp, globalPort üçün

class MalqaliqlarihesPage extends StatefulWidget {
  const MalqaliqlarihesPage({super.key});

  @override
  State<MalqaliqlarihesPage> createState() => _MalqaliqlarihesPageState();
}

class _MalqaliqlarihesPageState extends State<MalqaliqlarihesPage> {
  DateTime _date = DateTime.now();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _data = [];
  late ProductBalanceDataSource _dataSource;

  // Sort
  String? _sortColumn;
  bool _sortAscending = true;

  final NumberFormat _numFmt = NumberFormat('#,##0.00', 'en_US');
  final NumberFormat _qtyFmt = NumberFormat('#,##0.00', 'en_US');



  @override
  void initState() {
    super.initState();
    _dataSource = ProductBalanceDataSource([], notifyParent: _refreshTotals);
    _searchCtrl.addListener(_onSearchChanged);

    // İlk yükləmə üçün
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtApi(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtUi(DateTime d)  => DateFormat('dd.MM.yyyy').format(d);

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
    _applyFilter(q);
  }

  void _applyFilter(String q) {
    if (q.isEmpty) {
      _dataSource.updateData(_data);
    } else {
      final filtered = _data.where((m) {
        final name = (m['name'] ?? '').toString().toLowerCase();
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
      final uri = Uri.parse('http://$globalIp:$globalPort/api/productBalance?date2=${DateFormat('yyyy-MM-dd').format(_date)}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 30));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        if (data is List) {
          _data = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          // default sort: by name
          _sortColumn = 'name';
          _sortAscending = true;
          _sortData();
          _dataSource.updateData(_data);
          _dataSource.notifyListeners();
        } else {
          setState(() {
            _error = 'Serverdən gözlənilməyən cavab alındı.';
            _data = [];
            _dataSource.updateData([]);
          });
        }
      } else {
        setState(() {
          _error = 'Xəta: ${resp.statusCode} — ${resp.body}';
          _data = [];
          _dataSource.updateData([]);
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Şəbəkə xətası: $e';
        _data = [];
        _dataSource.updateData([]);
      });
    } finally {
      if (mounted) setState(() { _loading = false; });
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
      // number or string handling
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
      _dataSource.notifyListeners();
    });
  }

  // Footer üçün totals
  double _totalBalance = 0.0;
  double _totalBalanceAmount = 0.0;
  double _totalBalanceSaleAmount = 0.0;

  void _refreshTotals() {
    final list = _dataSource.rowsMap;
    // rowsMap contains list of maps
    double tb = 0.0;
    double tba = 0.0;
    double tbsa = 0.0;
    for (final m in list) {
      final bal = _toDouble(m['balance']);
      final balAmt = _toDouble(m['balance_amount']);
      final balSale = _toDouble(m['balance_sale_amount']);
      tb += bal;
      tba += balAmt;
      tbsa += balSale;
    }
    setState(() {
      _totalBalance = double.parse(tb.toStringAsFixed(2));
      _totalBalanceAmount = double.parse(tba.toStringAsFixed(2));
      _totalBalanceSaleAmount = double.parse(tbsa.toStringAsFixed(2));
    });
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    double val;
    if (v is num) val = v.toDouble();
    else {
      String cleaned = v.toString().replaceAll('.', '').replaceAll(',', '.');
      val = double.tryParse(cleaned) ?? 0.0;
    }
    return double.parse(val.toStringAsFixed(2));
  }



  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mal qalıqları (fifo)'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header kart
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
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
                    ],
                  ),
                ),
              ),
            ),

            // Grid və footer
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ))
                      : Column(
                    children: [
                      // Grid (flexible height)
                      Expanded(
                        child: SfDataGrid(
                          source: _dataSource,
                          columnWidthMode: ColumnWidthMode.fill,
                          allowSorting: true,
                          allowColumnsResizing: true,
                          allowPullToRefresh: false,
                          isScrollbarAlwaysShown: true,
                          gridLinesVisibility: GridLinesVisibility.both,
                          headerGridLinesVisibility: GridLinesVisibility.both,
                          columns: <GridColumn>[
                            GridColumn(
                              columnName: 'code',
                              width: 110,
                              label: _buildColHeader('Kod', 'code'),
                            ),
                            GridColumn(
                              columnName: 'name',
                              width: 300,
                              label: _buildColHeader('Adı', 'name'),
                            ),
                            GridColumn(
                              columnName: 'unit_name',
                              width: 100,
                              label: _buildColHeader('Ölçü', 'unit_name'),
                            ),
                            GridColumn(
                              columnName: 'barcode',
                              width: 150,
                              label: _buildColHeader('Barkod', 'barcode'),
                            ),
                            GridColumn(
                              columnName: 'balance',
                              width: 120,
                              label: _buildColHeader('Qalıq (miq.)', 'balance'),
                            ),
                            GridColumn(
                              columnName: 'reserved_quantity',
                              width: 120,
                              label: _buildColHeader('Rezerv', 'reserved_quantity'),
                            ),
                            GridColumn(
                              columnName: 'last_balance',
                              width: 120,
                              label: _buildColHeader('Son Qalıq', 'last_balance'),
                            ),
                            GridColumn(
                              columnName: 'balance_price',
                              width: 120,
                              label: _buildColHeader('Orta Maya', 'balance_price'),
                            ),
                            GridColumn(
                              columnName: 'balance_amount',
                              width: 140,
                              label: _buildColHeader('Qalıq Məbləğ', 'balance_amount'),
                            ),
                            GridColumn(
                              columnName: 'balance_sale_amount',
                              width: 160,
                              label: _buildColHeader('Satış Məbləğ', 'balance_sale_amount'),
                            ),
                            GridColumn(
                              columnName: 'depo_name',
                              width: 180,
                              label: _buildColHeader('Anbar', 'depo_name'),
                            ),
                          ],
                          tableSummaryRows: <GridTableSummaryRow>[
                            GridTableSummaryRow(
                              showSummaryInRow: false,
                              position: GridTableSummaryRowPosition.bottom,
                              title: 'Cəmlər',
                              columns: <GridSummaryColumn>[
                                GridSummaryColumn(
                                    name: 'sum_balance',
                                    columnName: 'balance',
                                    summaryType: GridSummaryType.sum),
                                GridSummaryColumn(
                                    name: 'sum_balance_amount',
                                    columnName: 'balance_amount',
                                    summaryType: GridSummaryType.sum),
                                GridSummaryColumn(
                                    name: 'sum_balance_sale_amount',
                                    columnName: 'balance_sale_amount',
                                    summaryType: GridSummaryType.sum),
                              ],
                              // customAggregate may be used for formatting but we will display formatted values below as well
                            ),
                          ],
                        ),
                      ),

                      // Aşağı footer (özəl daha böyük görünüş və formatlı cəmlər)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.grey.shade200)),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            //Expanded(
                            //child: Text(
                            //'Sətir: ${_dataSource.rowsCount}     Filtr nəticə: ${_dataSource.rowsCount}',
                            // style: GoogleFonts.poppins(fontSize: 13),
                            //    ),
                            //    ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Qalıq miqdarı: ${_qtyFmt.format(_totalBalance)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('Qalıq məbləği: ${_numFmt.format(_totalBalanceAmount)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('Satış məbləği: ${_numFmt.format(_totalBalanceSaleAmount)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColHeader(String title, String columnName) {
    final isSorted = _sortColumn == columnName;
    final icon = isSorted ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null;
    return InkWell(
      onTap: () => _onColumnHeaderTap(columnName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
            if (icon != null) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 14),
            ]
          ],
        ),
      ),
    );
  }
}

/// DataSource üçün sinif
class ProductBalanceDataSource extends DataGridSource {
  List<DataGridRow> _rows = [];
  List<Map<String, dynamic>> _rowsMap = [];
  final VoidCallback? notifyParent;

  ProductBalanceDataSource(List<Map<String, dynamic>> source, {this.notifyParent}) {
    updateData(source);
  }

  // rahatlik üçün row map-ə çıxış
  List<Map<String, dynamic>> get rowsMap => _rowsMap;
  int get rowsCount => _rowsMap.length;

  void updateData(List<Map<String, dynamic>> source) {
    _rowsMap = source.map((m) => Map<String, dynamic>.from(m)).toList();
    _rows = _rowsMap.map<DataGridRow>((m) {
      return DataGridRow(cells: [
        DataGridCell(columnName: 'code', value: m['code'] ?? ''),
        DataGridCell(columnName: 'name', value: m['name'] ?? ''),
        DataGridCell(columnName: 'unit_name', value: m['unit_name'] ?? ''),
        DataGridCell(columnName: 'barcode', value: m['barcode'] ?? ''),
        DataGridCell(columnName: 'balance', value: _toDouble(m['balance'])),
        DataGridCell(columnName: 'reserved_quantity', value: _toDouble(m['reserved_quantity'])),
        DataGridCell(columnName: 'last_balance', value: _toDouble(m['last_balance'])),
        DataGridCell(columnName: 'balance_price', value: _toDouble(m['balance_price'])),
        DataGridCell(columnName: 'balance_amount', value: _toDouble(m['balance_amount'])),
        DataGridCell(columnName: 'balance_sale_amount', value: _toDouble(m['balance_sale_amount'])),
        DataGridCell(columnName: 'depo_name', value: m['depo_name'] ?? ''),
      ]);
    }).toList();

    // Footer parentə xəbər et
    if (notifyParent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyParent!();
      });
    }

    notifyListeners();
  }


  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    double val;
    if (v is num) val = v.toDouble();
    else val = double.tryParse(v.toString()) ?? 0.0;
    // Decimal (18,2) dəqiqliklə yuvarlaqla
    return double.parse(val.toStringAsFixed(2));
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    // Hüceyrələr üçün alignments və formatlama
    return DataGridRowAdapter(cells: row.getCells().map<Widget>((c) {
      final col = c.columnName;
      final val = c.value;
      final style = TextStyle(fontSize: 13, color: Colors.black87);
      if (col == 'balance' || col == 'reserved_quantity' || col == 'last_balance') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerRight,
          child: Text(NumberFormat('#,##0.00', 'en_US').format(val ?? 0), style: style),

        );
      } else if (col == 'balance_amount' || col == 'balance_sale_amount' || col == 'balance_price') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerRight,
          child: Text(NumberFormat('#,##0.00', 'en_US').format(val ?? 0), style: style),

        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Text(val?.toString() ?? '', style: style),
        );
      }
    }).toList());
  }
}

/// Header tile komponenti
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
                Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
