import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'main.dart' show globalIp, globalPort;
import 'dart:math' as Math;

class Erazi {
  int? eraziId;
  String eraziAdi;
  LatLng merkez;
  double radius;
  late final String _uniqueId;

  Erazi({
    this.eraziId,
    required this.eraziAdi,
    required this.merkez,
    required this.radius,
  }) {
    // Əgər ID varsa ondan, yoxdursa zamandan istifadə edirik ki markerlər qarışmasın
    _uniqueId = eraziId != null
        ? "db_$eraziId"
        : "temp_${DateTime.now().millisecondsSinceEpoch}";
  }

  MarkerId get markerId => MarkerId('marker_$_uniqueId');
  CircleId get circleId => CircleId('circle_$_uniqueId');

  Map<String, dynamic> toJson() => {
    'eraziId': eraziId,
    'eraziAdi': eraziAdi,
    'latitude': merkez.latitude,
    'longitude': merkez.longitude,
    'radius': radius,
  };
}

class EraziTeyinEtmePage extends StatefulWidget {
  const EraziTeyinEtmePage({Key? key}) : super(key: key);

  @override
  State<EraziTeyinEtmePage> createState() => _EraziTeyinEtmePageState();
}

class _EraziTeyinEtmePageState extends State<EraziTeyinEtmePage> {
  String _baseUrl = '';
  bool _isLoading = false;
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  final List<Erazi> _eraziler = [];
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  List<Erazi> _filteredEraziler = [];
  Marker? _myLiveMarker;
  bool _isDirty = false; // Yadda saxla düyməsini idarə etmək üçün

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(40.4093, 49.8671),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _initialize();
  }
  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    _baseUrl = await _getBaseUrl();
    await _loadData(); // Səhifə açılanda datanı gətirir
  }

  Future<String> _getBaseUrl() async {
    String host = globalIp!.trim().replaceAll(RegExp(r'^https?://'), '');
    if (host == '127.0.0.1' || host == 'localhost') host = '10.0.2.2';
    return 'http://$host:${globalPort.toString().trim()}';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/eraziler'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        _eraziler.clear();
        for (var item in data) {
          _eraziler.add(
            Erazi(
              eraziId: item['erazi_id'],
              eraziAdi: item['erazi_adi'],
              merkez: LatLng(item['latitude'], item['longitude']),
              radius: (item['radius'] as num).toDouble(),
            ),
          );
        }

        _filteredEraziler = List.from(_eraziler); // bütün əraziləri göstər
        _updateMarkers(); // xəritəni yenilə
      }
    } catch (e) {
      print("Yükləmə xətası: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // _updateMarkers metodunu belə yeniləyin ki, adlar görünsün
  void _updateMarkers() async {
    _markers.clear();
    _circles.clear();

    for (var era in _filteredEraziler) {
      // Şəkil formasında olan marker ikonu (Adı göstərmək üçün)
      final icon = await _createMarkerWithText(era.eraziAdi);

      _markers.add(
        Marker(
          markerId: era.markerId,
          position: era.merkez,
          icon: icon, // Artıq default marker yox, yazdığınız yazı görünəcək
          infoWindow: InfoWindow(
            title: era.eraziAdi,
            snippet: "Silmək üçün bura klikləyin",
            onTap: () => _confirmDelete(era),
          ),
        ),
      );

      _circles.add(
        Circle(
          circleId: era.circleId,
          center: era.merkez,
          radius: era.radius,
          fillColor: Colors.red.withOpacity(0.2),
          strokeColor: Colors.red,
          strokeWidth: 2,
        ),
      );
    }

    if (_myLiveMarker != null) _markers.add(_myLiveMarker!);
    setState(() {});
  }


  // ================= PROFESSIONAL MARKER (NO PULSE) =================
  // Bu metod əvvəlki dizaynla tam eynidir, lakin pulsing effekti yoxdur.
  // Parametr kimi 'text' (ad) və 'markerColor' (əsas rəng) qəbul edir.
  Future<BitmapDescriptor> _createMarkerWithText(String text, {Color markerColor = Colors.indigo}) async {
    const double size = 150.0; // Marker ölçüsü (digəri ilə eyni)
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Adın baş hərflərini alırıq (getInitials funksiyası əvvəlki kodda var)
    final String initials = _getInitials(text);

    // 1. Xarici Pin Forması (Drop Shape)
    final Paint pinPaint = Paint()..color = markerColor;
    final Path path = Path();
    // Əsas dairəvi hissə
    path.addOval(Rect.fromLTWH(size * 0.2, size * 0.1, size * 0.6, size * 0.6));
    // Alt tərəf iti ucluq (damla forması)
    path.moveTo(size * 0.5, size * 0.9); // Uc nöqtə
    path.lineTo(size * 0.32, size * 0.55); // Sol birləşmə
    path.lineTo(size * 0.68, size * 0.55); // Sağ birləşmə
    path.close();

    // Pin-in kölgəsi (daha peşəkar görünüş üçün yüngül kölgə)
    canvas.drawPath(
        path.shift(const Offset(2, 2)),
        Paint()..color = Colors.black.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
    );

    // Pin-in özünü çəkirik
    canvas.drawPath(path, pinPaint);

    // 2. Daxili Ağ Dairə (Baş hərflərin yazılacağı yer)
    canvas.drawCircle(
      Offset(size / 2, size * 0.4), // Mərkəz
      size * 0.25, // Radius
      Paint()..color = Colors.white,
    );

    // 3. Mətn (Baş hərflər)
    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: markerColor, // Mətnin rəngi pin-in rəngi ilə eyni olsun
          fontWeight: FontWeight.bold,
          fontSize: size * 0.18, // Şrift ölçüsü
        ),
      ),
    )..layout();

    // Mətni ağ dairənin tən ortasına yerləşdiririk
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size * 0.4) - (textPainter.height / 2)),
    );

    // Şəkli yaddaşa yazırıq
    final image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  // Köməkçi metod: Adın baş hərflərini çıxarır (əgər kodunuzda yoxdursa əlavə edin)
  String _getInitials(String name) {
    if (name.isEmpty) return "??";
    List<String> parts = name.trim().split(" ");
    if (parts.length > 1) {
      // Ad və Soyadın baş hərfləri (məs: Əli Vəliyev -> ƏV)
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    // Yalnız adın ilk iki hərfi (məs: Əli -> ƏL) və ya tək hərf
    return parts[0].substring(0, Math.min(2, parts[0].length)).toUpperCase();
  }


  void _onMapLongPress(LatLng pos) {
    _showAddEraziDialog(pos);
  }

  void _showAddEraziDialog(LatLng pos) {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController radiusCtrl = TextEditingController(text: "10");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yeni klinika"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Klinikalar"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: radiusCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Radius (metr)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Ləğv et"),
          ),
          ElevatedButton(
            child: const Text("Əlavə et"),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;

              double radius = double.tryParse(radiusCtrl.text) ?? 10;

              _addEraziToMap(
                Erazi(
                  eraziAdi: nameCtrl.text.trim(),
                  merkez: pos,
                  radius: radius,
                ),
              );

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startLiveLocation() async {
    try {

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) return;

      _positionStream?.cancel();

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
        ),
      ).listen((Position position) {

        final LatLng myPos = LatLng(
          position.latitude,
          position.longitude,
        );

        // Kamera istifadəçini izləsin
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: myPos,
              zoom: 17,
            ),
          ),
        );

      });

    } catch (e) {
      print("Live Location Xətası: $e");
    }
  }

  Future<void> _focusMyLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();

    final LatLng myPos = LatLng(pos.latitude, pos.longitude);

    // Xəritəni fokusla
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: myPos,
          zoom: 17,
        ),
      ),
    );

    // Marker əlavə et
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == "my_location");

      _markers.add(
        Marker(
          markerId: const MarkerId("my_location"),
          position: myPos,
          infoWindow: const InfoWindow(title: "Mənim mövqeyim"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });
  }

  void _filterEraziler(String query) {
    if (query.isEmpty) {
      _filteredEraziler = List.from(_eraziler);
    } else {
      _filteredEraziler = _eraziler
          .where((e) => e.eraziAdi.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    _updateMarkers();
  }
  void _addEraziToMap(Erazi era) async {
    final icon = await _createMarkerWithText(era.eraziAdi);

    setState(() {
      _eraziler.add(era);
      _filteredEraziler.add(era); // Axtarış listinə də əlavə et
      _isDirty = true; // Düyməni göstər

      _markers.add(
        Marker(
          markerId: era.markerId,
          position: era.merkez,
          icon: icon,
        ),
      );
      // ... circle əlavə etmə hissəsi eyni qalır
    });
  }


  void _addEraziToMapFiltered(Erazi era) async {
    final icon = await _createMarkerWithText(era.eraziAdi);

    _markers.add(
      Marker(
        markerId: era.markerId,
        position: era.merkez,
        icon: icon,
      ),
    );

    _circles.add(
      Circle(
        circleId: era.circleId,
        center: era.merkez,
        radius: era.radius,
        fillColor: Colors.blue.withOpacity(0.2),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      ),
    );
  }


  // Silməzdən əvvəl təsdiq sorğusu (Confirm Dialog)
  void _confirmDelete(Erazi era) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ərazini sil"),
        content: Text("'${era.eraziAdi}' ərazisini silmək istədiyinizə əminsiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Xeyr"),
          ),
          TextButton(
            onPressed: () {
              _deleteErazi(era);
              Navigator.pop(context);
            },
            child: const Text("Bəli, sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteErazi(Erazi era) {
    setState(() {
      _eraziler.remove(era);
      _markers.removeWhere((m) => m.markerId == era.markerId);
      _circles.removeWhere((c) => c.circleId == era.circleId);
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/save-eraziler'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'eraziler': _eraziler.map((e) => e.toJson()).toList()}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uğurla yadda saxlanıldı"), backgroundColor: Colors.green));
        _loadData(); // ID-ləri sinxronlaşdırmaq üçün yenidən yükləyirik
      }
    } catch (e) {
      print("Xəta: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Klinikalar"), backgroundColor: Colors.red),
      body: Stack(



        children: [

          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (c) => _mapController = c,
            onLongPress: _onMapLongPress,
            markers: _markers,
            circles: _circles,

            // BURANI ƏLAVƏ ET
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),

          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: TextField(
                onChanged: (value) => _filterEraziler(value),
                decoration: const InputDecoration(
                  hintText: "Klinikanın adını axtar",
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                ),
              ),
            ),
          ),
          Positioned(
            top: 90,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _startLiveLocation,
              child: const Icon(Icons.gps_fixed, color: Colors.black),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Visibility(
              visible: _isDirty, // Yalnız nəsə əlavə olunanda və ya dəyişəndə görünür
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                  backgroundColor: Colors.green, // Rəngi seçilən olsun
                ),
                onPressed: _isLoading
                    ? null
                    : () async {
                  await _saveChanges();
                  setState(() => _isDirty = false); // Saxlanıldıqdan sonra gizlət
                },
                child: const Text("Yadda saxla", style: TextStyle(color: Colors.white)),
              ),
            ),
          )
        ],
      ),
    );
  }
}