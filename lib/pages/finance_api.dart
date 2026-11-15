import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/finance.dart';

class FinanceApi {
  static const _base = 'https://blueichor.org/apis/finance.php';
  final String shopid;
  FinanceApi(this.shopid);

  Future<FinanceData> fetch({
    required String view, required String type, required String date,
  }) async {
    final r = await http.get(Uri.parse('$_base?shopid=$shopid&view=$view&type=$type&date=$date'));
    if (r.statusCode != 200) throw Exception('Server ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (d['success'] != true) throw Exception(d['message'] ?? 'API error');
    return FinanceData.fromJson(d);
  }

  Future<({DateSummary summary, List<ProductSoldDetail> products})> salesDetail(String date) async {
    final r = await http.get(Uri.parse('$_base?shopid=$shopid&detail_date=$date&detail_type=sales'));
    if (r.statusCode != 200) throw Exception('Server ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (d['success'] != true) throw Exception(d['message'] ?? 'API error');
    final summary = d['summary'] != null
        ? DateSummary.fromJson(d['summary'] as Map<String, dynamic>)
        : DateSummary.fromJson({});
    final products = (d['sales_breakdown'] as List?)
            ?.map((e) => ProductSoldDetail.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
    return (summary: summary, products: products);
  }

  Future<List<PurchaseDetail>> purchasesDetail(String date) async {
    final r = await http.get(Uri.parse('$_base?shopid=$shopid&detail_date=$date&detail_type=purchases'));
    if (r.statusCode != 200) throw Exception('Server ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (d['success'] != true) throw Exception(d['message'] ?? 'API error');
    return (d['purchases_breakdown'] as List?)
            ?.map((e) => PurchaseDetail.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
  }
}