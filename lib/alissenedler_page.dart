import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Yaddaş açarı və server parametrləri main.dart-dandır
import 'main.dart' show kSavedPrinterAddrKey;
import 'main.dart' show globalIp, globalPort, globalTermname;

final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

class AlisSenedlerPage extends StatefulWidget {
  const AlisSenedlerPage({super.key});

  @override
  State<AlisSenedlerPage> createState() => _AlisSenedlerPageState();
}

class _AlisSenedlerPageState extends State<AlisSenedlerPage> {
  // ---- UI vəziyyəti ----
  bool _loading = true;
  String? _error;
  List<_AlisHeader> _headers = [];

  // Sətirlər üçün cache
  final Map<int, List<_AlisLine>> _linesCache = {};
  final Map<int, bool> _linesLoading = {};
  final Map<int, String?> _linesError = {};

  // ---- Printer vəziyyəti ----
  BluetoothDevice? _printer;
  bool _btConnecting = false;
  bool _btConnected  = false;

  String? _username;



  @override
  void initState() {
    super.initState();
    _loadHeaders();
    _loadLookups();
    _autoConnectSavedPrinter(); // səhifə açılarkən yaddaşdakı printerə qoşul
  }

  // ===================== DATA =====================

  Future<void> _loadHeaders() async {
    if (globalIp == null || globalPort == null || (globalTermname == null || globalTermname!.isEmpty)) {
      setState(() {
        _loading = false;
        _error = "Server və ya istifadəçi (term_name) tənzimləmələri tapılmadı.";
      });
      return;
    }

    setState(() { _loading = true; _error = null; });

    final url = Uri.parse('http://$globalIp:$globalPort/alissenedi?user=${Uri.encodeComponent(globalTermname!)}');
    try {
      final resp = await http.get(url, headers: {'ngrok-skip-browser-warning': 'true'});
      if (resp.statusCode == 200) {
        final List list = json.decode(resp.body) as List;
        final items = list.map((e) => _AlisHeader.fromMap(e as Map<String, dynamic>)).toList();
        setState(() { _headers = items; _loading = false; });
      } else {
        setState(() {
          _loading = false;
          _error = "Xəta: ${resp.statusCode} ${resp.reasonPhrase}";
        });
      }
    } catch (e) {
      setState(() { _loading = false; _error = "Server xətası: $e"; });
    }
  }


  // UI
  bool _loadingLookups = false;
  String? _lookupError;

  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });

    try {
      final base = await _getBaseUrl();

      final responses = await Future.wait([
        http.get(Uri.parse('$base/user?userId=$globalTermname')).timeout(const Duration(seconds: 15)),
      ]);

      if (responses.any((r) => r.statusCode != 200)) {
        throw Exception('Lookup yüklənmə xətası (status != 200)');
      }

      final userJson = jsonDecode(responses[0].body) as List;

      final users = userJson.map((e) => LookupItem.fromMap(e)).toList();


      setState(() {
        _username = users.isNotEmpty ? users.first.name : null;

      });
    } catch (e) {
      setState(() => _lookupError = e.toString());
    } finally {
      setState(() => _loadingLookups = false);
    }
  }

  Future<String> _getBaseUrl() async {
    if (globalIp == null ||
        globalPort == null ||
        globalIp!.trim().isEmpty ||
        globalPort!.toString().trim().isEmpty) {
      throw Exception('Server IP/Port təyin olunmayıb. Parametrləri yoxlayın.');
    }

    String host = globalIp!.trim();
    String port = globalPort!.toString().trim();

    // 'http://' / 'https://' yazılıbsa təmizlə
    host = host.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');

    // Emulator üçün localhost problemi
    if (host == '127.0.0.1' || host.toLowerCase() == 'localhost') {
      host = '10.0.2.2';
    }

    final base = 'http://$host:$port';
    debugPrint('BASE URL => $base');
    return base;
  }

  BluetoothDevice? _findByAddress(List<BluetoothDevice> list, String addr) {
    try {
      return list.firstWhere((d) => (d.address ?? '') == addr);
    } catch (_) {
      return null; // ✅ firstWhere orElse: null vermək olmaz, ona görə try/catch
    }
  }
  Future<void> _loadLines(int id) async {
    if (_linesCache.containsKey(id)) return; // cache varsa, yükləmə

    _linesLoading[id] = true;
    _linesError[id] = null;
    setState(() {});

    final url = Uri.parse('http://$globalIp:$globalPort/alissenedi/$id/lines');
    try {
      final resp = await http.get(url, headers: {'ngrok-skip-browser-warning': 'true'});
      if (resp.statusCode == 200) {
        final List list = json.decode(resp.body) as List;
        _linesCache[id] = list.map((e) => _AlisLine.fromMap(e as Map<String, dynamic>)).toList();
      } else {
        _linesError[id] = "Xəta: ${resp.statusCode} ${resp.reasonPhrase}";
      }
    } catch (e) {
      _linesError[id] = "Server xətası: $e";
    } finally {
      _linesLoading[id] = false;
      setState(() {});
    }
  }

  String _fmtDate(dynamic v) {
    try {
      final dt = DateTime.parse(v.toString());
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return v?.toString() ?? '';
    }
  }


  // ===================== PRINTER =====================

  // Azərbaycan dilində “ə/Ə” üçün sadə normallaşdırma
  String _azNormalize(String s) => s.replaceAll('ə', 'e').replaceAll('Ə', 'E');

  void _p(String text, {int size = 1, int align = 0}) {
    bluetooth.printCustom(_azNormalize(text), size, align);
  }

  void _plr(String left, String right, {int size = 1}) {
    bluetooth.printLeftRight(_azNormalize(left), _azNormalize(right), size);
  }

  String _money(num? v) => (v ?? 0).toStringAsFixed(2);
  String _qtyStr(num? v) => (v ?? 0).toStringAsFixed(3);

  Future<void> _autoConnectSavedPrinter() async {
    try {
      // 1) cütləşdirilmiş cihazları götür
      final bonded = await bluetooth.getBondedDevices();

      // 2) yaddaşdakı ünvanı tap
      final prefs = await SharedPreferences.getInstance();
      final addr = prefs.getString(kSavedPrinterAddrKey);

      if (addr == null || addr.isEmpty) return; // seçilməyib

      // 3) siyahıda həmin cihazı tap
      final match = _findByAddress(bonded, addr); // BluetoothDevice?
      if (match == null) return;
      _printer = match;
      await bluetooth.connect(match);

      if (match == null) return;

      _printer = match;

      // 4) artıq qoşuludursa, keç
      final isConn = await bluetooth.isConnected ?? false;
      if (isConn) {
        setState(() => _btConnected = true);
        return;
      }

      // 5) qoşul
      if (_btConnecting) return;
      _btConnecting = true;
      await bluetooth.connect(match);
      setState(() => _btConnected = true);
    } catch (e) {
      setState(() => _btConnected = false);
    } finally {
      _btConnecting = false;
    }
  }

  Future<void> _ensurePrinterConnected() async {
    final isConn = await bluetooth.isConnected ?? false;
    if (isConn) return;

    try {
      // Yaddaşdan yükələ
      final prefs = await SharedPreferences.getInstance();
      final addr = prefs.getString(kSavedPrinterAddrKey);
      if (addr == null || addr.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Seçilmiş printer yoxdur. Tənzimləmələr → Bluetooth Printerləri-dən seçin.")),
        );
        return;
      }

      final bonded = await bluetooth.getBondedDevices();
      final match = bonded.firstWhere(
            (d) => (d.address ?? '') == addr,
        orElse: () => throw Exception("Yadda saxlanmış printer tapılmadı"),
      );
      await bluetooth.connect(match);
      setState(() {
        _printer = match;
        _btConnected = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Printerə qoşulma xətası: $e")),
      );
    }
  }

  Future<void> _printAlisSened(_AlisHeader h) async {
    await _ensurePrinterConnected();

    final isConn = await bluetooth.isConnected ?? false;
    if (!isConn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printerə qoşulmaq alınmadı.')),
      );
      return;
    }

    try {
      // Başlıq
      _p("ALIS", size: 3, align: 1);
      _p("----------------------------------------------", align: 1);
      _plr("Sənəd №:", h.senNo);
      _plr("Tarix:", _fmtDate(h.tarix));
      if ((h.kontraName ?? '').isNotEmpty) _plr("Təchizatçı:", h.kontraName!);
      if ((h.qeyd ?? '').isNotEmpty) _p("Qeyd: ${h.qeyd}", size: 0, align: 0);
      _p("----------------------------------------------", align: 1);

      // Sətirləri yüklə / yoxla
      if (!_linesCache.containsKey(h.id)) {
        await _loadLines(h.id);
      }
      final lines = _linesCache[h.id] ?? [];

      double total = 0;
      for (final l in lines) {
        _p(l.malName ?? '', size: 1, align: 0);
        final sol = "${_qtyStr(l.miqdar)} x ${_money(l.qiymet)}";
        final sag = "${_money(l.mebleg)} AZN";
        _plr(sol, sag, size: 1);
        total += (l.mebleg ?? 0);
        bluetooth.printNewLine();
      }

      _p("----------------------------------------------", align: 1);
      final cem = (total > 0 ? total : (h.mebleg ?? 0));
      _plr("CƏM:", "${_money(cem)} AZN", size: 2);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      try { bluetooth.paperCut(); } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Çap göndərildi.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Çap zamanı xəta: $e")),
        );
      }
    }
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alış sənədləri")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
        onRefresh: _loadHeaders,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemBuilder: (ctx, i) {
            final h = _headers[i];
            return Card(
              child: ExpansionTile(
                title: Text("${h.senNo}  —  ${_fmtDate(h.tarix)}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((h.kontraName ?? '').isNotEmpty) Text("Təchizatçı: ${h.kontraName}"),
                    if ((h.qeyd ?? '').isNotEmpty) Text("Qeyd: ${h.qeyd}"),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("${h.mebleg?.toStringAsFixed(2) ?? '0.00'} ₼"),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Çap et',
                      icon: const Icon(Icons.print),
                      onPressed: () => _printAlisSened(h),
                    ),
                  ],
                ),
                onExpansionChanged: (expanded) {
                  if (expanded) _loadLines(h.id);
                },
                children: [
                  if (_linesLoading[h.id] == true)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_linesError[h.id] != null)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(_linesError[h.id]!, style: const TextStyle(color: Colors.red)),
                    )
                  else
                    _buildLinesTable(_linesCache[h.id] ?? []),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: _headers.length,
        ),
      ),
    );
  }

  Widget _buildLinesTable(List<_AlisLine> lines) {
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
          DataColumn(label: Text("Məhsul")),
          DataColumn(label: Text("Miqdar")),
          DataColumn(label: Text("Qiymət")),
          DataColumn(label: Text("Məbləğ")),
        ],
        rows: lines.map((e) {
          return DataRow(
            cells: [
              DataCell(Text(e.malName ?? '')),
              DataCell(Text(e.miqdar?.toStringAsFixed(3) ?? '0')),
              DataCell(Text(e.qiymet?.toStringAsFixed(2) ?? '0.00')),
              DataCell(Text(e.mebleg?.toStringAsFixed(2) ?? '0.00')),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ===================== MODELLƏR =====================

class _AlisHeader {
  final int id;
  final String senNo;
  final dynamic tarix; // serverdən gələn format fərqli ola bilər
  final String? kontraName;
  final String? qeyd;
  final double? mebleg;

  _AlisHeader({
    required this.id,
    required this.senNo,
    required this.tarix,
    this.kontraName,
    this.qeyd,
    this.mebleg,
  });

  factory _AlisHeader.fromMap(Map<String, dynamic> m) => _AlisHeader(
    id: (m['id'] ?? m['idn'] ?? m['es_no'] ?? 0 as num).toInt(),
    senNo: (m['sen_no'] ?? '').toString(),
    tarix: m['tarix'],
    kontraName: (m['kontra_name'] ?? '').toString(),
    qeyd: (m['qeyd'] ?? '').toString(),
    mebleg: m['mebleg'] == null ? null : (m['mebleg'] as num).toDouble(),
  );
}


class LookupItem {
  final int id;
  final String name;
  LookupItem({required this.id, required this.name});

  factory LookupItem.fromMap(Map<String, dynamic> m) => LookupItem(
    id: (m['idn'] as num).toInt(),
    name: (m['adi'] ?? '').toString(),
  );
}

class _AlisLine {
  final String? malName;
  final double? miqdar;
  final double? qiymet;
  final double? mebleg;

  _AlisLine({this.malName, this.miqdar, this.qiymet, this.mebleg});

  factory _AlisLine.fromMap(Map<String, dynamic> m) => _AlisLine(
    malName: (m['mal_name'] ?? '').toString(),
    miqdar: m['miqdar'] == null ? null : (m['miqdar'] as num).toDouble(),
    qiymet: m['qiymet'] == null ? null : (m['qiymet'] as num).toDouble(),
    mebleg: m['mebleg'] == null ? null : (m['mebleg'] as num).toDouble(),
  );
}
