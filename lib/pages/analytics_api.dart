import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/analytics.dart';

class AnalyticsApi {
  static const _base = 'https://aphel.blueichor.org/app/php/analytics.php';
  static const _financeBase = 'https://blueichor.org/apis/finance.php';

  final String shopid;
  AnalyticsApi(this.shopid);

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse(_base),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'shopid': shopid, ...body}),
    );
    if (r.statusCode != 200) {
      throw Exception('Server ${r.statusCode}: ${r.body}');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'API error');
    }
    return data;
  }

  Future<Map<String, dynamic>> _getFinance(Map<String, String> params) async {
    final uri = Uri.parse(_financeBase).replace(queryParameters: {
      'shopid': shopid,
      ...params,
    });
    final r = await http.get(uri);
    if (r.statusCode != 200) {
      throw Exception('Finance server ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- Existing analytics.php calls ----
  Future<AnalyticsSummary> summary(DateTime date) async =>
      AnalyticsSummary.fromJson(await _post({'action': 'summary', 'date': _isoDate(date)}));

  Future<List<OrderRow>> recent(DateTime date) async {
    final d = await _post({'action': 'recent', 'date': _isoDate(date)});
    return (d['orders'] as List).map((e) => OrderRow.fromJson(e)).toList();
  }

  Future<ProfitSummary> profits() async =>
      ProfitSummary.fromJson(await _post({'action': 'profits'}));

  Future<List<SellerRow>> topSellers() async {
    final d = await _post({'action': 'top_sellers'});
    return (d['items'] as List).map((e) => SellerRow.fromJson(e)).toList();
  }

  Future<List<SellerRow>> lowSellers() async {
    final d = await _post({'action': 'low_sellers'});
    return (d['items'] as List).map((e) => SellerRow.fromJson(e)).toList();
  }

  Future<List<LowStockRow>> lowStock() async {
    final d = await _post({'action': 'low_stock'});
    return (d['items'] as List).map((e) => LowStockRow.fromJson(e)).toList();
  }

  Future<List<ExpenseRow>> expenses() async {
    final d = await _post({'action': 'expenses'});
    return (d['items'] as List).map((e) => ExpenseRow.fromJson(e)).toList();
  }

  Future<List<OrderRow>> guards(DateTime date) async {
    final d = await _post({'action': 'guards', 'date': _isoDate(date)});
    return (d['orders'] as List).map((e) => OrderRow.fromJson(e)).toList();
  }

  Future<List<ExcelRow>> excelData(DateTime date) async {
    final d = await _post({'action': 'excel_data', 'date': _isoDate(date)});
    return (d['rows'] as List).map((e) => ExcelRow.fromJson(e)).toList();
  }

  // ---- NEW: finance.php detail calls (same endpoints React uses) ----
  Future<SalesDetail> salesDetail(DateTime date) async {
    final d = await _getFinance({
      'detail_date': _isoDate(date),
      'detail_type': 'sales',
    });
    final products = (d['sales_breakdown'] as List? ?? [])
        .map((e) => ProductSoldDetail.fromJson(e))
        .toList();
    final summary = d['summary'] != null
        ? SalesDetailSummary.fromJson(d['summary'])
        : SalesDetailSummary.empty();
    return SalesDetail(products: products, summary: summary);
  }

  Future<List<PurchaseDetail>> purchasesDetail(DateTime date) async {
    final d = await _getFinance({
      'detail_date': _isoDate(date),
      'detail_type': 'purchases',
    });
    return (d['purchases_breakdown'] as List? ?? [])
        .map((e) => PurchaseDetail.fromJson(e))
        .toList();
  }

  // Filter expenses server-side for the date via analytics.php
  Future<List<ExpenseRow>> expensesForDate(DateTime date) async {
    final d = await _post({'action': 'expenses_for_date', 'date': _isoDate(date)});
    return (d['items'] as List).map((e) => ExpenseRow.fromJson(e)).toList();
  }
}