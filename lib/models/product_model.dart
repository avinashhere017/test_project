enum ProductSource {
  openFoodFacts('Open Food Facts'),
  openBeautyFacts('Open Beauty Facts'),
  openProductsFacts('Open Products Facts'),
  upcItemDb('UPCitemdb');

  final String label;
  const ProductSource(this.label);
}

class ProductModel {
  final String barcode;
  final String name;
  final String brand;
  final String quantity;
  final String? imageUrl;
  final String price;
  final ProductSource source;

  const ProductModel({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.quantity,
    required this.price,
    required this.source,
    this.imageUrl,
  });

  /// Open Food Facts, Open Beauty Facts and Open Products Facts all share
  /// this exact response shape (they're sibling projects on the same API).
  factory ProductModel.fromOpenFactsFamily(
    String barcode,
    Map<String, dynamic> json,
    ProductSource source,
  ) {
    final product = json['product'] as Map<String, dynamic>? ?? {};
    return ProductModel(
      barcode: barcode,
      name: (product['product_name'] as String?)?.trim().isNotEmpty == true
          ? product['product_name'] as String
          : 'Unknown product',
      brand: (product['brands'] as String?)?.trim().isNotEmpty == true
          ? product['brands'] as String
          : 'Unknown brand',
      quantity: (product['quantity'] as String?)?.trim().isNotEmpty == true
          ? product['quantity'] as String
          : '—',
      price: 'Not available',
      source: source,
      imageUrl: product['image_front_url'] as String? ??
          product['image_url'] as String?,
    );
  }

  factory ProductModel.fromUpcItemDb(String barcode, Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    final item = items.isNotEmpty ? items.first as Map<String, dynamic> : const {};
    final images = item['images'] as List<dynamic>? ?? const [];
    return ProductModel(
      barcode: barcode,
      name: (item['title'] as String?)?.trim().isNotEmpty == true
          ? item['title'] as String
          : 'Unknown product',
      brand: (item['brand'] as String?)?.trim().isNotEmpty == true
          ? item['brand'] as String
          : 'Unknown brand',
      quantity: (item['size'] as String?)?.trim().isNotEmpty == true
          ? item['size'] as String
          : '—',
      price: (item['lowest_recorded_price'] is num)
          ? '\$${(item['lowest_recorded_price'] as num).toStringAsFixed(2)}'
          : 'Not available',
      source: ProductSource.upcItemDb,
      imageUrl: images.isNotEmpty ? images.first as String? : null,
    );
  }
}
