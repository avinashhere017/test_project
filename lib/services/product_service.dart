import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/product_model.dart';

class ProductNotFoundException implements Exception {
  final String barcode;
  ProductNotFoundException(this.barcode);

  @override
  String toString() => 'Product not found for barcode $barcode';
}

/// Sources are tried in this order when the caller doesn't pin one down.
/// The three Open-X-Facts projects need no API key and share a response
/// shape; UPCitemdb is a broader general-retail fallback (unkeyed trial
/// tier, rate-limited) for barcodes the Open Facts family doesn't carry.
const List<ProductSource> _autoSourceOrder = [
  ProductSource.openFoodFacts,
  ProductSource.openBeautyFacts,
  ProductSource.openProductsFacts,
  ProductSource.upcItemDb,
];

const Map<ProductSource, String> _openFactsBaseUrls = {
  ProductSource.openFoodFacts: 'https://world.openfoodfacts.org/api/v0/product',
  ProductSource.openBeautyFacts: 'https://world.openbeautyfacts.org/api/v0/product',
  ProductSource.openProductsFacts: 'https://world.openproductsfacts.org/api/v0/product',
};

class ProductService {
  static const _perSourceTimeout = Duration(seconds: 6);

  /// Fetches product details for [barcode]. If [source] is null (Auto),
  /// each source in [_autoSourceOrder] is tried in turn until one returns
  /// a match; a source only reports "not found" (rather than an error) if
  /// it responded but has no record for this barcode. When every source
  /// comes back empty, [ProductNotFoundException] is thrown; if every
  /// source hit a network/server error instead, that error is thrown.
  Future<ProductModel> fetchProduct(String barcode, {ProductSource? source}) async {
    final sources = source != null ? [source] : _autoSourceOrder;

    Object? lastError;
    for (final s in sources) {
      try {
        return await _fetchFromSource(s, barcode);
      } on ProductNotFoundException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError is ProductNotFoundException || lastError == null) {
      throw ProductNotFoundException(barcode);
    }
    throw Exception('Could not reach any product source. $lastError');
  }

  Future<ProductModel> _fetchFromSource(ProductSource source, String barcode) {
    if (source == ProductSource.upcItemDb) {
      return _fetchFromUpcItemDb(barcode);
    }
    return _fetchFromOpenFactsFamily(source, barcode);
  }

  Future<ProductModel> _fetchFromOpenFactsFamily(ProductSource source, String barcode) async {
    final uri = Uri.parse('${_openFactsBaseUrls[source]}/$barcode.json');
    final response = await http.get(uri).timeout(_perSourceTimeout);

    if (response.statusCode != 200) {
      throw Exception('${source.label} returned ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] == 0 || json['product'] == null) {
      throw ProductNotFoundException(barcode);
    }

    return ProductModel.fromOpenFactsFamily(barcode, json, source);
  }

  Future<ProductModel> _fetchFromUpcItemDb(String barcode) async {
    final uri = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode');
    final response = await http.get(uri).timeout(_perSourceTimeout);

    if (response.statusCode != 200) {
      throw Exception('UPCitemdb returned ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? const [];
    if (items.isEmpty) {
      throw ProductNotFoundException(barcode);
    }

    return ProductModel.fromUpcItemDb(barcode, json);
  }

  /// Stub upload for one complete item: barcode details plus both captured
  /// photos, sent together. No backend endpoint is wired up yet; this
  /// simulates a network call so the UI flow can be exercised end to end.
  Future<bool> uploadItem({
    required ProductModel details,
    required File productPhoto,
    required File barcodePhoto,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return true;
  }
}
