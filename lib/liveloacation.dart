import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'main.dart' show globalIp, globalPort, globalTermname;
import 'dart:math' as Math;

class LiveLocationPage extends StatefulWidget {
  const LiveLocationPage({Key? key}) : super(key: key);

  @override
  _LiveLocationPageState createState() => _LiveLocationPageState();
}

class _LiveLocationPageState extends State<LiveLocationPage> with TickerProviderStateMixin {
  gmaps.GoogleMapController? _mapController;
  Timer? _fetchTimer;

  final Map<gmaps.MarkerId, gmaps.Marker> _markers = {};
  final Map<gmaps.MarkerId, gmaps.Circle> _circles = {};
  final List<fmap.Marker> _fmapMarkers = [];

  double _pulseValue = 0;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _startPulseAnimation();
    _initData();
  }

  void _startPulseAnimation() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (mounted) {
        setState(() {
          _pulseValue = (Math.sin(t.tick / 10) + 1) / 2;
        });
      }
    });
  }

  Future<void> _initData() async {
    await _determinePosition();
    await _fetchEmployees();
    await _fetchClinics();

    _fetchTimer = Timer.periodic(const Duration(seconds: 10), (t) async {
      await _fetchEmployees();
      await _fetchClinics();
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final pos = await Geolocator.getCurrentPosition();
    _updateMyMarker(pos);
  }

  void _updateMyMarker(Position pos) {
    const id = gmaps.MarkerId("me");
    _markers[id] = gmaps.Marker(
      markerId: id,
      position: gmaps.LatLng(pos.latitude, pos.longitude),
      zIndex: 10,
      icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure),
      infoWindow: const gmaps.InfoWindow(title: "Mən"),
    );

    _fmapMarkers.add(
      fmap.Marker(
        point: latlng.LatLng(pos.latitude, pos.longitude),
        width: 40,
        height: 40,
        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
      ),
    );
  }
  String _filterStatus = "Hamısı"; // Hamısı, Online, Offline
  String _searchQuery = "";

  Widget _buildFilterMenu() {
    return Row(
      children: [
        DropdownButton<String>(
          value: _filterStatus,
          items: ["Hamısı", "Online", "Offline"].map((status) {
            return DropdownMenuItem(value: status, child: Text(status));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _filterStatus = value!;
            });
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: "Menecer axtar",
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
          ),
        ),
      ],
    );
  }


  Future<void> _fetchClinics() async {
    if (globalIp == null || globalPort == null) return;
    final host = globalIp!.trim().replaceAll(RegExp(r'^https?://'), '');
    final url = 'http://$host:$globalPort/eraziler';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);

        setState(() {
          for (var item in data) {
            final id = gmaps.MarkerId("erazi_${item['erazi_id']}");
            final lat = double.tryParse(item['latitude'].toString());
            final lng = double.tryParse(item['longitude'].toString());
            final radius = (item['radius'] as num).toDouble();
            if (lat == null || lng == null) continue;

            final pos = gmaps.LatLng(lat, lng);

            _markers[id] = gmaps.Marker(
              markerId: id,
              position: pos,
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
              infoWindow: gmaps.InfoWindow(
                title: item['erazi_adi'],
                snippet: "Radius: $radius m",
              ),
            );

            _circles[id] = gmaps.Circle(
              circleId: gmaps.CircleId("circle_${item['erazi_id']}"),
              center: pos,
              radius: radius,
              fillColor: Colors.red.withOpacity(0.2),
              strokeColor: Colors.red,
              strokeWidth: 2,
            );

            _fmapMarkers.add(
              fmap.Marker(
                point: latlng.LatLng(lat, lng),
                width: 100,
                height: 100,
                child: Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: 60),
                    Text(
                      item['erazi_adi'],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ),
            );

          }
        });
      }
    } catch (e) {
      debugPrint("Clinic API Xətası: $e");
    }
  }

  Future<void> _fetchEmployees() async {
    if (globalIp == null || globalPort == null) return;
    final host = globalIp!.trim().replaceAll(RegExp(r'^https?://'), '');
    final url = 'http://$host:$globalPort/live-locations?userId=$globalTermname';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        await _processEmployees(data);
      }
    } catch (e) {
      debugPrint("API Xətası: $e");
    }
  }

  Future<gmaps.BitmapDescriptor> _createMarkerWithText(
      String text, {
        Color markerColor = Colors.indigo,
      }) async {
    const double size = 150.0;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final String initials = _getInitials(text);

    // Pin forması
    final Paint pinPaint = Paint()..color = markerColor;
    final Path path = Path();
    path.addOval(Rect.fromLTWH(size * 0.2, size * 0.1, size * 0.6, size * 0.6));
    path.moveTo(size * 0.5, size * 0.9);
    path.lineTo(size * 0.32, size * 0.55);
    path.lineTo(size * 0.68, size * 0.55);
    path.close();

    // Kölgə effekti
    canvas.drawPath(
      path.shift(const Offset(2, 2)),
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawPath(path, pinPaint);

    // Daxili ağ dairə
    canvas.drawCircle(
      Offset(size / 2, size * 0.4),
      size * 0.25,
      Paint()..color = Colors.white,
    );

    // Baş hərflər
    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: markerColor,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.18,
        ),
      ),
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size * 0.4) - (textPainter.height / 2)),
    );

    final image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return gmaps.BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }


  Future<void> _processEmployees(List data) async {
    final now = DateTime.now();

    // Əvvəlcə yalnız "me" markerini saxla, qalan əməkdaş markerlərini sil
    _markers.removeWhere((key, value) => key.value != "me");
    _fmapMarkers.clear();

    for (var emp in data) {
      final id = gmaps.MarkerId(emp['id'].toString());
      final lat = double.parse(emp['lat'].toString());
      final lng = double.parse(emp['lng'].toString());
      final newPos = gmaps.LatLng(lat, lng);

      final updatedAt = DateTime.parse(emp['son_yenilenme']);
      final isOnline = now.difference(updatedAt).inMinutes <= 5;

      // Filter və search tətbiqi
      if (_filterStatus == "Online" && !isOnline) continue;
      if (_filterStatus == "Offline" && isOnline) continue;
      if (_searchQuery.isNotEmpty &&
          !emp['ad'].toString().toLowerCase().contains(_searchQuery)) continue;


      final icon = await _createMarkerWithText(
        emp['ad'],
        markerColor: isOnline ? Colors.green : Colors.grey,
      );

      setState(() {
        _markers[id] = gmaps.Marker(
          markerId: id,
          position: newPos,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          infoWindow: gmaps.InfoWindow(
            title: emp['ad'],
            snippet: "Son görülmə: ${DateFormat('dd.MM.yyyy HH:mm').format(updatedAt)}",
          ),
        );


        _fmapMarkers.add(
          fmap.Marker(
            point: latlng.LatLng(lat, lng),
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(emp['ad']),
                    content: Text("Son görülmə: ${DateFormat('dd.MM.yyyy HH:mm').format(updatedAt)}"),
                  ),
                );
              },
              child: Column(
                children: [
                  Icon(Icons.person, color: isOnline ? Colors.green : Colors.grey, size: 50),
                  Text(
                    _getInitials(emp['ad']),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      });
    }
  }


  Future<gmaps.BitmapDescriptor> _createCustomMarker(String name, bool isOnline) async {
    const double size = 150.0;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Color mainColor = isOnline ? Colors.green : Colors.grey.shade600;
    final String initials = _getInitials(name);

    if (isOnline) {
      final Paint pulsePaint = Paint()
        ..color = Colors.green.withOpacity(0.4 * (1 - _pulseValue))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), (size / 2) * (0.6 + (0.4 * _pulseValue)), pulsePaint);
    }

    final Paint pinPaint = Paint()..color = mainColor;
    final Path path = Path();
    path.addOval(Rect.fromLTWH(size * 0.2, size * 0.1, size * 0.6, size * 0.6));
    path.moveTo(size * 0.5, size * 0.9);
    path.lineTo(size * 0.32, size * 0.55);
    path.lineTo(size * 0.68, size * 0.55);
    path.close();
    canvas.drawPath(path, pinPaint);

    canvas.drawCircle(
      Offset(size / 2, size * 0.4),
      size * 0.25,
      Paint()..color = Colors.white,
    );

    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: mainColor,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.18,
        ),
      ),
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size * 0.4) - (textPainter.height / 2)),
    );

    // Status nöqtəsi (sağ aşağıda)
    canvas.drawCircle(
      Offset(size * 0.7, size * 0.25),
      size * 0.07,
      Paint()..color = isOnline ? Colors.lightGreenAccent : Colors.red,
    );
    canvas.drawCircle(
      Offset(size * 0.7, size * 0.25),
      size * 0.07,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Şəkli yaddaşa yazırıq və BitmapDescriptor qaytarırıq
    final image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return gmaps.BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "??";
    List<String> parts = name.trim().split(" ");
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }


  @override
  void dispose() {
    _fetchTimer?.cancel();
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        kIsWeb) {
      // Mobil və Web üçün Google Maps
      return Scaffold(
        appBar: AppBar(
          title: const Text("Canlı İzləmə"),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildFilterMenu(), // filter + search burada görünəcək
            ),
          ),
        ),
        body: gmaps.GoogleMap(
          initialCameraPosition: const gmaps.CameraPosition(
            target: gmaps.LatLng(40.4093, 49.8671),
            zoom: 12,
          ),
          markers: _markers.values.toSet(),
          circles: _circles.values.toSet(),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapType: gmaps.MapType.normal,
          onMapCreated: (c) => _mapController = c,
        ),
      );
    } else {
      // Windows/Linux/macOS üçün Flutter Map
      return Scaffold(
        appBar: AppBar(
          title: const Text("Canlı İzləmə"),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildFilterMenu(),
            ),
          ),
        ),
        body: fmap.FlutterMap(
          options: fmap.MapOptions(
            initialCenter: latlng.LatLng(40.4093, 49.8671),
            initialZoom: 12,
          ),
          children: [
            fmap.TileLayer(
              urlTemplate: "https://api.maptiler.com/maps/streets-v4/{z}/{x}/{y}.png?key=cgs9cMSEOFSYXLByhvEt",
            ),
            fmap.MarkerLayer(markers: _fmapMarkers),
          ],
        ),
      );
    }
  }

}