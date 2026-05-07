import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/shopping_item.dart';

class ShoppingListImportService {
  static Future<List<ShoppingItem>> fromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return _parse(raw);
  }

  static Future<List<ShoppingItem>> fromApi(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API error: ${response.statusCode}');
    }
    return _parse(response.body);
  }

  static List<ShoppingItem> _parse(String source) {
    final decoded = jsonDecode(source);

    final list = switch (decoded) {
      List<dynamic> value => value,
      Map<String, dynamic> value when value['items'] is List<dynamic> =>
        value['items'] as List<dynamic>,
      _ => <dynamic>[],
    };

    return list
        .whereType<Map<String, dynamic>>()
        .map(ShoppingItem.fromJson)
        .where((item) => item.name.isNotEmpty && item.section.isNotEmpty)
        .toList();
  }
}
