class AnalyticsSummary {
  final int orders;
  final double revenue;
  final int availableStock;
  final String currency;
  AnalyticsSummary({required this.orders, required this.revenue,
      required this.availableStock, required this.currency});
  factory AnalyticsSummary.fromJson(Map<String,dynamic> j) => AnalyticsSummary(
        orders: (j['orders'] as num).toInt(),
        revenue: (j['revenue'] as num).toDouble(),
        availableStock: (j['available_stock'] as num).toInt(),
        currency: j['currency'] ?? '\$');
}

class OrderLine {
  final String name; final double qty;
  OrderLine({required this.name, required this.qty});
  factory OrderLine.fromJson(Map<String,dynamic> j) =>
      OrderLine(name: j['name'], qty: (j['qty'] as num).toDouble());
}

class OrderRow {
  final int id;
  final List<OrderLine> items;
  final double total;
  final String receiptId;
  final String time;
  final String cashier;
  final bool? missingGuard;
  OrderRow({required this.id, required this.items, required this.total,
      required this.receiptId, required this.time, required this.cashier,
      this.missingGuard});
  factory OrderRow.fromJson(Map<String,dynamic> j) => OrderRow(
        id: j['id'] ?? 0,
        items: (j['items'] as List).map((e) => OrderLine.fromJson(e)).toList(),
        total: (j['total'] as num).toDouble(),
        receiptId: '${j['receipt_id']}',
        time: j['time'] ?? '',
        cashier: j['cashier'] ?? '',
        missingGuard: j['missing_guard'],
      );
}

class ProfitSummary {
  final double spent, made, profit; final String currency;
  ProfitSummary({required this.spent, required this.made,
      required this.profit, required this.currency});
  factory ProfitSummary.fromJson(Map<String,dynamic> j) => ProfitSummary(
        spent: (j['spent'] as num).toDouble(),
        made: (j['made'] as num).toDouble(),
        profit: (j['profit'] as num).toDouble(),
        currency: j['currency'] ?? '\$');
}

class SellerRow {
  final String name; final double sold, profit;
  SellerRow({required this.name, required this.sold, required this.profit});
  factory SellerRow.fromJson(Map<String,dynamic> j) => SellerRow(
        name: j['name'], sold: (j['sold'] as num).toDouble(),
        profit: (j['profit'] as num).toDouble());
}

class LowStockRow {
  final String name; final double quantity;
  LowStockRow({required this.name, required this.quantity});
  factory LowStockRow.fromJson(Map<String,dynamic> j) => LowStockRow(
        name: j['name'], quantity: (j['quantity'] as num).toDouble());
}

class ExpenseRow {
  final String name, date, time; final double amount;
  ExpenseRow({required this.name, required this.amount,
      required this.date, required this.time});
  factory ExpenseRow.fromJson(Map<String,dynamic> j) => ExpenseRow(
        name: j['name'], amount: (j['amount'] as num).toDouble(),
        date: j['date'] ?? '', time: j['time'] ?? '');
}

class ExcelRow {
  final String name;
  final double available;
  final double unitsMoved;
  final double revenueMade;
  final double costs;

  ExcelRow({
    required this.name,
    required this.available,
    required this.unitsMoved,
    required this.revenueMade,
    required this.costs,
  });

  factory ExcelRow.fromJson(Map<String, dynamic> j) => ExcelRow(
        name: j['name'] ?? '',
        available: (j['available'] as num).toDouble(),
        unitsMoved: (j['units_moved'] as num).toDouble(),
        revenueMade: (j['revenue_made'] as num).toDouble(),
        costs: (j['costs'] as num).toDouble(),
      );
}

// ---------- Sales detail (from finance.php?detail_type=sales) ----------
class ProductSoldDetail {
  final String product;
  final double quantity;
  final double unitPrice;
  final double stockPrice;
  final double originalTotal;
  final double discount;
  final double finalTotal;
  final double profit;
  final double profitMargin;
  final int? openingQuantity;
  final int? closingQuantity;

  ProductSoldDetail({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.stockPrice,
    required this.originalTotal,
    required this.discount,
    required this.finalTotal,
    required this.profit,
    required this.profitMargin,
    this.openingQuantity,
    this.closingQuantity,
  });

  bool get hasDiscount => discount > 0;

  factory ProductSoldDetail.fromJson(Map<String, dynamic> j) => ProductSoldDetail(
        product: j['product'] ?? '',
        quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
        stockPrice: (j['stockPrice'] as num?)?.toDouble() ?? 0,
        originalTotal: (j['original_total'] as num?)?.toDouble() ?? 0,
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        finalTotal: (j['final_total'] as num?)?.toDouble() ?? 0,
        profit: (j['profit'] as num?)?.toDouble() ?? 0,
        profitMargin: (j['profit_margin'] as num?)?.toDouble() ?? 0,
        openingQuantity: (j['opening_quantity'] as num?)?.toInt(),
        closingQuantity: (j['closing_quantity'] as num?)?.toInt(),
      );
}

class SalesDetailSummary {
  final double totalRevenue;
  final double totalOriginalRevenue;
  final double totalDiscounts;
  final double totalCOGS;
  final double totalGrossProfit;
  final int discountedOrders;
  final int totalOrders;

  SalesDetailSummary({
    required this.totalRevenue,
    required this.totalOriginalRevenue,
    required this.totalDiscounts,
    required this.totalCOGS,
    required this.totalGrossProfit,
    required this.discountedOrders,
    required this.totalOrders,
  });

  factory SalesDetailSummary.fromJson(Map<String, dynamic> j) => SalesDetailSummary(
        totalRevenue: (j['total_revenue'] as num?)?.toDouble() ?? 0,
        totalOriginalRevenue: (j['total_original_revenue'] as num?)?.toDouble() ?? 0,
        totalDiscounts: (j['total_discounts'] as num?)?.toDouble() ?? 0,
        totalCOGS: (j['total_cogs'] as num?)?.toDouble() ?? 0,
        totalGrossProfit: (j['total_gross_profit'] as num?)?.toDouble() ?? 0,
        discountedOrders: (j['discounted_orders'] as num?)?.toInt() ?? 0,
        totalOrders: (j['total_orders'] as num?)?.toInt() ?? 0,
      );

  factory SalesDetailSummary.empty() => SalesDetailSummary(
        totalRevenue: 0,
        totalOriginalRevenue: 0,
        totalDiscounts: 0,
        totalCOGS: 0,
        totalGrossProfit: 0,
        discountedOrders: 0,
        totalOrders: 0,
      );
}

class SalesDetail {
  final List<ProductSoldDetail> products;
  final SalesDetailSummary summary;
  SalesDetail({required this.products, required this.summary});
}

// ---------- Purchases (from finance.php?detail_type=purchases) ----------
class PurchaseDetail {
  final String productName;
  final String updateType;
  final String oldValue;
  final String newValue;
  final String change;
  final double amountSpent;
  final String time;

  PurchaseDetail({
    required this.productName,
    required this.updateType,
    required this.oldValue,
    required this.newValue,
    required this.change,
    required this.amountSpent,
    required this.time,
  });

  factory PurchaseDetail.fromJson(Map<String, dynamic> j) => PurchaseDetail(
        productName: j['product_name'] ?? '',
        updateType: j['update_type'] ?? '',
        oldValue: '${j['old_value'] ?? ''}',
        newValue: '${j['new_value'] ?? ''}',
        change: '${j['change'] ?? ''}',
        amountSpent: (j['amount_spent'] as num?)?.toDouble() ?? 0,
        time: j['time'] ?? '',
      );
}