
import 'dart:convert';
import 'dart:math' as math; // 🔹 clamp əvəzinə min istifadə üçün
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'main.dart'; // globalIp, globalPort üçün

class SatishesPage extends StatefulWidget {
  const SatishesPage({super.key});

  @override
  State<SatishesPage> createState() => _SatishesPageState();
}

class _SatishesPageState extends State<SatishesPage> {
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _dateTo = DateTime.now();

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _listScrollCtrl = ScrollController();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _filtered = [];

  // Lazy-load parametrləri
  int _visibleCount = 0;
  static const int _chunkSize = 50;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _listScrollCtrl.addListener(_onListScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listScrollCtrl.dispose();
    super.dispose();
  }

  // ==== Format köməkçiləri
  String _fmtApi(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtUi(DateTime d)  => DateFormat('dd.MM.yyyy').format(d);

  // ==== Sətir dəyərləri
  double _getQalMiq(Map<String, dynamic> m) {
    final v = m['qalmiq'] ?? 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double _getQalMeb(Map<String, dynamic> m) {
    final v = m['qalmeb'] ?? 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // ==== Tarix seçimi
  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateFrom = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateTo = picked);
  }

  // ==== Axtarış və filtr
  void _onSearchChanged() {
    _applyFilter(resetVisible: true);
  }

  void _applyFilter({bool resetVisible = false}) {
    final q = _searchCtrl.text.toLowerCase().trim();

    List<Map<String, dynamic>> next;
    if (q.isEmpty) {
      next = List.of(_rows);
    } else {
      next = _rows.where((m) {
        final kod   = (m['kod']   ?? '').toString().toLowerCase();
        final adi   = (m['adi']   ?? '').toString().toLowerCase();
        final tip   = (m['tip']   ?? '').toString().toLowerCase();
        final qrup  = (m['qrup']  ?? '').toString().toLowerCase();
        final anbar = (m['anbar'] ?? '').toString().toLowerCase();
        return kod.contains(q) || adi.contains(q) || tip.contains(q) || qrup.contains(q) || anbar.contains(q);
      }).toList();
    }

    // Mövcud sort qaydasını saxla
    if (_sortColumnIndex != null) {
      _sortListInPlace(next, _sortColumnIndex!, _sortAscending);
    }

    setState(() {
      _filtered = next;
      if (resetVisible) {
        _visibleCount = next.isEmpty ? 0 : math.min(_chunkSize, next.length); // 🔹 clamp -> min
      } else {
        if (_visibleCount > next.length) _visibleCount = next.length;
      }
    });
  }

  void _sortBy<T>(Comparable<T> Function(Map<String, dynamic>) keySel, int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _filtered.sort((a, b) {
        final ka = keySel(a);
        final kb = keySel(b);
        final r = Comparable.compare(ka, kb);
        return _sortAscending ? r : -r;
      });
    });
  }

  void _sortListInPlace(List<Map<String, dynamic>> list, int columnIndex, bool asc) {
    int idx = columnIndex;
    int compare(Map<String, dynamic> a, Map<String, dynamic> b) {
      int r;
      switch (idx) {
        case 0:
          r = ((a['kod'] ?? '').toString()).compareTo((b['kod'] ?? '').toString());
          break;
        case 1:
          r = ((a['adi'] ?? '').toString()).compareTo((b['adi'] ?? '').toString());
          break;
        case 5:
          r = _getQalMiq(a).compareTo(_getQalMiq(b));
          break;
        case 6:
          r = _getQalMeb(a).compareTo(_getQalMeb(b));
          break;
        default:
          r = 0;
      }
      return asc ? r : -r;
    }
    list.sort(compare);
  }

  // ==== Scroll-da lazy-load
  void _onListScroll() {
    if (_filtered.isEmpty) return;
    if (_listScrollCtrl.position.pixels >= _listScrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_visibleCount >= _filtered.length) return;
    setState(() {
      _visibleCount = math.min(_visibleCount + _chunkSize, _filtered.length); // 🔹 clamp -> min
    });
  }

  // ==== API
  Future<void> _onCalculate() async {
    if (_dateFrom.isAfter(_dateTo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlanğıc tarix son tarixdən böyük ola bilməz.')),
      );
      return;
    }
    if (globalIp == null || globalPort == null || globalIp!.isEmpty || globalPort!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server IP/Port təyin olunmayıb. Tənzimləmələri yoxlayın.')),
      );
      return;
    }

    final uri = Uri.parse('http://$globalIp:$globalPort/sat_hes');
    final body = jsonEncode({
      'start': _fmtApi(_dateFrom),
      'end':   _fmtApi(_dateTo),
    });

    setState(() { _loading = true; _error = null; });

    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        if (data is List) {
          _rows = data.cast<Map<String, dynamic>>();
          // default sort: Adı artan
          _sortColumnIndex = 1;
          _sortAscending = true;
          _rows.sort((a, b) => ((a['adi'] ?? '').toString()).compareTo((b['adi'] ?? '').toString()));

          _filtered = List.of(_rows);
          _visibleCount = _filtered.isEmpty ? 0 : math.min(_chunkSize, _filtered.length); // 🔹 clamp -> min
          setState(() {});
        } else {
          setState(() {
            _rows = []; _filtered = []; _visibleCount = 0;
            _error = 'Serverdən gözlənilməyən cavab alındı.';
          });
        }
      } else {
        setState(() {
          _rows = []; _filtered = []; _visibleCount = 0;
          _error = 'Xəta: ${resp.statusCode} — ${resp.body}';
        });
      }
    } catch (e) {
      setState(() {
        _rows = []; _filtered = []; _visibleCount = 0;
        _error = 'Şəbəkə xətası: $e';
      });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  // ==== UI
  @override
  Widget build(BuildContext context) {
    final rowsToShow = _filtered.take(_visibleCount).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Satış hesabatı'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87,
        ),
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: ListView(
        controller: _listScrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderTile(
                          label: 'Tarix',
                          value: _fmtUi(_dateFrom),
                          icon: Icons.event,
                          onTap: _pickFrom,
                          valueFontSize: 12, // 🔹 yalnız value kiçik
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _HeaderTile(
                          label: 'Tarix',
                          value: _fmtUi(_dateTo),
                          icon: Icons.event_available,
                          onTap: _pickTo,
                          valueFontSize: 12, // 🔹 yalnız value kiçik
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Axtar',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _applyFilter(resetVisible: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _onCalculate,
                          icon: const Icon(Icons.calculate),
                          label: const Text('Hesabla'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // CƏDVƏL
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: _loading
                ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
                : _error != null
                ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
                : rowsToShow.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nəticə yoxdur.'),
            )
                : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    columns: _buildColumns(),
                    rows: _buildRows(rowsToShow),
                    headingRowHeight: 44,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 60,
                  ),
                ),
                if (_visibleCount < _filtered.length)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: OutlinedButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.expand_more),
                      label: Text('Daha çox yüklə ($_visibleCount/${_filtered.length})'),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Cəmi (hazırda gizlidir)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: []),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    return [
      DataColumn(
        label: const Text('Kod'),
        onSort: (i, _) => _sortBy<String>((m) => (m['kod'] ?? '').toString(), i),
      ),
      DataColumn(
        label: const Text('Adı'),
        onSort: (i, _) => _sortBy<String>((m) => (m['adi'] ?? '').toString(), i),
      ),
      const DataColumn(label: Text('Tip')),
      const DataColumn(label: Text('Qrup')),
      const DataColumn(label: Text('Anbar')),
      DataColumn(
        numeric: true,
        label: const Text('Qalıq miq.'),
        onSort: (i, _) => _sortBy<num>((m) => _getQalMiq(m), i),
      ),
      DataColumn(
        numeric: true,
        label: const Text('Qalıq məbl.'),
        onSort: (i, _) => _sortBy<num>((m) => _getQalMeb(m), i),
      ),
    ];
  }

  List<DataRow> _buildRows(List<Map<String, dynamic>> subset) {
    return subset.map((m) {
      final qalmiq = _getQalMiq(m);
      final qalmeb = _getQalMeb(m);
      return DataRow(cells: [
        DataCell(Text((m['kod'] ?? '').toString())),
        DataCell(Text((m['adi'] ?? '').toString())),
        DataCell(Text((m['tip'] ?? '').toString())),
        DataCell(Text((m['qrup'] ?? '').toString())),
        DataCell(Text((m['anbar'] ?? '').toString())),
        DataCell(Text(qalmiq.toStringAsFixed(qalmiq == qalmiq.roundToDouble() ? 0 : 2))),
        DataCell(Text(qalmeb.toStringAsFixed(2))),
      ]);
    }).toList();
  }
}

class _HeaderTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final double valueFontSize; // 🔹 yalnız value üçün

  const _HeaderTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.valueFontSize = 12, // 🔹 default kiçik ölçü
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: valueFontSize, // 🔹 təkcə value kiçilir
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            //  const Icon(Icons.edit_calendar, size: 12),
          ],
        ),
      ),
    );
  }
}
