import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'main.dart' show globalIp, globalPort, globalTermname;

class IseBaslaBitirPage extends StatefulWidget {
  const IseBaslaBitirPage({Key? key}) : super(key: key);

  @override
  State<IseBaslaBitirPage> createState() => _IseBaslaBitirPageState();
}

class _IseBaslaBitirPageState extends State<IseBaslaBitirPage> {
  bool _isLoading = true;
  bool _isWorking = false;
  bool _isInZone = false;
  int? _currentLogId;

  List<dynamic> _allAreas = [];
  List<dynamic> _doctorsInArea = [];
  int? _selectedDoctorId;
  String _selectedDoctorName = "";

  String _currentAreaName = "Axtarılır...";
  String _lastCheckedArea = "";
  StreamSubscription<Position>? _positionStream;

  Timer? _stopwatchTimer;
  Duration _elapsedTime = Duration.zero;
  String _startTimeStr = "--:--";
  String _endTimeStr = "--:--";

  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _stopwatchTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _checkPermissions();
    await _loadData();
    await _checkCurrentStatus();
    _startLocationTracking();
  }

  Future<void> _fetchDoctors(String areaName) async {
    if (areaName == _lastCheckedArea || areaName == "Axtarılır..." || areaName == "Ərazi tapılmadı") return;

    _lastCheckedArea = areaName;
    final host = globalIp!.trim().replaceAll(RegExp(r'^https?://'), '');
    try {
      final url = Uri.parse('http://$host:${globalPort}/hekimler-by-name?erazi_adi=${Uri.encodeComponent(areaName)}');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        setState(() {
          _doctorsInArea = jsonDecode(resp.body);
          // Ərazi dəyişəndə həkimi tam sıfırlayırıq
          _selectedDoctorId = null;
          _selectedDoctorName = "";
        });
      }
    } catch (e) {
      debugPrint("Həkimləri çəkmə xətası: $e");
    }
  }

  Future<void> _checkCurrentStatus() async {
    final host = globalIp!.trim().replaceAll(RegExp(r'^https?://'), '');
    try {
      final url = Uri.parse('http://$host:${globalPort}/check-status?emekdas_id=$globalTermname');
      final resp = await http.get(url);

      if (resp.statusCode == 200 && resp.body != "null") {
        final data = jsonDecode(resp.body);

        // ISO formatda gəldiyi üçün birbaşa parse edirik
        DateTime startTime = DateTime.parse(data['baslama_tarixi']);

        if (mounted) {
          setState(() {
            _currentLogId = data['idn'];
            _isWorking = data['status'] == 'AKTIV';
            _startTimeStr = DateFormat('HH:mm:ss').format(startTime);
            _currentAreaName = data['erazi_adi'] ?? "Axtarılır...";
            _selectedDoctorName = data['hekim_adi'] ?? "";
            _selectedDoctorId = data['hekim_id'];

            // GECİKMƏNİN QARŞISINI ALAN HİSSƏ:
            // Səhifə açılan andakı real fərqi dərhal mənimsədirik
            _elapsedTime = DateTime.now().difference(startTime);

            // Yüklənməni dərhal bitiririk ki, timer görünsün
            _isLoading = false;
          });

          if (_isWorking) {
            _startTimer(startTime);
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Status error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer(DateTime startTime) {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isWorking) {
        setState(() {
          // Hər saniyə cari vaxtla başlama vaxtı arasındakı real fərqi hesablayır
          _elapsedTime = DateTime.now().difference(startTime);
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _sendAction(String type) async {
    final host = globalIp!.trim().replaceAll(RegExp(r'^https?://'), '');
    final urlStr = type == "START" ? 'is-basla' : 'is-bitir';

    try {
      final body = type == "START"
          ? {
        "emekdas_id": globalTermname,
        "erazi_adi": _currentAreaName,
        "hekim_id": _selectedDoctorId
      }
          : {
        "log_id": _currentLogId,
        "qeyd": _noteController.text
      };

      final response = await http.post(
        Uri.parse('http://$host:${globalPort}/$urlStr'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        DateTime now = DateTime.now();
        if (type == "START") {
          final data = jsonDecode(response.body);
          setState(() {
            _currentLogId = data['log_id'];
            _isWorking = true;
            _startTimeStr = DateFormat('HH:mm:ss').format(now);
          });
          _startTimer(now);
        } else {
          // GÖRÜŞ BİTƏNDƏ HƏKİM SEÇİMİNİ SIFIRLAYIRIQ
          setState(() {
            _isWorking = false;
            _stopwatchTimer?.cancel();
            _endTimeStr = DateFormat('HH:mm:ss').format(now);
            _noteController.clear();
            _selectedDoctorId = null;   // ID sıfırlanır
            _selectedDoctorName = "";  // Ad sıfırlanır
          });
        }
      }
    } catch (e) {
      _showMsg("Xəta baş verdi");
    }
  }

  void _showFinishDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Görüşü Bitir", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Görüş haqqında qeydləriniz...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Ləğv et")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendAction("FINISH");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Bitir və Yadda Saxla"),
          ),
        ],
      ),
    );
  }

  void _checkGeofence(Position userPos) {
    bool found = false;
    String name = "Ərazi tapılmadı";
    for (var erazi in _allAreas) {
      double lat = double.parse(erazi['latitude'].toString());
      double lng = double.parse(erazi['longitude'].toString());
      double radius = double.parse(erazi['radius'].toString());
      double distance = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, lat, lng);
      if (distance <= radius) {
        found = true;
        name = erazi['erazi_adi'] ?? "Adsız Ərazi";
        break;
      }
    }
    if (mounted) {
      setState(() {
        _isInZone = found;
        // Əgər işləmirsə, ərazini avtomatik tapsın,
        // amma işə başlayıbsa, ərazi adı sabit qalsın (itmesin).
        if (!_isWorking) {
          _currentAreaName = name;
        }
      });
      if (found && !_isWorking) _fetchDoctors(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Həkim Görüşü", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.indigo.shade900,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildInfoPanel(),
          const SizedBox(height: 20),
          // Ərazidəyəmsə və hazırda bir iş görmürəmsə seçim çıxsın
          if (_isInZone && !_isWorking) _buildDoctorSelector(),
          const SizedBox(height: 20),
          _buildTimerDisplay(),
          const Spacer(),
          _buildControlButtons(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDoctorSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: DropdownButtonFormField<int>(
        decoration: InputDecoration(
          labelText: "Həkim Seçin",
          prefixIcon: const Icon(Icons.person_search, color: Colors.indigo),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          filled: true,
          fillColor: Colors.white,
        ),
        value: _selectedDoctorId,
        items: _doctorsInArea.map((doc) {
          return DropdownMenuItem<int>(
            value: doc['id'],
            child: Text(doc['hekim_adi'], style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
        onChanged: (val) {
          setState(() {
            _selectedDoctorId = val;
            _selectedDoctorName = _doctorsInArea.firstWhere((doc) => doc['id'] == val)['hekim_adi'];
          });
        },
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Text(_currentAreaName.toUpperCase(),
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

          if (_selectedDoctorName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person, color: Colors.amber, size: 18),
                const SizedBox(width: 5),
                Text(
                  _selectedDoctorName,
                  style: GoogleFonts.poppins(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _timeInfo("BAŞLADI", _startTimeStr, Icons.play_circle_outline, Colors.greenAccent),
              _timeInfo("BİTDİ", _endTimeStr, Icons.stop_circle_outlined, Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  // Digər vizual metodlar olduğu kimi qalır...
  Widget _timeInfo(String label, String time, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildTimerDisplay() {
    return Column(
      children: [
        Text("GÖRÜŞ MÜDDƏTİ", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600], letterSpacing: 1.5)),
        Text(
          _formatDuration(_elapsedTime),
          style: GoogleFonts.shareTechMono(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _actionButton(
            title: "GÖRÜŞƏ BAŞLA",
            icon: Icons.play_arrow,
            color: Colors.green.shade600,
            isEnable: _isInZone && !_isWorking && _selectedDoctorId != null,
            onPressed: () => _sendAction("START"),
          ),
          const SizedBox(height: 15),
          _actionButton(
            title: "GÖRÜŞÜ BİTİR",
            icon: Icons.stop,
            color: Colors.red.shade600,
            isEnable: _isWorking,
            onPressed: _showFinishDialog,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  Widget _actionButton({required String title, required IconData icon, required Color color, required bool isEnable, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity, height: 60,
      child: ElevatedButton.icon(
        onPressed: isEnable ? onPressed : null,
        icon: Icon(icon),
        label: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) await Geolocator.requestPermission();
  }

  Future<void> _loadData() async {
    final host = globalIp!.trim().replaceAll(RegExp(r'^https?://'), '');
    try {
      final url = Uri.parse('http://$host:${globalPort}/eraziler');
      final resp = await http.get(url);
      if (resp.statusCode == 200) _allAreas = jsonDecode(resp.body);
    } catch (e) { debugPrint("Data error: $e"); }
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0),
    ).listen((pos) => _checkGeofence(pos));
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}