import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart' show globalIp, globalPort;

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<dynamic> _reports = [];
  List<Map<String, dynamic>> _availableAreas = [];
  bool _isLoading = false;

  String _viewType = "ALL";
  String _selectedDegree = "ALL";
  DateTimeRange? _selectedDateRange;
  final TextEditingController _searchController = TextEditingController();
  String _selectedArea = "Hamısı";

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // IP formatını təmizləmək üçün köməkçi funksiya
  String get _baseUrl {
    final host = globalIp!.trim().replaceAll(RegExp(r'^https?://'), '');
    return 'http://$host:$globalPort';
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchAreas();
    await _fetchReports();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAreas() async {
    try {
      final url = Uri.parse('$_baseUrl/eraziler');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final List<dynamic> decodedData = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _availableAreas = [{"erazi_adi": "Hamısı"}];
            for (var item in decodedData) {
              _availableAreas.add(Map<String, dynamic>.from(item));
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Ərazi yükləmə xətası: $e");
    }
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);

    // Əgər tarix seçilməyibsə, cari ayın 1-dən bu günə qədər olan aralığı götürür
    String startStr = _selectedDateRange != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)
        : DateFormat('yyyy-MM-01').format(DateTime.now());
    String endStr = _selectedDateRange != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    String url = '$_baseUrl/reports?'
        'erazi_adi=${Uri.encodeComponent(_selectedArea)}'
        '&filter_type=$_viewType'
        '&degree=$_selectedDegree'
        '&start_date=$startStr'
        '&end_date=$endStr';

    if (_searchController.text.isNotEmpty) {
      url += '&search_query=${Uri.encodeComponent(_searchController.text)}';
    }

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        if (mounted) setState(() { _reports = jsonDecode(resp.body); });
      }
    } catch (e) {
      debugPrint("Hesabat yükləmə xətası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatFullDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "--:--";
    try {
      DateTime dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (e) {
      return "--:--";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Ziyarətləri yoxla", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.indigo[900],
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterPanel(),
          _buildQuickSelectors(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _fetchReports,
              child: _reports.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: _reports.length,
                itemBuilder: (context, index) => _buildDetailedCard(_reports[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Üst hissədəki Status və Dərəcə seçimləri
  Widget _buildQuickSelectors() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: Row(
              children: [
                _quickChip("Hamısı", "ALL"),
                const SizedBox(width: 8),
                _quickChip("Tamamlanıb", "COMPLETED", activeColor: Colors.green),
                const SizedBox(width: 8),
                _quickChip("Natamam", "INCOMPLETE", activeColor: Colors.orange),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Row(
              children: [
                const Icon(Icons.star_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text("Dərəcə: ", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                _degreeChip("Hamısı", "ALL"),
                _degreeChip("1-ci", "1"),
                _degreeChip("2-ci", "2"),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _quickChip(String label, String val, {Color activeColor = Colors.indigo}) {
    bool isSelected = _viewType == val;
    return ChoiceChip(
      label: Text(label),
      labelStyle: GoogleFonts.poppins(
          fontSize: 11,
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: Colors.grey[200],
      onSelected: (selected) {
        if (selected) {
          setState(() => _viewType = val);
          _fetchReports();
        }
      },
    );
  }

  Widget _degreeChip(String label, String val) {
    bool isSelected = _selectedDegree == val;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ActionChip(
        padding: EdgeInsets.zero,
        label: Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black87)),
        backgroundColor: isSelected ? Colors.orange[800] : Colors.grey[100],
        onPressed: () {
          setState(() => _selectedDegree = val);
          _fetchReports();
        },
      ),
    );
  }

  Widget _buildDetailedCard(dynamic item) {
    bool isVisited = item['ziyaret_edilib'] == 1;
    int fakt = item['bu_ayki_ziyaret_sayi'] ?? 0;
    int teleb = item['teleb_olunan_say'] ?? 1;
    bool planDolub = fakt >= teleb;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Kartın üst başlığı (Plan faizi)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: planDolub ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: planDolub ? Colors.green : Colors.orange),
                    const SizedBox(width: 5),
                    Text("PLAN: $fakt / $teleb",
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: planDolub ? Colors.green[800] : Colors.orange[800])),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.indigo[900], borderRadius: BorderRadius.circular(10)),
                  child: Text("Dərəcə: ${item['derece']}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['hekim_adi'] ?? "Naməlum Həkim",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo[900])),
                const SizedBox(height: 8),
                _infoRow(Icons.business_rounded, "Klinika:", item['erazi_adi1'] ?? "-", iconColor: Colors.blueGrey),

                if (isVisited) ...[
                  const Divider(height: 20),
                  _infoRow(Icons.badge_outlined, "Son ziyarət:", item['emekdas_adi'] ?? "-", iconColor: Colors.blue),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _timeBox("GİRİŞ", _formatFullDate(item['baslama_tarixi']), Colors.green)),
                      Container(width: 1, height: 30, color: Colors.grey[200]),
                      Expanded(child: _timeBox("ÇIXIŞ", _formatFullDate(item['bitirme_tarixi']), Colors.red)),
                    ],
                  ),
                  if (item['qeyd'] != null && item['qeyd'].toString().isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                      child: Text("Qeyd: ${item['qeyd']}", style: TextStyle(fontSize: 11, color: Colors.grey[700], fontStyle: FontStyle.italic)),
                    ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy, color: Colors.red, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text("Bu tarix aralığında ziyarət edilməyib.",
                              style: GoogleFonts.poppins(color: Colors.red[900], fontSize: 11, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color iconColor = Colors.orange}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Text("$label ", style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _timeBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.shareTechMono(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: Colors.indigo[900],
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Axtarış sahəsi
          TextField(
            controller: _searchController,
            onChanged: (v) {
              // İstifadəçi yazdıqca axtarması üçün (opsional: debounce əlavə edilə bilər)
            },
            onSubmitted: (_) => _fetchReports(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Həkim və ya əməkdaş axtar...",
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, color: Colors.white70), onPressed: () { _searchController.clear(); _fetchReports(); })
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Ərazi seçimi
              Expanded(
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedArea,
                      dropdownColor: Colors.indigo[800],
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: _availableAreas.map((a) => DropdownMenuItem(value: a['erazi_adi'].toString(), child: Text(a['erazi_adi'].toString()))).toList(),
                      onChanged: (v) { if (v != null) { setState(() => _selectedArea = v); _fetchReports(); } },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Tarix seçimi düyməsi
              GestureDetector(
                onTap: _selectDateRange,
                child: Container(
                  height: 45, width: 50,
                  decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.calendar_month, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "${DateFormat('dd.MM.yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_selectedDateRange!.end)}",
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("Məlumat tapılmadı", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Colors.indigo[900]!, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _fetchReports();
    }
  }
}