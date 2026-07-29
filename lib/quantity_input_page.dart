import 'package:flutter/material.dart';

import 'package:aliyev_apk/models.dart';

class QuantityInputPage extends StatefulWidget {
  final String barcode;
  final String productName;
  final double buyPrice;
  final double sellPrice;

  const QuantityInputPage({
    super.key,
    required this.barcode,
    required this.productName,
    required this.buyPrice,
    required this.sellPrice,
  });

  @override
  State<QuantityInputPage> createState() => _QuantityInputPageState();
}

class _QuantityInputPageState extends State<QuantityInputPage> {
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _buyPriceController = TextEditingController();
  final TextEditingController _sellPriceController = TextEditingController();

  final FocusNode _qtyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _productNameController.text = widget.productName;
    _buyPriceController.text = widget.buyPrice.toStringAsFixed(2);
    _sellPriceController.text = widget.sellPrice.toStringAsFixed(2);

    Future.delayed(const Duration(milliseconds: 300), () {
      FocusScope.of(context).requestFocus(_qtyFocusNode);
      _qtyController.selection = TextSelection(baseOffset: 0, extentOffset: _qtyController.text.length); // <== Əlavə et
    });
  }

  void _submit() {
    try {
      final double quantity = double.tryParse(_qtyController.text) ?? 1.0; // int yox, double
      final String name = _productNameController.text.trim();
      final double buy = double.tryParse(_buyPriceController.text) ?? 0.0;
      final double sell = double.tryParse(_sellPriceController.text) ?? 0.0;

      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Məhsulun adı boş ola bilməz")),
        );
        return;
      }

      final product = ScannedProduct(
        barcode: widget.barcode,
        name: name,
        buyPrice: buy,
        sellPrice: sell,
        quantity: quantity, // artıq double
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context, product);
      });
    } catch (e) {
      print("XƏTA BAŞ VERDİ: $e");
    }
  }


  @override
  void dispose() {
    _qtyController.dispose();
    _productNameController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _qtyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Miqdar daxil et")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _qtyController,
                focusNode: _qtyFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done, // <== Əlavə olundu
                onTap: () => _qtyController.selection = TextSelection(baseOffset: 0, extentOffset: _qtyController.text.length),
                onSubmitted: (_) => _submit(), // <== Əlavə olundu
                decoration: const InputDecoration(
                  labelText: "Miqdar",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),
              Text("Barkod: ${widget.barcode}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _productNameController,
                decoration: const InputDecoration(
                  labelText: "Məhsulun adı",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _buyPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onTap: () => _buyPriceController.selection = TextSelection(baseOffset: 0, extentOffset: _buyPriceController.text.length),
                decoration: const InputDecoration(
                  labelText: "Alış qiyməti (AZN)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sellPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onTap: () => _sellPriceController.selection = TextSelection(baseOffset: 0, extentOffset: _sellPriceController.text.length),
                decoration: const InputDecoration(
                  labelText: "Satış qiyməti (AZN)",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  try {
                    final double quantity = double.tryParse(_qtyController.text) ?? 1.0; // int yox, double
                    final String name = _productNameController.text.trim();
                    final double buy = double.tryParse(_buyPriceController.text) ?? 0.0;
                    final double sell = double.tryParse(_sellPriceController.text) ?? 0.0;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Məhsulun adı boş ola bilməz")),
                      );
                      return;
                    }

                    final product = ScannedProduct(
                      barcode: widget.barcode,
                      name: name,
                      buyPrice: buy,
                      sellPrice: sell,
                      quantity: quantity, // artıq double
                    );

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pop(context, product);
                    });
                  } catch (e) {
                    print("XƏTA BAŞ VERDİ: $e");
                  }
                },
                child: const Text("Təsdiqlə"),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
