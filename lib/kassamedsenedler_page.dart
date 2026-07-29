import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'main.dart' show globalIp, globalPort, globalAllowDateChange, globalTermname,globalceki, globaleded;

class KassaMedaxilDocPage extends StatefulWidget {
  const KassaMedaxilDocPage({super.key});

  @override
  State<KassaMedaxilDocPage> createState() => _KassaMedaxilDocPageState();
}

class _KassaMedaxilDocPageState extends State<KassaMedaxilDocPage> {
  bool _loading = true;
  String? _error;
  List<KassaMedaxilHeader> _headers = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  Color _statusColor(int? status) {
    switch (status) {
      case 0:
        return Colors.green.shade100;
      case 1:
        return Colors.yellow.shade100;
      default:
        return Colors.white;
    }
  }

  Future<void> _loadHeaders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final base = 'http://$globalIp:$globalPort';
    final url = Uri.parse(
        '$base/kassamedaxildoc?userId=$globalTermname&start=${DateFormat('yyyy-MM-dd').format(_startDate)}&end=${DateFormat('yyyy-MM-dd').format(_endDate)}');

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List;
        final items = list
            .map((e) => KassaMedaxilHeader.fromMap(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _headers = items;
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kassa Mədaxil Sənədləri")),
      body: Column(
        children: [
          _buildDateFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
              onRefresh: _loadHeaders,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _headers.length,
                itemBuilder: (ctx, i) {
                  final h = _headers[i];
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
                          Text("Kimdən: ${h.contractor_name}"),
                          Text("Kassa: ${h.kassa}"),
                          Text("Məbləğ: ${(h.amount ?? 0).toStringAsFixed(2)} ${h.currency ?? ''}"),
                          if ((h.note ?? '').isNotEmpty)
                            Text("Qeyd: ${h.note}"),
                          if ((h.insUser ?? '').isNotEmpty)
                            Text("İcraçı: ${h.insUser}"),
                        ],
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

// ================== MODEL ==================
class KassaMedaxilHeader {
  final int idn;
  final String? documentNo;
  final DateTime? date;
  final String? currency;
  final double? rate;
  final double? amount;
  final String? note;
  final String? contractor_name;
  final String? kassa;
  final int? status;
  final String? insUser;
  final DateTime? insDate;
  final String? updUser;
  final DateTime? updDate;
  final List<KassaMedaxilLine> lines;

  KassaMedaxilHeader({
    required this.idn,
    this.documentNo,
    this.date,
    this.currency,
    this.rate,
    this.amount,
    this.note,
    this.contractor_name,
    this.kassa,
    this.status,
    this.insUser,
    this.insDate,
    this.updUser,
    this.updDate,
    this.lines = const [],
  });

  factory KassaMedaxilHeader.fromMap(Map<String, dynamic> m) {
    List<KassaMedaxilLine> parsedLines = [];
    if (m['lines'] != null) {
      final list = m['lines'] is String ? jsonDecode(m['lines']) : m['lines'];
      parsedLines = (list as List).map((e) => KassaMedaxilLine.fromMap(e)).toList();
    }

    DateTime? _parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    double? _toDouble(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

    int? _toInt(dynamic v) =>
        v == null ? null : (v is bool ? (v ? 1 : 0) : (v is num ? v.toInt() : int.tryParse(v.toString())));

    return KassaMedaxilHeader(
      idn: _toInt(m['idn']) ?? 0,
      documentNo: m['document_no']?.toString(),
      date: _parseDate(m['date']),
      currency: m['currency']?.toString(),
      rate: _toDouble(m['rate']),
      amount: _toDouble(m['amount']),
      note: m['note']?.toString(),
      contractor_name: m['contractor_name']?.toString(),
      kassa: m['kassa']?.toString(),
      status: _toInt(m['status']),
      insUser: m['ins_user']?.toString(),
      insDate: _parseDate(m['ins_date']),
      updUser: m['upd_user']?.toString(),
      updDate: _parseDate(m['upd_date']),
      lines: parsedLines,
    );
  }
}

class KassaMedaxilLine {
  final int? idn;
  final String? malName;
  final String? vahid;
  final double? quantity;
  final double? price;
  final double? amount;
  final double? summary;

  KassaMedaxilLine({
    this.idn,
    this.malName,
    this.vahid,
    this.quantity,
    this.price,
    this.amount,
    this.summary,
  });

  factory KassaMedaxilLine.fromMap(Map<String, dynamic> m) => KassaMedaxilLine(
    idn: m['idn'] as int?,
    malName: m['mal_name']?.toString(),
    vahid: m['vahid']?.toString(),
    quantity: (m['quantity'] as num?)?.toDouble(),
    price: (m['price'] as num?)?.toDouble(),
    amount: (m['amount'] as num?)?.toDouble(),
    summary: (m['summary'] as num?)?.toDouble(),
  );
}

// ================== TARİX WIDGET ==================
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
            Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
