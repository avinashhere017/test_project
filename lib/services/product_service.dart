import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, debugPrint, TargetPlatform;
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
  static const _uploadTimeout = Duration(seconds: 20);

  /// Set this to your dev machine's LAN IP (e.g. '192.168.1.23') when
  /// testing on a physical device — it must be running the backend and
  /// reachable on the same Wi-Fi network. Find it with `ipconfig` (Windows)
  /// or `ifconfig` / `ip addr` (macOS/Linux). Leave null for an emulator or
  /// web, which are handled automatically below.
  static const String? _physicalDeviceBackendHost = '192.168.29.218';

  /// Base URL of the backend that proxies uploads to Cloudinary and saves
  /// items in MongoDB. Android emulators can't reach the host's `localhost`
  /// directly, so they're pointed at the special `10.0.2.2` alias instead;
  /// a physical device needs [_physicalDeviceBackendHost] set above.
  static String get _backendBaseUrl {
    if (_physicalDeviceBackendHost != null) {
      return 'http://$_physicalDeviceBackendHost:5000/api';
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://localhost:5000/api';
  }

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

  /// Uploads one complete item — barcode details plus both captured photos —
  /// to the backend, which stores the photos in Cloudinary and the record in
  /// MongoDB. Returns false on any non-2xx response or network failure.
  Future<bool> uploadItem({
    required ProductModel details,
    required File productPhoto,
    required File barcodePhoto,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendBaseUrl/items'),
      )
        ..fields['barcode'] = details.barcode
        ..fields['name'] = details.name
        ..fields['brand'] = details.brand
        ..fields['quantity'] = details.quantity
        ..fields['price'] = details.price
        ..fields['source'] = details.source.label
        ..fields['sourceImageUrl'] = details.imageUrl ?? ''
        ..files.add(await http.MultipartFile.fromPath('productPhoto', productPhoto.path))
        ..files.add(await http.MultipartFile.fromPath('barcodePhoto', barcodePhoto.path));

      final streamedResponse = await request.send().timeout(_uploadTimeout);
      final ok = streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300;
      if (!ok) {
        final body = await streamedResponse.stream.bytesToString();
        debugPrint('uploadItem failed: HTTP ${streamedResponse.statusCode} — $body');
      }
      return ok;
    } catch (e) {
      debugPrint('uploadItem failed: $e');
      return false;
    }
  }
}
