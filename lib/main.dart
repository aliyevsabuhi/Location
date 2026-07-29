import 'dart:async'; // Time
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:aliyev_apk/HekimAddPage.dart';
import 'package:aliyev_apk/balanshes.dart';
import 'package:aliyev_apk/bankhes.dart';
import 'package:aliyev_apk/gonderilendoc.dart';
import 'package:aliyev_apk/hekimler.dart';
import 'package:aliyev_apk/kassamedaxil.dart';
import 'package:aliyev_apk/kassamedsenedler_page.dart';
import 'package:aliyev_apk/liveloacation.dart';
import 'package:aliyev_apk/malgonder.dart';
import 'package:aliyev_apk/malingonderilmesi.dart';
import 'package:aliyev_apk/malqaliqlari.dart';
import 'package:aliyev_apk/mushes.dart';
import 'package:aliyev_apk/reportspage.dart';
import 'package:aliyev_apk/satis.dart';
import 'package:aliyev_apk/satishes.dart';
import 'package:aliyev_apk/satissenedler_page.dart';
import 'package:aliyev_apk/sifaris.dart';
import 'package:aliyev_apk/sifarissenedler_page.dart';
import 'package:aliyev_apk/telebname.dart';
import 'package:aliyev_apk/telebnameler.dart';
import 'package:aliyev_apk/telebnamesenedler_page.dart';
import 'package:aliyev_apk/terminal.dart';
import 'package:aliyev_apk/transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Bluetooth printer paketi
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

import 'alis.dart';
import 'alissenedler_page.dart';
import 'balansheanbs.dart';
import 'change_log_page.dart';
import 'emekdas.dart';
import 'erazi_teyin_etme_page.dart';
import 'geri.dart';
import 'jobstart.dart';
import 'kassahes.dart';
import 'kassamexaric.dart';
import 'kassamexsenedler_page.dart';
import 'lock_screen.dart';
import 'qiymetyoxla.dart'; // fayl yolunuza görə düzəldin

// Yaddaş açarları
const String kSavedPrinterNameKey = 'saved_printer_name';
const String kSavedPrinterAddrKey = 'saved_printer_address';

bool _hasNewVersion = false;
String currentVersion = "1.0.7";

String? globalUserId;

String? globalIp = '188.213.212.55';   // default
String? globalPort = '3003';           // default


Future<void> _savePreferredPrinter(BluetoothDevice dev) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kSavedPrinterNameKey, dev.name ?? '');
  await prefs.setString(kSavedPrinterAddrKey, dev.address ?? '');
}

Future<BluetoothDevice?> _loadPreferredPrinter(List<BluetoothDevice> bonded) async {
  final prefs = await SharedPreferences.getInstance();
  final addr = prefs.getString(kSavedPrinterAddrKey);
  if (addr == null || addr.isEmpty) return null;
  try {
    return bonded.firstWhere((d) => (d.address ?? '') == addr);
  } catch (_) {
    return null;
  }
}




String? globalTermpass;//='111111';  // ilkin dəyər (default)
String? globalTermname;//='0';  // ilkin dəyər (default)
String? globalUsername;//='';  // ilkin dəyər (default)

String? globalceki='27';
String? globaleded='20';



bool globalAllowDateChange = false;
List<String> _allowedPages = [];
Timer? _countsTimer; // _logout funksiyası üçün əlçatan olmalıdır


void main() async {
  WidgetsFlutterBinding.ensureInitialized();



  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    if (Platform.isAndroid) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    await initializeService();
  }

  final prefs = await SharedPreferences.getInstance();

  globalUserId = prefs.getString('logged_in_user_idn');
  globalIp = prefs.getString('term_ip') ?? globalIp;
  globalPort = prefs.getString('term_port') ?? globalPort;

  runApp(MyApp(
    autoLoginUserId: globalUserId,
    autoLoginUserName: prefs.getString('logged_in_user_name'),
    autoLoginUserRole: prefs.getString('logged_in_user_role'),
  ));
}





Future<void> initializeService() async {

  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel =
  AndroidNotificationChannel(
    'location_channel',
    'Canlı İzləmə',
    description: 'Location tracking',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(

    androidConfiguration: AndroidConfiguration(

      onStart: onStart,

      autoStart: true,

      autoStartOnBoot: true,

      isForegroundMode: true,

      notificationChannelId: 'location_channel',

      initialNotificationTitle: 'Soffen Mobile',

      initialNotificationContent:
      'Canlı izləmə aktivdir',

      foregroundServiceNotificationId: 999,

      foregroundServiceTypes: [
        AndroidForegroundType.location,
      ],

    ),

    iosConfiguration: IosConfiguration(),

  );

  service.startService();

}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {

  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  Timer.periodic(const Duration(seconds: 15), (timer) async {

    try {

      final String ip ='188.213.212.55';

      final String port ='3003';

      final String? userId =
      prefs.getString('logged_in_user_idn');

      print("BACKGROUND USERID: $userId");

      if (ip == null ||
          port == null ||
          userId == null) {

        print("CONFIG NULL");
        return;
      }

      Position position =
      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url =
      Uri.parse('http://$ip:$port/update-location');

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "emekdas_id": userId,
          "lat": position.latitude,
          "lng": position.longitude,
          "time": DateTime.now().toIso8601String(),
        }),
      );

      print("STATUS CODE: ${response.statusCode}");

    } catch (e) {

      print("BACKGROUND ERROR: $e");

    }

  });

}


Future<bool> _checkIfPasswordIsSet() async {
  final prefs = await SharedPreferences.getInstance();
  final String? termPass = prefs.getString('term_pass');
  return termPass != null && termPass.isNotEmpty;
}



void startLiveLocationTracking() {
  Timer.periodic(const Duration(seconds: 3), (timer) async {
    try {
      // 1. Mövqeyi al
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );

      final prefs = await SharedPreferences.getInstance();
      String? ip = prefs.getString('term_ip') ?? globalIp;
      String? port = prefs.getString('term_port') ?? globalPort;
      String? userId = prefs.getString('logged_in_user_idn');

      if (ip != null && userId != null) {
        final url = Uri.parse('http://$ip:$port/update-location');

        await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "emekdas_id": userId,
            "lat": position.latitude,
            "lng": position.longitude,
            "time": DateTime.now().toIso8601String(),
          }),
        ).timeout(const Duration(seconds: 5));

        debugPrint("Məkan uğurla göndərildi: ${position.latitude} ${position.longitude}");
      }
    } catch (e) {
      debugPrint("Live Location Xətası: $e");
    }
  });
}

Future<void> _loadInitialData() async {
  final prefs = await SharedPreferences.getInstance();
  globalceki = prefs.getString('term_ceki');
  globaleded = prefs.getString('term_eded');
  await Future.delayed(const Duration(milliseconds: 500));
}

class SplashScreenApp extends StatelessWidget {
  const SplashScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.deepPurple,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpinKitFadingCircle(color: Colors.white, size: 50.0),
              const SizedBox(height: 20),
              Text(
                'Soffen Mobile Yüklənir...',
                style: GoogleFonts.poppins(
                    fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// MyApp class-ı eyni qalır
class MyApp extends StatelessWidget {

  final String? autoLoginUserId;
  final String? autoLoginUserName;
  final String? autoLoginUserRole;

  const MyApp({
    super.key,
    this.autoLoginUserId,
    this.autoLoginUserName,
    this.autoLoginUserRole,
  });

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Soffen Mobile',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),

      home: FutureBuilder(
        future: Future.delayed(const Duration(milliseconds: 800)),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreenApp();
          }

          /// ƏGƏR LOGIN VARSA
          if (autoLoginUserId != null && autoLoginUserId!.isNotEmpty) {

            return AnaSehife(
              userIdn: autoLoginUserId!,
              userName: autoLoginUserName ?? "İstifadəçi",
              userRol: autoLoginUserRole ?? "",
            );

          }

          /// ƏKS HALDA LOCK SCREEN
          return const LockScreenPage();

        },
      ),
    );
  }
}

class AnaSehife extends StatefulWidget {
  final String userIdn;
  final String userName;
  final String userRol;

  const AnaSehife({super.key, required this.userIdn, required this.userName, required this.userRol});

  @override
  State<AnaSehife> createState() => _AnaSehifeState();
}

class _AnaSehifeState extends State<AnaSehife> {
  String? _lastUpdated;
  int _sif = 0, _sift = 0, _sat = 0, _satt = 0, _kmd = 0, _kmx = 0, _qolan = 0, _qolmayan = 0, _tqebul = 0, _tgozleme = 0;

  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _bluetoothDevices = [];
  BluetoothDevice? _selectedBluetoothDevice;
  bool _isBluetoothConnected = false;
  bool _isLoadingBluetoothAction = false;
  String _userRol = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runInitialSetup();
    });
  }

  @override
  void dispose() {
    _countsTimer?.cancel();
    super.dispose();
  }

  Future<void> _runInitialSetup() async {
    // Əvvəlcə istifadəçi və icazə məlumatlarını arxa fonda yükləyirik
    await _loadUserNameAndPermissions();

    // Bluetooth və digər tənzimləmələri edirik
    _initBluetoothAndPermissions();
    _initAutoConnect();

    // Periodik yoxlamaları başladırıq
    _startPeriodicCountUpdates();

    // === ƏSAS MƏNTİQ: Versiya yoxlaması və ya məlumat yükləmə ===
    // Bu funksiya ya yeniləmə pəncərəsi göstərəcək, ya da məlumatları yükləyəcək.
    await _checkVersionAndDownloadDataIfNeeded();

    var status = await Permission.location.status;
    if (status.isGranted) {
      startLiveLocationTracking();
    }

  }

  Future<void> _logout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Çıxış'),
          content: const Text('Hesabdan çıxmaq istədiyinizə əminsiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Xeyr'),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Bəli, Çıxış et'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    _countsTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_user_idn');
    await prefs.remove('logged_in_user_name');
    await prefs.remove('logged_in_user_role');

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LockScreenPage()),
            (Route<dynamic> route) => false,
      );
    }
  }


  Future<void> _loadUserNameAndPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final storedName = prefs.getString('logged_in_user_name') ?? 'İstifadəçi';
    final storedRolId = prefs.getString('logged_in_user_role') ?? '';

    String roleName = 'Vəzifə';
    if (storedRolId.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse('http://$globalIp:$globalPort/api/role/$storedRolId'));
        if (response.statusCode == 200) {
          roleName = jsonDecode(response.body)['name'] ?? 'Vəzifə';
        }
      } catch (e) {
        print('Rol yüklənərkən xəta: $e');
      }
    }

    if (mounted) {
      setState(() => _userRol = roleName);
      await _loadRolePermissions(roleName);
    }
  }

  Future<void> _loadRolePermissions(String roleName) async {
    if (roleName.isEmpty || roleName == 'Vəzifə') {
      if (mounted) setState(() => _allowedPages = []);
      return;
    }
    try {
      final response = await http.get(Uri.parse('http://$globalIp:$globalPort/api/roles/$roleName'));
      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _allowedPages = List<String>.from(jsonDecode(response.body).map((e) => e['page_name'].toString().trim().toLowerCase()));
          });
          print("Yenilənmiş icazələr: $_allowedPages");
        } else {
          setState(() => _allowedPages = []);
        }
      }
    } catch (e) {
      print('Rol icazələrini yükləyərkən xəta: $e');
      if (mounted) setState(() => _allowedPages = []);
    }
  }

  Future<void> _checkVersionAndDownloadDataIfNeeded() async {
    bool newVersionFound = false;
    try {
      final url = Uri.parse("http://$globalIp:$globalPort/version");
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty && data.first["version"] != currentVersion) {
          newVersionFound = true;

          if (mounted) {
            setState(() => _hasNewVersion = true);

            // İstifadəçi heç nə etmədən update səhifəsinə keç
            Navigator.of(context, rootNavigator: true).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const ChangeLogPage(),
              ),
            );
          }

          return; // burdan sonra heç nə işləməsin
        }

      }
    } catch (e) {
      print("Versiya yoxlaması zamanı xəta: $e");
    }

    /*if (!newVersionFound && mounted) {
      await _showProgressDialog(_downloadMallar);
    }*/
  }


  void _startPeriodicCountUpdates() {
    _fetchOrderCounts();
    _countsTimer?.cancel();
    _countsTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchOrderCounts());
  }

  Future<void> _initAutoConnect() async {
    try {
      _bluetoothDevices = await bluetooth.getBondedDevices();
      final saved = await _loadPreferredPrinter(_bluetoothDevices);
      if (saved != null) {
        setState(() => _selectedBluetoothDevice = saved);
        await _connectToBluetoothDevice(saved);
      }
    } catch (_) {}
  }

  Future<void> _initBluetoothAndPermissions() async {
    if (await bluetooth.isAvailable == true) {
      _getPairedBluetoothDevices();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bluetooth aktiv deyil.")));
    }
  }

  Future<void> _getPairedBluetoothDevices() async {
    if (!mounted) return;
    setState(() => _isLoadingBluetoothAction = true);
    try {
      _bluetoothDevices = await bluetooth.getBondedDevices();
    } catch (e) {
      debugPrint("Bluetooth cihazlarını alarkən xəta: $e");
    } finally {
      if (mounted) setState(() => _isLoadingBluetoothAction = false);
    }
  }

  Future<void> _connectToBluetoothDevice(BluetoothDevice device) async {
    if (_isBluetoothConnected && _selectedBluetoothDevice?.address == device.address) return;
    if (_isBluetoothConnected) await _disconnectFromBluetoothDevice();
    if (!mounted) return;
    setState(() => _isLoadingBluetoothAction = true);
    try {
      await bluetooth.connect(device);
      if (mounted) {
        setState(() {
          _selectedBluetoothDevice = device;
          _isBluetoothConnected = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${device.name ?? 'Cihaz'}-a qoşuldu.")));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cihaza qoşularkən xəta: $e")));
    } finally {
      if(mounted) setState(() => _isLoadingBluetoothAction = false);
    }
  }

  Future<void> _disconnectFromBluetoothDevice() async {
    if(!mounted) return;
    setState(() => _isLoadingBluetoothAction = true);
    try {
      await bluetooth.disconnect();
      if (mounted) {
        setState(() {
          _isBluetoothConnected = false;
          _selectedBluetoothDevice = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cihazdan ayrıldı.")));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cihazdan ayrılarkən xəta: $e")));
    } finally {
      if(mounted) setState(() => _isLoadingBluetoothAction = false);
    }
  }

  Future<void> _showBluetoothDeviceListDialog() async {
    final ok = await _ensureBtPermissions();
    if (!ok) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bluetooth icazələri verilməyib')));
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool localLoading = true;
        List<BluetoothDevice> localDevices = [];
        String? localError;

        Future<void> loadDevicesOnce(StateSetter s) async {
          s(() {
            localLoading = true;
            localError = null;
          });
          try {
            if (await bluetooth.isOn != true) {
              throw Exception("Bluetooth söndürülüb.");
            }
            localDevices = await bluetooth.getBondedDevices().timeout(const Duration(seconds: 5));
          } catch (e) {
            localError = "Cihazları oxuyarkən xəta: $e";
          } finally {
            s(() => localLoading = false);
          }
        }

        return StatefulBuilder(builder: (stfCtx, stfSetState) {
          if(localLoading && localDevices.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => loadDevicesOnce(stfSetState));
          }

          return AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text("Bluetooth Printer Seçin")),
                IconButton(
                  tooltip: 'Yenilə',
                  onPressed: localLoading ? null : () => loadDevicesOnce(stfSetState),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: localLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (localError != null)
                  ? Center(child: Text(localError!, textAlign: TextAlign.center))
                  : (localDevices.isEmpty)
                  ? const Center(child: Text("Cütləşdirilmiş cihaz tapılmadı.", textAlign: TextAlign.center))
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: localDevices.length,
                itemBuilder: (context, index) {
                  final device = localDevices[index];
                  final isSelected = _selectedBluetoothDevice?.address == device.address;
                  return ListTile(
                    leading: Icon(Icons.print_outlined, color: (isSelected && _isBluetoothConnected) ? Colors.green : null),
                    title: Text(device.name ?? "Naməlum cihaz"),
                    subtitle: Text(device.address ?? "Ünvan yoxdur"),
                    selected: isSelected && _isBluetoothConnected,
                    selectedTileColor: Colors.green.withOpacity(0.1),
                    onTap: () async {
                      Navigator.of(dialogContext).pop();
                      if (mounted) setState(() => _selectedBluetoothDevice = device);
                      await _savePreferredPrinter(device);
                      await _connectToBluetoothDevice(device);
                    },
                    trailing: (isSelected && _isBluetoothConnected) ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  );
                },
              ),
            ),
            actions: <Widget>[
              if (_isBluetoothConnected && _selectedBluetoothDevice != null)
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _disconnectFromBluetoothDevice();
                  },
                  child: const Text("AYRIL", style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("BAĞLA"),
              ),
            ],
          );
        });
      },
    );
  }

  Future<bool> _ensureBtPermissions() async {
    if (!Platform.isAndroid) return true;
    final connect = await Permission.bluetoothConnect.request();
    final scan = await Permission.bluetoothScan.request();
    return connect.isGranted && scan.isGranted;
  }

  Future<void> _fetchOrderCounts() async {
    try {
      final base = 'http://$globalIp:$globalPort';
      final url = Uri.parse('$base/counts?userId=$globalTermname');
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final counts = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _sif = counts['sif'] ?? 0;
            _sift = counts['sift'] ?? 0;
            _sat = counts['sat'] ?? 0;
            _satt = counts['satt'] ?? 0;
            _kmd = counts['kmd'] ?? 0;
            _kmx = counts['kmx'] ?? 0;
            _qolan = counts['qebulolanlar'] ?? 0;
            _qolmayan = counts['qebulolmayanlar'] ?? 0;
            _tqebul = counts['tqebul'] ?? 0;
            _tgozleme = counts['tgozleme'] ?? 0;
          });
        }
      }
    } catch (e) {
      print("Sifariş sayları alına bilmədi: $e");
      if (mounted) {
        setState(() { _sif=0; _sift=0; _sat=0; _satt=0; _kmd=0; _kmx=0; _qolan=0; _qolmayan=0; });
      }
    }
  }

  List<_MenuCategory> _buildMenuCategories() {
    List<_MenuItem> emeliyyatlarItems = [];
    List<_MenuItem> hesabatlarItems = [];
    List<_MenuItem> tenzimlemelerItems = [];

    if (_allowedPages.contains("sifariş")) emeliyyatlarItems.add(_MenuItem("Sifariş", Icons.receipt_long_outlined, Colors.pinkAccent, docsRoute: '/alis/senedler', badgeCount1: _sif, badgeCount2: _sift));
    if (_allowedPages.contains("satış")) emeliyyatlarItems.add(_MenuItem("Satış", Icons.shopping_bag, Colors.pinkAccent, docsRoute: '/satis/senedler', badgeCount1: _sat, badgeCount2: _satt));
    if (_allowedPages.contains("qaytarma")) emeliyyatlarItems.add(_MenuItem("Qaytarma", Icons.shopping_cart_checkout_rounded, Colors.pinkAccent, docsRoute: '/qaytarma/senedler'));
    if (_allowedPages.contains("transfer")) emeliyyatlarItems.add(_MenuItem("Transfer", Icons.compare_arrows, Colors.cyan, docsRoute: '/transfer/senedler'));
    if (_allowedPages.contains("tələbnamə")) emeliyyatlarItems.add(_MenuItem("Tələbnamə", Icons.star_sharp, Colors.blueGrey, docsRoute: '/telebname/senedler', badgeCount1: _qolmayan, badgeCount2: _qolan));
    if (_allowedPages.contains("malın qəbulu")) emeliyyatlarItems.add(_MenuItem("Malın qəbulu", Icons.approval_rounded, Colors.black45, docsRoute: '/malin qebulu/senedler' , badgeCount1: _tgozleme, badgeCount2: _tqebul));
    if (_allowedPages.contains("mədaxil")) emeliyyatlarItems.add(_MenuItem("Kassa mədaxil", Icons.monetization_on_outlined, Colors.green, docsRoute: '/kassa/medaxil/senedler', badgeCount2: _kmd));
    if (_allowedPages.contains("məxaric")) emeliyyatlarItems.add(_MenuItem("Kassa məxaric", Icons.monetization_on_outlined, Colors.deepOrange, docsRoute: '/kassa/mexaric/senedler', badgeCount2: _kmx));
    if (_allowedPages.contains("mal qalıqları")) hesabatlarItems.add(_MenuItem("Mal qalıqları", Icons.warehouse, Colors.indigo));
    if (_allowedPages.contains("balans hesabatı")) hesabatlarItems.add(_MenuItem("Balans hesabatı", Icons.show_chart, Colors.green));
    if (_allowedPages.contains("balans hesabatı(anbardar)")) hesabatlarItems.add(_MenuItem("Balans hesabatı(Anbardar)", Icons.money_rounded, Colors.green));
    if (_allowedPages.contains("kassa hesabatı")) hesabatlarItems.add(_MenuItem("Kassa hesabatı", Icons.money_rounded, Colors.green));
    if (_allowedPages.contains("bank hesabatı")) hesabatlarItems.add(_MenuItem("Bank hesabatı", Icons.credit_card, Colors.blue));
    if (_allowedPages.contains("müştəri satış hesabatı")) hesabatlarItems.add(_MenuItem("Müştəri satış hesabatı", Icons.people_rounded, Colors.purple));
    if (_allowedPages.contains("ərazi təyini")) tenzimlemelerItems.add(_MenuItem("Klinikalar", Icons.local_hospital, Colors.red));
    if (_allowedPages.contains("əməkdaşlar")) tenzimlemelerItems.add(_MenuItem("Əməkdaşlar", Icons.perm_contact_cal_rounded, Colors.black12));
    if (_allowedPages.contains("həkimlər")) tenzimlemelerItems.add(_MenuItem("Həkimlər", Icons.person, Colors.blue));
    //if (_allowedPages.contains("həkimlər")) tenzimlemelerItems.add(_MenuItem("Bütün həkimlər", Icons.perm_contact_cal, Colors.redAccent));
    if (_allowedPages.contains("iş vaxtı")) tenzimlemelerItems.add(_MenuItem("Həkim görüşü", Icons.timer_outlined, Colors.redAccent));
    if (_allowedPages.contains("davamiyyət")) tenzimlemelerItems.add(_MenuItem("Ziyarətləri yoxla", Icons.view_timeline_outlined, Colors.blue));
    if (_allowedPages.contains("canlı izlə")) tenzimlemelerItems.add(_MenuItem("Menecerləri izlə", Icons.location_history, Colors.redAccent));
    List<_MenuCategory> categories = [];
    if (emeliyyatlarItems.isNotEmpty) categories.add(_MenuCategory("Əməliyyatlar", Icons.widgets, emeliyyatlarItems));
    if (hesabatlarItems.isNotEmpty) categories.add(_MenuCategory("Hesabatlar", Icons.bar_chart, hesabatlarItems));
    if (tenzimlemelerItems.isNotEmpty) categories.add(_MenuCategory("Davamiyyət", Icons.work_history, tenzimlemelerItems));

    /*categories.add(
      _MenuCategory("Tənzimləmələr", Icons.settings, [
        _MenuItem("Bluetooth Printerləri", Icons.print, Colors.blue),
      ]),
    );
    */

    return categories;
  }

  Future<void> _showProgressDialog(Future<void> Function() task) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SpinKitFadingCircle(color: Colors.deepPurple, size: 50.0),
              const SizedBox(height: 20),
              Text("Zəhmət olmasa gözləyin...", style: GoogleFonts.poppins(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
    try {
      await task();
    } finally {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _downloadMallar() async {
    final url = Uri.parse('http://$globalIp:$globalPort/mallar');
    try {
      final resp = await http.get(url, headers: {'ngrok-skip-browser-warning': 'true'});
      if (resp.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mallar_data', resp.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Məlumatlar uğurla yeniləndi.")));
        await _saveLastUpdatedDate();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Məlumatlar yüklənərkən xəta: ${resp.statusCode}")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Serverə qoşulma xətası: $e")));
    }
  }

  Future<void> _saveLastUpdatedDate() async {
    final prefs = await SharedPreferences.getInstance();
    final formattedDate = DateFormat('dd.MM.yyyy HH:mm:ss').format(DateTime.now());
    await prefs.setString('last_updated_date', formattedDate);
    if (mounted) setState(() => _lastUpdated = formattedDate);
  }

  @override
  Widget build(BuildContext context) {
    final menuCategories = _buildMenuCategories();
    globalTermname = widget.userIdn;
    globalUsername = widget.userName;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Xoş gəldin\n'
              '${widget.userName}',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Hesabdan çıx',
          icon: const Icon(Icons.logout, color: Colors.red),
          onPressed: _logout,
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.black87),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeLogPage())),
              ),
              if (_hasNewVersion)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),

        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: menuCategories.length,
              itemBuilder: (context, index) {
                final category = menuCategories[index];
                if (category.items.isEmpty) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    leading: Icon(category.icon, color: Colors.deepPurple),
                    title: Text(category.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    children: category.items.map((item) {
                      return Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: () {
                            if (item.title == "Sifariş") Navigator.push(context, MaterialPageRoute(builder: (_) => const SifarisPage()));
                            else if (item.title == "Satış") Navigator.push(context, MaterialPageRoute(builder: (_) => const SatisPage()));
                            else if (item.title == "Qaytarma") Navigator.push(context, MaterialPageRoute(builder: (_) => const GeriPage()));
                            else if (item.title == "Transfer") Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferPage()));
                            else if (item.title == "Tələbnamə") Navigator.push(context, MaterialPageRoute(builder: (_) => const TelebnamePage()));
                            else if (item.title == "Malın qəbulu") Navigator.push(context, MaterialPageRoute(builder: (_) => const GonderilenlerdocPage()));
                            else if (item.title == "Kassa mədaxil") Navigator.push(context, MaterialPageRoute(builder: (_) => const KassaMedaxilPage()));
                            else if (item.title == "Kassa məxaric") Navigator.push(context, MaterialPageRoute(builder: (_) => const KassaMexaricPage()));
                            else if (item.title == "Mal qalıqları") Navigator.push(context, MaterialPageRoute(builder: (_) => const MalqaliqlarihesPage()));
                            else if (item.title == "Balans hesabatı") Navigator.push(context, MaterialPageRoute(builder: (_) => const BalanshesPage()));
                            else if (item.title == "Balans hesabatı(Anbardar)") Navigator.push(context, MaterialPageRoute(builder: (_) => const BalanshesanbPage()));
                            else if (item.title == "Kassa hesabatı") Navigator.push(context, MaterialPageRoute(builder: (_) => const KassaHesabatiPage()));
                            else if (item.title == "Bank hesabatı") Navigator.push(context, MaterialPageRoute(builder: (_) => const BankHesabatiPage()));
                            else if (item.title == "Müştəri satış hesabatı") Navigator.push(context, MaterialPageRoute(builder: (_) => const MusteriHesabatiPage()));
                            else if (item.title == "Klinikalar")
                            {
                              startLiveLocationTracking();
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => const EraziTeyinEtmePage()));}
                            else if (item.title == "Əməkdaşlar")
                            {
                              startLiveLocationTracking();
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => EmekdasAddPage()));
                            }
                            else if (item.title == "Həkimlər")
                            {
                              startLiveLocationTracking();
                              Navigator.push(context, MaterialPageRoute(
                               builder: (_) => const HekimAddPage()));
                            }
                            else if (item.title == "Həkim görüşü")
                            {
                              startLiveLocationTracking();
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => const IseBaslaBitirPage()));}
                            else if (item.title == "Ziyarətləri yoxla")
                            {
                              startLiveLocationTracking();
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ReportsPage()));
                            }
                            else if (item.title == "Menecerləri izlə")
                            {
                              startLiveLocationTracking();
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => LiveLocationPage()));
                            }
                            else if (item.title == "Bluetooth Printerləri") _showBluetoothDeviceListDialog();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                Icon(item.icon, color: item.color, size: 28),
                                const SizedBox(width: 16),
                                Expanded(child: Text(item.title, style: const TextStyle(fontSize: 16))),
                                _buildTrailingWithBadges(context, item),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          if (_lastUpdated != null && _lastUpdated!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0, top: 8.0),
              child: Text("Son yenilənmə: $_lastUpdated", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailingWithBadges(BuildContext context, _MenuItem item) {
    final String? route = item.docsRoute;
    final bool hasBadges = (item.badgeCount1 ?? 0) > 0 || (item.badgeCount2 ?? 0) > 0;

    if (route == null && !hasBadges) {
      return const SizedBox(width: 48);
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (route != null)
          IconButton(
            tooltip: 'Sənədlər',
            icon: const Icon(Icons.list_alt),
            onPressed: () => Navigator.pushNamed(context, route),
          )
        else
          const SizedBox(width: 48),

        if ((item.badgeCount1 ?? 0) > 0)
          Positioned(
            top: 4, left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(item.badgeCount1.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),

        if ((item.badgeCount2 ?? 0) > 0)
          Positioned(
            top: 4, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(item.badgeCount2.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}

class _MenuCategory {
  final String title;
  final IconData icon;
  final List<_MenuItem> items;
  _MenuCategory(this.title, this.icon, this.items);
}

class _MenuItem {
  final String title;
  final IconData? icon;
  final Color? color;
  final String? docsRoute;
  final int? badgeCount1;
  final int? badgeCount2;
  final String? iconPath;

  const _MenuItem(this.title, this.icon, this.color, {this.docsRoute, this.badgeCount1, this.badgeCount2, this.iconPath});
}

class AltSehife extends StatelessWidget {
  final String title;
  const AltSehife({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[700]),
        titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(child: Text("$title səhifəsi", style: GoogleFonts.poppins(fontSize: 22))),
    );
  }
}
