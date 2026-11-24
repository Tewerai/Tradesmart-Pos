import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance.dart';
import 'analytics_api.dart';
import 'finance_api.dart';
import '../models/analytics.dart'
    hide ProductSoldDetail, PurchaseDetail;
enum ViewMode { recent, profits, topSellers, lowSellers, lowStock, expenses, guards }

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  AnalyticsApi? _api;
  FinanceApi? _financeApi;

  ViewMode _view = ViewMode.recent;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  AnalyticsSummary? _summary;
  List<OrderRow>? _recentOrders;
  ProfitSummary? _profit;
  List<SellerRow>? _sellers;
  List<LowStockRow>? _lowStock;
  List<ExpenseRow>? _expenses;
  List<OrderRow>? _guardOrders;

  // --- Finance (inline) ---
  FinanceData? _finance;
  bool _financeLoading = false;
  String? _financeError;
  String _financeView = 'daily';
  String _financeType = 'sales';
  bool _showAllFinanceExpenses = false;

  // --- Inline detail panel ---
  GraphPoint? _selectedPoint;
  DateSummary? _detailSummary;
  List<ProductSoldDetail>? _detailProducts;
  List<PurchaseDetail>? _detailPurchases;
  bool _detailLoading = false;
  String? _detailError;
  bool _showDetailProducts = true;
  bool _showDetailPurchases = true;
  bool _showDetailProfit = true;
  String password = '';


  @override
  void initState() {
    super.initState();
    _checkPasswordRequirement();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final shopid = prefs.getString('username') ?? '';
    _api = AnalyticsApi(shopid);
    _financeApi = FinanceApi(shopid);
    await _reload();
    await _loadFinance();
  }

  Future<void> _checkPasswordRequirement() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool requirePassword = prefs.getBool('addPasswordForUploadStock') ?? false;
    if (requirePassword) {
      _showPasswordDialog();
    }
  }

  Future<void> _showPasswordDialog() async {
    TextEditingController passwordController = TextEditingController();
    int passwordAttempts = 0;
    bool passwordMatched = false;

    while (passwordAttempts < 3 && !passwordMatched) {
      passwordMatched = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Enter Password'),
                content: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            errorText: passwordAttempts != 0
                                ? 'Wrong password, ${3 - passwordAttempts} attempt(s) remaining'
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: Text('Submit'),
                    onPressed: () async {
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      String savedPassword = prefs.getString('password') ?? '';
                      if (passwordController.text == savedPassword) {
                        Navigator.of(context).pop(true);
                      } else {
                        setState(() => passwordAttempts++);
                        if (passwordAttempts >= 3) {
                          Navigator.of(context).pop(false);
                        }
                      }
                    },
                  ),
                ],
              );
            },
          ) ??
          false;
    }

    if (!passwordMatched && passwordAttempts >= 3) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _reload() async {
    if (_api == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final summary = await _api!.summary(_date);
      switch (_view) {
        case ViewMode.recent:     _recentOrders = await _api!.recent(_date); break;
        case ViewMode.profits:    _profit       = await _api!.profits(); break;
        case ViewMode.topSellers: _sellers      = await _api!.topSellers(); break;
        case ViewMode.lowSellers: _sellers      = await _api!.lowSellers(); break;
        case ViewMode.lowStock:   _lowStock     = await _api!.lowStock(); break;
        case ViewMode.expenses:   _expenses     = await _api!.expenses(); break;
        case ViewMode.guards:     _guardOrders  = await _api!.guards(_date); break;
      }
      if (!mounted) return;
      setState(() { _summary = summary; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadFinance() async {
    if (_financeApi == null) return;
    setState(() { _financeLoading = true; _financeError = null; });
    try {
      final data = await _financeApi!.fetch(
        view: _financeView,
        type: _financeType,
        date: DateFormat('yyyy-MM-dd').format(_date),
      );
      if (!mounted) return;
      setState(() { _finance = data; _financeLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _financeLoading = false; _financeError = e.toString(); });
    }
  }

  Future<void> _openDetail(GraphPoint point) async {
    if (_financeApi == null) return;
    setState(() {
      _selectedPoint = point;
      _detailLoading = true;
      _detailError = null;
      _detailSummary = null;
      _detailProducts = null;
      _detailPurchases = null;
    });
    final iso = _normaliseDate(point.date);
    try {
      final results = await Future.wait([
        _financeApi!.salesDetail(iso),
        _financeApi!.purchasesDetail(iso),
      ]);
      if (!mounted) return;
      final sales = results[0] as ({DateSummary summary, List<ProductSoldDetail> products});
      setState(() {
        _detailSummary = sales.summary;
        _detailProducts = sales.products;
        _detailPurchases = results[1] as List<PurchaseDetail>;
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _detailLoading = false; _detailError = e.toString(); });
    }
  }

  String _normaliseDate(String raw) {
    if (raw.contains(' to ')) raw = raw.split(' to ').first;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return raw;
    final m = RegExp(r'(\d+)(?:st|nd|rd|th)? of (\w+) (\d{4})').firstMatch(raw);
    if (m != null) {
      const months = ['january','february','march','april','may','june',
        'july','august','september','october','november','december'];
      final d = int.tryParse(m.group(1)!) ?? 1;
      final mi = months.indexOf(m.group(2)!.toLowerCase()) + 1;
      final y = int.tryParse(m.group(3)!) ?? DateTime.now().year;
      if (mi > 0) return DateFormat('yyyy-MM-dd').format(DateTime(y, mi, d));
    }
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _downloadExcel() async {
    if (_api == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final rows = await _api!.excelData(_date);
      final buf = StringBuffer()..writeln('Name\tAvailable\tUnits Moved\tRevenue Made\tCosts');
      for (final r in rows) {
        buf.writeln('"${r.name}"\t${r.available}\t${r.unitsMoved}\t${r.revenueMade}\t${r.costs}');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Sales_Detail_${DateFormat('yyyy-MM-dd').format(_date)}.xls');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.ms-excel')],
        subject: 'Sales Detail — ${DateFormat('yyyy-MM-dd').format(_date)}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${rows.length} rows')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _reload();
              _loadFinance();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading && _summary == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _reload)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _StatCards(summary: _summary!,
                        onDownload: _downloadExcel, downloading: _downloading),
                    const SizedBox(height: 20),
                    _Controls(
                      view: _view, date: _date,
                      onViewChanged: (v) { setState(() => _view = v); _reload(); },
                      onDateChanged: (d) {
                        setState(() => _date = d);
                        _reload();
                        _loadFinance();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_loading) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    _buildTable(),

                    // ====== FINANCE SECTION (inline) ======
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(thickness: 2),
                    ),
                    const Text('Financial Details',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._buildFinanceSection(),
                  ],
                ),
    );
  }

  Widget _buildTable() {
    switch (_view) {
      case ViewMode.recent:
        return _RecentTable(rows: _recentOrders ?? [], currency: _summary!.currency);
      case ViewMode.profits:
        return _ProfitTable(p: _profit!);
      case ViewMode.topSellers:
      case ViewMode.lowSellers:
        return _SellerTable(rows: _sellers ?? [], currency: _summary!.currency);
      case ViewMode.lowStock:
        return _LowStockTable(rows: _lowStock ?? []);
      case ViewMode.expenses:
        return _ExpenseTable(rows: _expenses ?? [], currency: _summary!.currency);
      case ViewMode.guards:
        return _GuardsTable(rows: _guardOrders ?? [], currency: _summary!.currency);
    }
  }

  List<Widget> _buildFinanceSection() {
    if (_financeLoading && _finance == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_financeError != null) {
      return [
        Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('Finance: $_financeError',
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _loadFinance, child: const Text('Retry')),
            ]),
          ),
        ),
      ];
    }
    final f = _finance!;
    return [
      _FinanceCards(data: f),
      const SizedBox(height: 24),
      const Text('Revenue vs Expenditure',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _FinanceFilters(
        view: _financeView, type: _financeType, date: _date,
        onViewChanged: (v) { setState(() => _financeView = v); _loadFinance(); },
        onTypeChanged: (v) { setState(() => _financeType = v); _loadFinance(); },
        onDateChanged: (d) {
          setState(() => _date = d);
          _reload();
          _loadFinance();
        },
      ),
      const SizedBox(height: 12),
      if (_financeLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
      const SizedBox(height: 8),
      if (f.graphData.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No graph data for this period.',
              style: TextStyle(color: Colors.grey)),
        )
      else
        _FinanceChart(data: f.graphData, onPointTap: _openDetail),
      const SizedBox(height: 8),
      Text('💡 Tap any point to see the daily breakdown below.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),

      if (_selectedPoint != null) ...[
        const SizedBox(height: 16),
        _InlineDetailPanel(
          point: _selectedPoint!,
          loading: _detailLoading,
          error: _detailError,
          summary: _detailSummary,
          products: _detailProducts,
          purchases: _detailPurchases,
          showProducts: _showDetailProducts,
          showPurchases: _showDetailPurchases,
          showProfit: _showDetailProfit,
          onToggleProducts: () => setState(() => _showDetailProducts = !_showDetailProducts),
          onTogglePurchases: () => setState(() => _showDetailPurchases = !_showDetailPurchases),
          onToggleProfit: () => setState(() => _showDetailProfit = !_showDetailProfit),
          onClose: () => setState(() => _selectedPoint = null),
        ),
      ],

      const SizedBox(height: 24),
      _FinanceExpensesTable(
        expenses: f.expenses,
        showAll: _showAllFinanceExpenses,
        onToggle: () => setState(() => _showAllFinanceExpenses = !_showAllFinanceExpenses),
      ),
      const SizedBox(height: 24),
      _FinanceProductsPie(products: f.products),
      const SizedBox(height: 24),
      _FinanceCapital(stats: f.capitalStats),
    ];
  }
}

// ==========================================================================
// Existing analytics widgets
// ==========================================================================

class _StatCards extends StatelessWidget {
  final AnalyticsSummary summary;
  final VoidCallback? onDownload;
  final bool downloading;
  const _StatCards({required this.summary, this.onDownload, this.downloading = false});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _card('Orders Complete', '${summary.orders}', Icons.shopping_cart, Colors.blue),
      _card('Total Sale',
          '${summary.currency}${summary.revenue.toStringAsFixed(2)}',
          Icons.attach_money, Colors.green),
      _card('Available Stock', '${summary.availableStock}',
          Icons.inventory, Colors.orange),
      _card('Download Data', downloading ? 'Working…' : 'Excel',
          Icons.file_download, Colors.purple,
          onTap: downloading ? null : onDownload,
          trailing: downloading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null),
    ];
    return Wrap(spacing: 12, runSpacing: 12, children: cards);
  }

  Widget _card(String title, String value, IconData icon, Color color,
      {VoidCallback? onTap, Widget? trailing}) {
    return SizedBox(
      width: 165, height: 100,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(icon, color: color, size: 34),
              const SizedBox(width: 12),
              Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: Text(value,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis)),
                    if (trailing != null) trailing,
                  ]),
                ],
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final ViewMode view;
  final DateTime date;
  final ValueChanged<ViewMode> onViewChanged;
  final ValueChanged<DateTime> onDateChanged;
  const _Controls({required this.view, required this.date,
      required this.onViewChanged, required this.onDateChanged});

  @override
  Widget build(BuildContext context) {
    final label = {
      ViewMode.recent: 'Recent Orders', ViewMode.profits: 'Profit Margins',
      ViewMode.topSellers: 'Top Sellers', ViewMode.lowSellers: 'Low Sellers',
      ViewMode.lowStock: 'Low Stock', ViewMode.expenses: 'Expenses',
      ViewMode.guards: 'Security Check',
    };
    return Wrap(
      spacing: 12, runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<ViewMode>(
          value: view,
          onChanged: (v) => v != null ? onViewChanged(v) : null,
          items: ViewMode.values.map((v) =>
              DropdownMenuItem(value: v, child: Text(label[v]!))).toList(),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(DateFormat('yyyy-MM-dd').format(date)),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context, initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked != null) onDateChanged(picked);
          },
        ),
      ],
    );
  }
}

class _RecentTable extends StatelessWidget {
  final List<OrderRow> rows; final String currency;
  const _RecentTable({required this.rows, required this.currency});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty('No orders for this date.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Items')), DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Receipt')), DataColumn(label: Text('Time')),
          DataColumn(label: Text('Cashier')),
        ],
        rows: rows.map((o) => DataRow(cells: [
          DataCell(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: o.items.map((it) => Text('${it.name} x ${it.qty}')).toList(),
          )),
          DataCell(Text('$currency${o.total.toStringAsFixed(2)}')),
          DataCell(Text(o.receiptId)),
          DataCell(Text(o.time)),
          DataCell(Text(o.cashier)),
        ])).toList(),
      ),
    );
  }
}

class _ProfitTable extends StatelessWidget {
  final ProfitSummary p;
  const _ProfitTable({required this.p});
  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Amount Spent')),
        DataColumn(label: Text('Amount Made')),
        DataColumn(label: Text('Profit')),
      ],
      rows: [
        DataRow(cells: [
          DataCell(Text('${p.currency}${p.spent.toStringAsFixed(2)}')),
          DataCell(Text('${p.currency}${p.made.toStringAsFixed(2)}')),
          DataCell(Text('${p.currency}${p.profit.toStringAsFixed(2)}',
              style: TextStyle(color: p.profit >= 0 ? Colors.green : Colors.red))),
        ]),
      ],
    );
  }
}

class _SellerTable extends StatelessWidget {
  final List<SellerRow> rows; final String currency;
  const _SellerTable({required this.rows, required this.currency});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty('No products.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Sold')),
          DataColumn(label: Text('Profit')),
        ],
        rows: rows.map((r) => DataRow(cells: [
          DataCell(Text(r.name)),
          DataCell(Text(r.sold.toStringAsFixed(0))),
          DataCell(Text('$currency${r.profit.toStringAsFixed(2)}')),
        ])).toList(),
      ),
    );
  }
}

class _LowStockTable extends StatelessWidget {
  final List<LowStockRow> rows;
  const _LowStockTable({required this.rows});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty('All products above threshold.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Available')),
        ],
        rows: rows.map((r) => DataRow(cells: [
          DataCell(Text(r.name)),
          DataCell(Text(r.quantity.toStringAsFixed(0),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ])).toList(),
      ),
    );
  }
}

class _ExpenseTable extends StatelessWidget {
  final List<ExpenseRow> rows; final String currency;
  const _ExpenseTable({required this.rows, required this.currency});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty('No expenses.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Expense')),
          DataColumn(label: Text('Value')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Time')),
        ],
        rows: rows.map((r) => DataRow(cells: [
          DataCell(Text(r.name)),
          DataCell(Text('$currency${r.amount.toStringAsFixed(2)}')),
          DataCell(Text(r.date)),
          DataCell(Text(r.time)),
        ])).toList(),
      ),
    );
  }
}

class _GuardsTable extends StatelessWidget {
  final List<OrderRow> rows; final String currency;
  const _GuardsTable({required this.rows, required this.currency});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty('No orders for this date.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Order#')),
          DataColumn(label: Text('Products')),
          DataColumn(label: Text('Total')),
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Cashier')),
        ],
        rows: rows.map((o) => DataRow(
          color: MaterialStateProperty.resolveWith((_) =>
              o.missingGuard == true ? Colors.red.withOpacity(0.15) : null),
          cells: [
            DataCell(Text(o.receiptId)),
            DataCell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: o.items.map((it) => Text('${it.name} x ${it.qty}')).toList(),
            )),
            DataCell(Text('$currency${o.total.toStringAsFixed(2)}')),
            DataCell(Text(o.time)),
            DataCell(Text(o.cashier)),
          ],
        )).toList(),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty(this.message);
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Text(message)));
}

class _ErrorView extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    ),
  );
}

// ==========================================================================
// Inline finance widgets
// ==========================================================================

class _FinanceCards extends StatelessWidget {
  final FinanceData data;
  const _FinanceCards({required this.data});
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: [
      _c('Total Sales', data.totalSales, Icons.attach_money, Colors.blue),
      _c('Sales Today', data.salesToday, Icons.trending_up, Colors.green),
      _c('Week Expenditure', data.weekExpenditure, Icons.account_balance_wallet, Colors.orange),
      _c('Total Profits', data.totalProfits, Icons.check_circle, Colors.purple),
    ]);
  }

  Widget _c(String title, double v, IconData icon, Color color) => SizedBox(
    width: 165, height: 100,
    child: Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(icon, color: color, size: 34),
        const SizedBox(width: 12),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('\$${v.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
    )),
  );
}

class _FinanceFilters extends StatelessWidget {
  final String view, type;
  final DateTime date;
  final ValueChanged<String> onViewChanged, onTypeChanged;
  final ValueChanged<DateTime> onDateChanged;
  const _FinanceFilters({required this.view, required this.type, required this.date,
      required this.onViewChanged, required this.onTypeChanged, required this.onDateChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<String>(
          value: view,
          onChanged: (v) => v != null ? onViewChanged(v) : null,
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
          ],
        ),
        DropdownButton<String>(
          value: type,
          onChanged: (v) => v != null ? onTypeChanged(v) : null,
          items: const [
            DropdownMenuItem(value: 'sales', child: Text('Sales')),
            DropdownMenuItem(value: 'products', child: Text('Products')),
            DropdownMenuItem(value: 'expenses', child: Text('Expenses')),
          ],
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(DateFormat('yyyy-MM-dd').format(date)),
          onPressed: () async {
            final p = await showDatePicker(
              context: context, initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (p != null) onDateChanged(p);
          },
        ),
      ],
    );
  }
}

class _FinanceChart extends StatelessWidget {
  final List<GraphPoint> data;
  final ValueChanged<GraphPoint> onPointTap;
  const _FinanceChart({required this.data, required this.onPointTap});

  @override
  Widget build(BuildContext context) {
    double maxY = 0;
    for (final p in data) {
      for (final v in [p.revenue, p.expenditure, p.inventory, p.profit]) {
        if (v > maxY) maxY = v;
      }
    }
    if (maxY == 0) maxY = 100;
    final interval = data.length > 10 ? (data.length / 8).ceilToDouble() : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 16, children: [
          _legend('Revenue', Colors.blue),
          _legend('Expenses', Colors.green),
          _legend('Purchases', Colors.orange),
          _legend('Profit', Colors.red),
        ]),
        const SizedBox(height: 8),
        SizedBox(height: 280, child: LineChart(LineChartData(
          minY: 0, maxY: maxY * 1.15,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, interval: interval, reservedSize: 28,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_short(data[i].date), style: const TextStyle(fontSize: 9)),
                );
              },
            )),
          ),
          lineTouchData: LineTouchData(
            touchCallback: (event, response) {
              if (event is FlTapUpEvent && response != null &&
                  response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                final i = response.lineBarSpots!.first.spotIndex;
                if (i >= 0 && i < data.length) onPointTap(data[i]);
              }
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final p = data[s.spotIndex];
                return LineTooltipItem(
                  '${_short(p.date)}\n'
                  'Rev: \$${p.revenue.toStringAsFixed(2)}\n'
                  'Exp: \$${p.expenditure.toStringAsFixed(2)}\n'
                  'Inv: \$${p.inventory.toStringAsFixed(2)}\n'
                  'Profit: \$${p.profit.toStringAsFixed(2)}',
                  TextStyle(color: s.bar.color ?? Colors.black, fontSize: 11),
                );
              }).toList(),
            ),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
          lineBarsData: [
            _line(data.map((p) => p.revenue).toList(), Colors.blue),
            _line(data.map((p) => p.expenditure).toList(), Colors.green),
            _line(data.map((p) => p.inventory).toList(), Colors.orange),
            _line(data.map((p) => p.profit).toList(), Colors.red),
          ],
        ))),
      ],
    );
  }

  LineChartBarData _line(List<double> vals, Color color) => LineChartBarData(
    spots: List.generate(vals.length, (i) => FlSpot(i.toDouble(), vals[i])),
    isCurved: true, color: color, barWidth: 2,
    dotData: const FlDotData(show: true),
    belowBarData: BarAreaData(show: false),
  );

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  String _short(String raw) {
    final m = RegExp(r'(\d+)(?:st|nd|rd|th)? of (\w+)').firstMatch(raw);
    if (m != null) return '${m.group(1)} ${m.group(2)!.substring(0, 3)}';
    return raw.length >= 10 ? raw.substring(5, 10) : raw;
  }
}

class _FinanceExpensesTable extends StatelessWidget {
  final List<ExpenseItem> expenses;
  final bool showAll;
  final VoidCallback onToggle;
  const _FinanceExpensesTable({required this.expenses, required this.showAll, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final shown = showAll ? expenses : expenses.take(8).toList();
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const Text('No expenses recorded.', style: TextStyle(color: Colors.grey))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')), DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Time')), DataColumn(label: Text('Date')),
              ],
              rows: <DataRow>[
                for (final e in shown)
                  DataRow(cells: [
                    DataCell(Text(e.name)),
                    DataCell(Text('\$${e.amount.toStringAsFixed(2)}')),
                    DataCell(Text(e.time)),
                    DataCell(Text(e.date)),
                  ]),
                DataRow(cells: [
                  const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text('\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                ]),
              ],
            ),
          ),
        if (expenses.length > 8)
          TextButton(onPressed: onToggle,
              child: Text(showAll ? 'See Less' : 'See More (${expenses.length - 8} more)')),
      ],
    );
  }
}

class _FinanceProductsPie extends StatelessWidget {
  final List<ProductStat> products;
  const _FinanceProductsPie({required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('Items Bought', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('No product data.', style: TextStyle(color: Colors.grey)),
      ]);
    }
    final sorted = [...products]..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final other = sorted.skip(5).fold<double>(0, (s, p) => s + p.value);
    final slices = <ProductStat>[
      ...top,
      if (other > 0)
        ProductStat(name: 'Other', value: other, sold: 0, amount: 0, profit: 0),
    ];
    const colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.grey];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Items Bought', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      SizedBox(height: 220, child: Row(children: [
        Expanded(flex: 2, child: PieChart(PieChartData(
          sections: List.generate(slices.length, (i) => PieChartSectionData(
            value: slices[i].value, color: colors[i % colors.length], title: '', radius: 70)),
        ))),
        Expanded(flex: 1, child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(slices.length, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Container(width: 10, height: 10, color: colors[i % colors.length]),
              const SizedBox(width: 6),
              Expanded(child: Text('${slices[i].name} (\$${slices[i].value.toStringAsFixed(0)})',
                  style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
            ]),
          )),
        )),
      ])),
    ]);
  }
}

class _FinanceCapital extends StatelessWidget {
  final CapitalStats stats;
  const _FinanceCapital({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('💰 Capital & Inventory Balance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('Based on current stock in shop and warehouse.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _tile('Total Items in Stock', '${stats.totalItems} units', Colors.blue),
        _tile('Current Capital (Cost)', '\$${stats.costCapital.toStringAsFixed(2)}', Colors.red),
        _tile('Expected Revenue (Sell)', '\$${stats.expectedRevenue.toStringAsFixed(2)}', Colors.purple),
        _tile('Potential Profit', '\$${stats.potentialProfit.toStringAsFixed(2)}', Colors.green),
      ]),
    ]);
  }

  Widget _tile(String label, String value, Color color) => SizedBox(
    width: 165, height: 90,
    child: Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    )),
  );
}

// ---------- INLINE DETAIL PANEL (expands under the chart on tap) ----------
class _InlineDetailPanel extends StatelessWidget {
  final GraphPoint point;
  final bool loading;
  final String? error;
  final DateSummary? summary;
  final List<ProductSoldDetail>? products;
  final List<PurchaseDetail>? purchases;
  final bool showProducts, showPurchases, showProfit;
  final VoidCallback onToggleProducts, onTogglePurchases, onToggleProfit, onClose;

  const _InlineDetailPanel({
    required this.point, required this.loading, required this.error,
    required this.summary, required this.products, required this.purchases,
    required this.showProducts, required this.showPurchases, required this.showProfit,
    required this.onToggleProducts, required this.onTogglePurchases,
    required this.onToggleProfit, required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Details for ${point.date}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ]),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
              )
            else if (summary != null) ...[
              // Top summary cards
              Wrap(spacing: 12, runSpacing: 12, children: [
                _mini('Revenue (After Discounts)',
                    '\$${summary!.totalRevenue.toStringAsFixed(2)}', Colors.green),
                _mini('Original Revenue',
                    '\$${summary!.totalOriginalRevenue.toStringAsFixed(2)}', Colors.blue),
                _mini('Discounts',
                    '\$${summary!.totalDiscounts.toStringAsFixed(2)}', Colors.orange,
                    sub: '${summary!.discountedOrders} orders'),
                _mini('Net Profit',
                    '\$${(summary!.totalRevenue - summary!.totalCOGS - point.expenditure).toStringAsFixed(2)}',
                    (summary!.totalRevenue - summary!.totalCOGS - point.expenditure) >= 0
                        ? Colors.green : Colors.red),
              ]),
              const SizedBox(height: 16),

              // Products sold
              _section(
                '🛍️ Products Sold (${products?.length ?? 0})',
                showProducts,
                onToggleProducts,
                (products?.isEmpty ?? true)
                    ? const Text('No products sold.', style: TextStyle(color: Colors.grey))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Product')),
                            DataColumn(label: Text('Qty')),
                            DataColumn(label: Text('Unit')),
                            DataColumn(label: Text('Cost')),
                            DataColumn(label: Text('Orig')),
                            DataColumn(label: Text('Disc')),
                            DataColumn(label: Text('Final')),
                            DataColumn(label: Text('Profit')),
                            DataColumn(label: Text('Margin')),
                          ],
                          rows: <DataRow>[
                            for (final p in products!)
                              DataRow(cells: [
                                DataCell(Text(p.product)),
                                DataCell(Text(p.quantity.toStringAsFixed(0))),
                                DataCell(Text('\$${p.unitPrice.toStringAsFixed(2)}')),
                                DataCell(Text('\$${p.stockPrice.toStringAsFixed(2)}')),
                                DataCell(Text('\$${p.originalTotal.toStringAsFixed(2)}')),
                                DataCell(Text(
                                  p.discount > 0
                                      ? '-\$${p.discount.toStringAsFixed(2)}'
                                      : '\$0.00',
                                  style: TextStyle(
                                      color: p.discount > 0 ? Colors.orange : null),
                                )),
                                DataCell(Text('\$${p.finalTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text('\$${p.profit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        color: p.profit >= 0 ? Colors.green : Colors.red))),
                                DataCell(Text(
                                  p.profitMargin != null
                                      ? '${p.profitMargin!.toStringAsFixed(1)}%'
                                      : '—',
                                )),
                              ]),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Purchases
              _section(
                '📦 Purchases & Inventory Updates (${purchases?.length ?? 0})',
                showPurchases,
                onTogglePurchases,
                (purchases?.isEmpty ?? true)
                    ? const Text('No purchases on this date.', style: TextStyle(color: Colors.grey))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Product')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Before')),
                            DataColumn(label: Text('After')),
                            DataColumn(label: Text('Change')),
                            DataColumn(label: Text('Spent')),
                            DataColumn(label: Text('Time')),
                          ],
                          rows: <DataRow>[
                            for (final p in purchases!)
                              DataRow(cells: [
                                DataCell(Text(p.productName)),
                                DataCell(Text(p.updateType)),
                                DataCell(Text(p.oldValue.toStringAsFixed(0))),
                                DataCell(Text(p.newValue.toStringAsFixed(0))),
                                DataCell(Text(p.change.toStringAsFixed(0))),
                                DataCell(Text('\$${p.amountSpent.toStringAsFixed(2)}')),
                                DataCell(Text(p.time)),
                              ]),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Profit breakdown
              _section(
                '📈 Profit Calculation',
                showProfit,
                onToggleProfit,
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _row('Total Revenue (After Discounts)',
                      '\$${summary!.totalRevenue.toStringAsFixed(2)}'),
                  _row('Original Revenue (Before Discounts)',
                      '\$${summary!.totalOriginalRevenue.toStringAsFixed(2)}',
                      color: Colors.grey),
                  _row('Total Discounts Given',
                      '-\$${summary!.totalDiscounts.toStringAsFixed(2)}',
                      color: Colors.orange),
                  _row('Less: COGS', '-\$${summary!.totalCOGS.toStringAsFixed(2)}'),
                  const Divider(),
                  _row(
                    '= Gross Profit',
                    '\$${(summary!.totalRevenue - summary!.totalCOGS).toStringAsFixed(2)}',
                    bold: true,
                  ),
                  _row('Less: Operating Expenses',
                      '-\$${point.expenditure.toStringAsFixed(2)}'),
                  const Divider(),
                  _row(
                    '= Net Profit',
                    '\$${(summary!.totalRevenue - summary!.totalCOGS - point.expenditure).toStringAsFixed(2)}',
                    bold: true,
                    fontSize: 18,
                    color: (summary!.totalRevenue - summary!.totalCOGS - point.expenditure) >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mini(String title, String value, Color color, {String? sub}) => SizedBox(
    width: 165, height: 95,
    child: Card(
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            if (sub != null)
              Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    ),
  );

  Widget _section(String title, bool expanded, VoidCallback onToggle, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Row(children: [
            Expanded(child: Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
          ]),
        ),
        if (expanded)
          Padding(padding: const EdgeInsets.only(top: 8), child: child),
      ],
    );
  }

  Widget _row(String label, String value,
      {Color? color, bool bold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : null, fontSize: fontSize)),
          ),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.bold : null,
                  fontSize: fontSize)),
        ],
      ),
    );
  }
}