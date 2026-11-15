double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

class GraphPoint {
  final String date;
  final double revenue, expenditure, inventory, profit;
  GraphPoint({required this.date, required this.revenue,
    required this.expenditure, required this.inventory, required this.profit});
  factory GraphPoint.fromJson(Map<String, dynamic> j) => GraphPoint(
    date: j['date']?.toString() ?? '',
    revenue: _d(j['revenue']), expenditure: _d(j['expenditure']),
    inventory: _d(j['inventory']), profit: _d(j['profit']),
  );
}

class ExpenseItem {
  final String name, time, date; final double amount;
  ExpenseItem({required this.name, required this.amount,
    required this.time, required this.date});
  factory ExpenseItem.fromJson(Map<String, dynamic> j) => ExpenseItem(
    name: j['name']?.toString() ?? '', amount: _d(j['amount']),
    time: j['time']?.toString() ?? '', date: j['date']?.toString() ?? '',
  );
}

class ProductStat {
  final String name; final double value, sold, amount, profit;
  ProductStat({required this.name, required this.value,
    required this.sold, required this.amount, required this.profit});
  factory ProductStat.fromJson(Map<String, dynamic> j) => ProductStat(
    name: j['name']?.toString() ?? '', value: _d(j['value']),
    sold: _d(j['sold']), amount: _d(j['amount']), profit: _d(j['profit']),
  );
}

class CapitalStats {
  final int totalItems;
  final double costCapital, expectedRevenue, potentialProfit;
  CapitalStats({required this.totalItems, required this.costCapital,
    required this.expectedRevenue, required this.potentialProfit});
  factory CapitalStats.fromJson(Map<String, dynamic> j) => CapitalStats(
    totalItems: _i(j['totalItems']), costCapital: _d(j['costCapital']),
    expectedRevenue: _d(j['expectedRevenue']),
    potentialProfit: _d(j['potentialProfit']),
  );
}

class FinanceData {
  final double totalSales, salesToday, weekExpenditure, totalProfits;
  final List<GraphPoint> graphData;
  final List<ExpenseItem> expenses;
  final List<ProductStat> products;
  final CapitalStats capitalStats;
  FinanceData({required this.totalSales, required this.salesToday,
    required this.weekExpenditure, required this.totalProfits,
    required this.graphData, required this.expenses,
    required this.products, required this.capitalStats});
  factory FinanceData.fromJson(Map<String, dynamic> j) => FinanceData(
    totalSales: _d(j['totalSales']), salesToday: _d(j['salesToday']),
    weekExpenditure: _d(j['weekExpenditure']), totalProfits: _d(j['totalProfits']),
    graphData: (j['graphData'] as List?)?.map((e) => GraphPoint.fromJson(e)).toList() ?? [],
    expenses: (j['expenses'] as List?)?.map((e) => ExpenseItem.fromJson(e)).toList() ?? [],
    products: (j['products'] as List?)?.map((e) => ProductStat.fromJson(e)).toList() ?? [],
    capitalStats: CapitalStats.fromJson((j['capitalStats'] as Map<String,dynamic>?) ?? {}),
  );
}

class DateSummary {
  final double totalRevenue, totalOriginalRevenue, totalDiscounts, totalCOGS, totalGrossProfit;
  final int discountedOrders, totalOrders;
  DateSummary({required this.totalRevenue, required this.totalOriginalRevenue,
    required this.totalDiscounts, required this.totalCOGS,
    required this.totalGrossProfit, required this.discountedOrders,
    required this.totalOrders});
  factory DateSummary.fromJson(Map<String, dynamic> j) => DateSummary(
    totalRevenue: _d(j['total_revenue']),
    totalOriginalRevenue: _d(j['total_original_revenue']),
    totalDiscounts: _d(j['total_discounts']), totalCOGS: _d(j['total_cogs']),
    totalGrossProfit: _d(j['total_gross_profit']),
    discountedOrders: _i(j['discounted_orders']), totalOrders: _i(j['total_orders']),
  );
}

class ProductSoldDetail {
  final String product;
  final double quantity, unitPrice, stockPrice, originalTotal, discount, finalTotal, profit;
  final double? profitMargin;
  final int? openingQuantity, closingQuantity;
  ProductSoldDetail({required this.product, required this.quantity,
    required this.unitPrice, required this.stockPrice, required this.originalTotal,
    required this.discount, required this.finalTotal, required this.profit,
    this.profitMargin, this.openingQuantity, this.closingQuantity});
  factory ProductSoldDetail.fromJson(Map<String, dynamic> j) => ProductSoldDetail(
    product: j['product']?.toString() ?? '', quantity: _d(j['quantity']),
    unitPrice: _d(j['unitPrice'] ?? j['unit_price']),
    stockPrice: _d(j['stockPrice'] ?? j['stock_price']),
    originalTotal: _d(j['original_total']), discount: _d(j['discount']),
    finalTotal: _d(j['final_total']), profit: _d(j['profit']),
    profitMargin: j['profit_margin'] != null ? _d(j['profit_margin']) : null,
    openingQuantity: j['opening_quantity'] != null ? _i(j['opening_quantity']) : null,
    closingQuantity: j['closing_quantity'] != null ? _i(j['closing_quantity']) : null,
  );
}

class PurchaseDetail {
  final String productName, updateType, time;
  final double oldValue, newValue, change, amountSpent;
  PurchaseDetail({required this.productName, required this.updateType,
    required this.oldValue, required this.newValue, required this.change,
    required this.amountSpent, required this.time});
  factory PurchaseDetail.fromJson(Map<String, dynamic> j) => PurchaseDetail(
    productName: j['product_name']?.toString() ?? '',
    updateType: j['update_type']?.toString() ?? '',
    oldValue: _d(j['old_value']), newValue: _d(j['new_value']),
    change: _d(j['change']), amountSpent: _d(j['amount_spent']),
    time: j['time']?.toString() ?? '',
  );
}