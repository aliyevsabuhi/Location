class ScannedProduct {
  final String barcode;
  final String name;
  final double buyPrice;
  final double sellPrice;
  final double quantity; // <-- int deyil, double

  ScannedProduct({
    required this.barcode,
    required this.name,
    required this.buyPrice,
    required this.sellPrice,
    required this.quantity,
  });

  ScannedProduct copyWith({
    String? barcode,
    String? name,
    double? buyPrice,
    double? sellPrice,
    double? quantity,
  }) => ScannedProduct(
    barcode: barcode ?? this.barcode,
    name: name ?? this.name,
    buyPrice: buyPrice ?? this.buyPrice,
    sellPrice: sellPrice ?? this.sellPrice,
    quantity: quantity ?? this.quantity,
  );

  Map<String, dynamic> toMap() => {
    'barcode': barcode,
    'name': name,
    'buyPrice': buyPrice,
    'sellPrice': sellPrice,
    'quantity': quantity,
  };

  factory ScannedProduct.fromMap(Map<String, dynamic> m) => ScannedProduct(
    barcode: (m['barcode'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    buyPrice: (m['buyPrice'] as num).toDouble(),
    sellPrice: (m['sellPrice'] as num).toDouble(),
    quantity: (m['quantity'] as num).toDouble(), // <-- double kimi oxu
  );
}
