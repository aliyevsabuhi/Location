// lib/qiymetyoxla.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // ⬅️ RawKeyboardListener və düymələr üçün

class QiymetYoxlaPage extends StatefulWidget {
  const QiymetYoxlaPage({super.key});

  @override
  State<QiymetYoxlaPage> createState() => _QiymetYoxlaPageState();
}

class _QiymetYoxlaPageState extends State<QiymetYoxlaPage> {
  final TextEditingController _scanCtrl = TextEditingController();
  final FocusNode _scanFocus = FocusNode();

  // ⬇️ Yeni: xam klaviatura üçün ayrıca fokus və buffer
  final FocusNode _keyboardFocus = FocusNode();
  final StringBuffer _scanBuffer = StringBuffer();
  String? _queuedBarcode; // ⬅️ ikinci skan gəlsə, növbəyə qoyaq

  Map<String, dynamic>? _product; // { name, barcode, price }
  String? _error;
  Timer? _clearTimer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusScanner();
      _focusKeyboard();
    });
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    _scanCtrl.dispose();
    _scanFocus.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _focusScanner() {
    if (mounted) {
      FocusScope.of(context).requestFocus(_scanFocus);
    }
  }

  void _focusKeyboard() {
    if (mounted) {
      _keyboardFocus.requestFocus();
    }
  }

  void _startAutoClear() {
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _product = null;
        _error = null;
        _loading = false;
      });
      _scanCtrl.clear();
      _scanBuffer.clear(); // ⬅️ buffer-i də sıfırla
      _focusScanner();
      _focusKeyboard();
    });
  }

  // ⬇️ Xam klaviatura hadisələrini burada yığırıq:
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // Yalnız key down ilə işləyək
    if (event is! KeyDownEvent) return KeyEventResult.handled;

    // Enter gəlirsə → toplanan barkodu göndər
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _scanBuffer.toString().trim();
      _scanBuffer.clear();
      if (code.isNotEmpty) {
        _handleSubmit(code);
      }
      return KeyEventResult.handled;
    }

    // Control/Shift və s. yox, yalnız çap olunan simvolları yaz
    final ch = event.character;
    if (ch != null && ch.isNotEmpty) {
      // Çap olunmayanları at (tab, newline və s.)
      final int codeUnit = ch.codeUnitAt(0);
      if (codeUnit >= 32 && codeUnit != 127) {
        _scanBuffer.write(ch);
      }
    }
    return KeyEventResult.handled;
  }

  Future<void> _handleSubmit(String value) async {
    final barcode = value.trim();
    if (barcode.isEmpty) return;

    // ⬇️ Əgər hazırda bir sorğu gedirsə, növbəyə at və çıx
    if (_loading) {
      _queuedBarcode = barcode;
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _product = null;
    });

    try {
      final uri = Uri.http(
        '188.213.212.57:3006',
        '/mallar/bybarcode',
        {'barcode': barcode},
      );

      final resp = await http
          .get(uri, headers: {'accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes);
        final data = json.decode(body);

        if (data is Map<String, dynamic> && data['barkod'] != null) {
          setState(() {
            _product = {
              'name': (data['ad'] ?? '').toString(),
              'barcode': (data['barkod'] ?? '').toString(),
              'price': ((data['satis'] ?? 0) as num).toDouble(),
            };
            _loading = false;
          });
          _startAutoClear();
        } else {
          setState(() {
            _error = "Məhsul tapılmadı.";
            _loading = false;
          });
          _startAutoClear();
        }
      } else if (resp.statusCode == 404) {
        setState(() {
          _error = "Məhsul tapılmadı.";
          _loading = false;
        });
        _startAutoClear();
      } else {
        setState(() {
          _error = "Xəta ${resp.statusCode}: server cavabı uğursuzdur.";
          _loading = false;
        });
        _startAutoClear();
      }
    } on TimeoutException {
      setState(() {
        _error = "Zaman aşımı. Şəbəkəni yoxlayın.";
        _loading = false;
      });
      _startAutoClear();
    } catch (e) {
      setState(() {
        _error = "Gözlənilməz xəta: $e";
        _loading = false;
      });
      _startAutoClear();
    } finally {
      // ⬇️ Əgər bu arada yeni barkod növbəyə düşübsə, onu dərhal işlə
      if (_queuedBarcode != null) {
        final next = _queuedBarcode!;
        _queuedBarcode = null;
        // Kiçik gecikmə fokusları bərpa etsin
        Future.microtask(() {
          _focusKeyboard();
          _focusScanner();
          _handleSubmit(next);
        });
      } else {
        _focusKeyboard();
        _focusScanner();
      }
    }
  }

  String _fmtPrice(double v) {
    final f = NumberFormat.currency(locale: 'az_AZ', symbol: '₼', decimalDigits: 2);
    return f.format(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // ⬇️ BÜTÜN EKRANI xam klaviatura üçün dinləyirik:
      body: Focus(
        focusNode: _keyboardFocus,
        onKeyEvent: _onKeyEvent,
        autofocus: true,
        child: GestureDetector(
          onTap: () {
            _focusKeyboard();
            _focusScanner();
          },
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _loading
                        ? const _LoadingCard()
                        : (_error != null
                        ? _InfoCard(
                      title: "Tapılmadı",
                      subtitle: _error!,
                      color: Colors.redAccent,
                    )
                        : (_product == null
                        ? _IdleCard(onTap: () {
                      _focusKeyboard();
                      _focusScanner();
                    })
                        : _ProductCard(
                      name: _product!['name'] as String,
                      barcode: _product!['barcode'] as String,
                      priceText: _fmtPrice((_product!['price'] as double)),
                    ))),
                  ),
                ),
              ),

              // ⬇️ Ehtiyat üçün gizli TextField (bəzi skanerlər bunu tələb edir)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: false,
                  child: Opacity(
                    opacity: 0.001,
                    child: TextField(
                      controller: _scanCtrl,
                      focusNode: _scanFocus,
                      autofocus: true,
                      readOnly: true,                // ⬅️ kursordan müdaxiləni azaldır
                      showCursor: false,
                      enableInteractiveSelection: false,
                      onSubmitted: (v) {
                        // Əgər bəzi skanerlər yalnız TextField üzərindən işləyirsə
                        if (v.trim().isNotEmpty) {
                          _handleSubmit(v.trim());
                        }
                        _scanCtrl.clear();
                      },
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Boş vəziyyət kartı
class _IdleCard extends StatelessWidget {
  final VoidCallback onTap;
  const _IdleCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.qr_code_scanner, size: 72, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              "Barkodu skan edin",
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "",
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Yüklənmə kartı
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SizedBox(
          height: 80,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

/// Xəbərdarlıq/Info kartı
class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _InfoCard({required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Məhsul kartı – iri qiymət
class _ProductCard extends StatelessWidget {
  final String name;
  final String barcode;
  final String priceText;

  const _ProductCard({
    required this.name,
    required this.barcode,
    required this.priceText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.confirmation_number_outlined),
                const SizedBox(width: 8),
                Text(
                  barcode,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FittedBox(
              child: Text(
                priceText,
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
