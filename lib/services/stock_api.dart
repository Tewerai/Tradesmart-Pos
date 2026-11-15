import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock.dart';

class StockApi {
  static const _base = 'https://blueichor.org/api/update_stock.php';
  final String shopid;
  StockApi(this.shopid);

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse(_base),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'shopid': shopid, ...body}),
    );
    if (r.statusCode != 200) throw Exception('Server ${r.statusCode}: ${r.body}');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'API error');
    }
    return data;
  }

  Future<List<StockProduct>> list() async {
    final d = await _post({'action': 'list'});
    return (d['products'] as List)
        .map((e) => StockProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<StockProduct>> search(String term) async {
    final d = await _post({'action': 'search', 'term': term});
    return (d['products'] as List)
        .map((e) => StockProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> delete(int id) => _post({'action': 'delete', 'id': id});

  Future<int> batchUpdate(List<Map<String, dynamic>> products) async {
    final d = await _post({'action': 'batch_update', 'products': products});
    return (d['updated'] as num?)?.toInt() ?? 0;
  }

  Future<double> soldCount(String productName, DateTime date) async {
    final d = await _post({
      'action': 'sold_count',
      'product_name': productName,
      'date': _iso(date),
    });
    return (d['sold_count'] as num).toDouble();
  }

  Future<List<OrderDetailRow>> orderDetails(
      String productName, DateTime date, {bool fullOrder = false}) async {
    final d = await _post({
      'action': 'order_details',
      'product_name': productName,
      'date': _iso(date),
      'full_order': fullOrder,
    });
    return (d['orders'] as List)
        .map((e) => OrderDetailRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}