import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'barcode_scanner_page.dart';
import 'models.dart';
import 'quantity_input_page.dart';
import 'package:http/http.dart' as http;
import 'main.dart' show globalIp, globalPort, globalceki, globaleded;

class ListDetailPage extends StatefulWidget {
  final String listName;

  const ListDetailPage({super.key, required this.listName});

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  final TextEditingController _barcodeController = TextEditingController();
  final List<ScannedProduct> _scannedProducts = [];

  // ---- PERSISTENCE AÇARLARI və HELPER-LƏR ----
  String get _storageKey => 'list_items_${widget.listName}';

  Map<String, dynamic> _toMap(ScannedProduct p) => {
    'barcode': p.barcode,
    'name': p.name,
    'buyPrice': p.buyPrice,
    'sellPrice': p.sellPrice,
    'quantity': p.quantity,
  };

  ScannedProduct _fromMap(Map<String, dynamic> m) => ScannedProduct(
    barcode: m['barcode'] as String,
    name: m['name'] as String,
    buyPrice: (m['buyPrice'] as num).toDouble(),
    sellPrice: (m['sellPrice'] as num).toDouble(),
    quantity: (m['quantity'] as num).toDouble(),
  );

  Future<void> _loadProductsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return;
    final List<dynamic> arr = jsonDecode(jsonStr);
    setState(() {
      _scannedProducts
        ..clear()
        ..addAll(arr.map((e) => _fromMap(e as Map<String, dynamic>)));
    });
  }

  Future<void> _saveProductsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final arr = _scannedProducts.map(_toMap).toList();
    await prefs.setString(_storageKey, jsonEncode(arr));
  }
  // ---- /PERSISTENCE ----



  bool _submitting = false;

  double get _totalQty =>
      _scannedProducts.fold<double>(0.0, (s, p) => s + p.quantity);


  Future<String> _getBaseUrl() async {
    if (globalIp == null ||
        globalPort == null ||
        globalIp!.trim().isEmpty ||
        globalPort!.toString().trim().isEmpty) {
      throw Exception('Server IP/Port təyin olunmayıb. Parametrləri yoxlayın.');
    }
    String host = globalIp!.trim();
    String port = globalPort!.toString().trim();
    host = host.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');
    if (host == '127.0.0.1' || host.toLowerCase() == 'localhost') {
      host = '10.0.2.2'; // Android emulator üçün
    }
    return 'http://$host:$port';
  }

  Future<void> _clearList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    setState(() => _scannedProducts.clear());
  }

  /// Serverə göndər
  Future<void> _submitToServer() async {
    if (_scannedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Siyahıda məhsul yoxdur.')),
      );
      return;
    }

    final payload = {
      'date': DateTime.now().toIso8601String(),
      'listName': widget.listName,
      'lines': _scannedProducts.map((p) => {
        'barcode': p.barcode,
        'ad': p.name,
        'qty': p.quantity,
        'alis': p.buyPrice,
        'satis': p.sellPrice,
      }).toList(),
      'totalQty': _totalQty,
    };

    setState(() => _submitting = true);
    try {
      final base = await _getBaseUrl();
      final resp = await http.post(
        Uri.parse('$base/terminal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        await _clearList();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Siyahı serverə göndərildi.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xəta: ${resp.statusCode} — ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Şəbəkə xətası: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  @override
  void initState() {
    super.initState();
    _loadProductsFromStorage(); // səhifə açılan kimi məhsulları yüklə
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }



  Future<void> _removeAtOriginalIndex(int originalIndex) async {
    setState(() {
      _scannedProducts.removeAt(originalIndex);
    });
    await _saveProductsToStorage();
  }

  Future<void> _editAtOriginalIndex(int originalIndex) async {
    final p = _scannedProducts[originalIndex];

    final nameCtrl = TextEditingController(text: p.name);
    final qtyCtrl  = TextEditingController(text: p.quantity.toString());
    final buyCtrl  = TextEditingController(text: p.buyPrice.toStringAsFixed(2));
    final sellCtrl = TextEditingController(text: p.sellPrice.toStringAsFixed(2));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Məhsula düzəliş et'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Ad'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Miqdar'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: buyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Alış qiyməti'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sellCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Satış qiyməti'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ləğv et'),
            ),
            FilledButton(
              onPressed: () {
                String fix(String s) => s.replaceAll(',', '.').trim();
                final name = nameCtrl.text.trim();
                final qty  = double.tryParse(fix(qtyCtrl.text)) ?? p.quantity;
                final buy  = double.tryParse(fix(buyCtrl.text)) ?? p.buyPrice;
                final sell = double.tryParse(fix(sellCtrl.text)) ?? p.sellPrice;

                if (name.isEmpty || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ad boş ola bilməz, miqdar 0-dan böyük olmalıdır.')),
                  );
                  return;
                }

                setState(() {
                  _scannedProducts[originalIndex] = p.copyWith(
                    name: name,
                    quantity: qty,
                    buyPrice: buy,
                    sellPrice: sell,
                  );
                });
                Navigator.pop(context, true);
              },
              child: const Text('Yadda saxla'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _saveProductsToStorage();
    }
  }


  Future<void> _handleScannedBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('mallar_data');

    if (jsonString == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Məhsul siyahısı boşdur. Əvvəlcə yeniləyin.")),
      );
      return;
    }


    final List<dynamic> mallar = jsonDecode(jsonString);

    // 1) Əvvəl tərəzi barkodu olub-olmadığını yoxla
    final parsed = _parseScaleBarcode(barcode);

    if (parsed != null) {
      final plu = parsed.plu;
      final qtyFromScale = parsed.qty;

      final foundList = mallar.where((m) {
        final mPlu = (m['plu'] as num?)?.toInt();
        return mPlu == plu;
      }).toList();

      if (foundList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tərəzi barkodu üçün məhsul tapılmadı (Plu: $plu).')),
        );
        return;
      }

      final m = foundList.first as Map<String, dynamic>;
      final productName = (m['adi'] ?? '').toString();
      final buyPrice = double.tryParse(m['alis']?.toString() ?? '') ?? 0.0;
      final sellPrice = double.tryParse(m['satis']?.toString() ?? '') ?? 0.0;

      final baseBarcode = (m['barkod'] ?? '').toString();
      final keyBarcode = baseBarcode.isNotEmpty ? baseBarcode : barcode;

      final existingIndex = _scannedProducts.indexWhere((p) => p.barcode == keyBarcode);

      setState(() {
        if (existingIndex != -1) {
          final ex = _scannedProducts[existingIndex];
          _scannedProducts[existingIndex] = ex.copyWith(
            quantity: ex.quantity + qtyFromScale,
          );
        } else {
          _scannedProducts.add(
            ScannedProduct(
              barcode: keyBarcode,
              name: productName,
              buyPrice: buyPrice,
              sellPrice: sellPrice,
              quantity: qtyFromScale,
            ),
          );
        }
      });

      await _saveProductsToStorage();
      _barcodeController.clear();
      return;
    }


    // 2) Tərəzi barkodu deyilsə, əvvəlki məntiq eyni qalsın
    final existingIndex = _scannedProducts.indexWhere((p) => p.barcode == barcode);
    final existingProduct = existingIndex != -1 ? _scannedProducts[existingIndex] : null;

    final foundProducts = mallar.where((m) => m['barkod'] == barcode).toList();

    String productName = '';
    double buyPrice = 0.0;
    double sellPrice = 0.0;

    if (foundProducts.isNotEmpty) {
      final foundProduct = foundProducts.first as Map<String, dynamic>;
      productName = (foundProduct['adi'] ?? '').toString();
      buyPrice = double.tryParse(foundProduct['alis']?.toString() ?? '') ?? 0.0;
      sellPrice = double.tryParse(foundProduct['satis']?.toString() ?? '') ?? 0.0;
    } else {
      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Məhsul tapılmadı"),
          content: Text("\"$barcode\" barkoduna uyğun məhsul tapılmadı.\nƏlavə etmək istəyirsinizmi?"),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Xeyr")),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Bəli, əlavə et")),
          ],
        ),
      );
      if (shouldAdd != true) return;
    }

    final ScannedProduct? product = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuantityInputPage(
          barcode: barcode,
          productName: productName,
          buyPrice: buyPrice,
          sellPrice: sellPrice,
        ),
      ),
    );

    if (product != null) {
      setState(() {
        if (existingProduct != null) {
          final updatedProduct = existingProduct.copyWith(
            quantity: existingProduct.quantity + product.quantity,
          );
          _scannedProducts[existingIndex] = updatedProduct;
        } else {
          _scannedProducts.add(product);
        }
      });
      await _saveProductsToStorage();
      _barcodeController.clear();
    }
  }




  bool _isScaleBarcode(String bc) {
    if (bc.length != 13) return false;
    return bc.startsWith('$globaleded') || bc.startsWith('$globalceki');
  }

  /// Nümunə: 2207367002200  => idn: 7367, qty: 0.220
  ({int plu, double qty})? _parseScaleBarcode(String bc) {
    try {
      if (!_isScaleBarcode(bc)) return null;
      final pluStr = bc.substring(3, 7);   // 4 rəqəm → PLU
      final qtyStr = bc.substring(7, 12);  // 5 rəqəm → çəki
      final plu = int.parse(pluStr);
      final qty = int.parse(qtyStr) / 1000.0;
      if (qty <= 0) return null;
      return (plu: plu, qty: qty);
    } catch (_) {
      return null;
    }
  }



  @override
  Widget build(BuildContext context) {
    // Siyahını ters göstərmək üçün ayrıca reversed list qururuq
    final reversed = _scannedProducts.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.listName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: "Barkod və ya PLU kodu daxil et",
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _handleScannedBarcode,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handleScannedBarcode(_barcodeController.text.trim()),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: reversed.isEmpty
                ? const Center(child: Text('Heç bir məhsul əlavə edilməyib.'))
                : ListView.builder(
              itemCount: reversed.length,
              itemBuilder: (context, index) {
                final product = reversed[index];

                // reversed -> orijinal index
                final originalIndex = _scannedProducts.length - 1 - index;

                return Dismissible(
                  key: ValueKey('prod_${product.barcode}_$originalIndex'),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await _removeAtOriginalIndex(originalIndex);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Məhsul silindi')),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      onTap: () => _editAtOriginalIndex(originalIndex),
                      title: Text("Barkodu: ${product.barcode}\nAdı:  ${product.name}"),
                      subtitle: Text(
                        "Alış: ${product.buyPrice.toStringAsFixed(2)} ₼ | "
                            "Satış: ${product.sellPrice.toStringAsFixed(2)} ₼",
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Miqdar: ${product.quantity}"),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Düzəliş et',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editAtOriginalIndex(originalIndex),
                              ),
                              IconButton(
                                tooltip: 'Sil',
                                icon: const Icon(Icons.delete_forever),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Silinsin?'),
                                      content: Text('"${product.name}" silinsin?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Yox'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Bəli'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await _removeAtOriginalIndex(originalIndex);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },

            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Barkod oxut',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
          );
          if (result != null && result is String) {
            _handleScannedBarcode(result);
          }
        },
        child: const Icon(Icons.qr_code_scanner), // düzəliş
      ),


      // ↓↓↓ BUNU ƏLAVƏ ET ↓↓↓
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

          /*child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submitToServer,
                  icon: _submitting
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _submitting
                        ? 'Göndərilir...'
                        : 'Serverə göndər (${_totalQty.toString()})',
                  ),
                ),
              ),
            ],
          ),*/
        ),
      ),
    );
  }


}
