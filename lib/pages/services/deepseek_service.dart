import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../models/stock.dart';

class StockUpdateItem {
  final String product;
  final double? quantityChange; // delta, can be negative
  final double? quantitySet;    // absolute
  final double? price;
  final double? stockPrice;

  StockUpdateItem({
    required this.product,
    this.quantityChange,
    this.quantitySet,
    this.price,
    this.stockPrice,
  });

  factory StockUpdateItem.fromJson(Map<String, dynamic> j) => StockUpdateItem(
    product: j['product']?.toString() ?? '',
    quantityChange: (j['quantity_change'] as num?)?.toDouble(),
    quantitySet: (j['quantity_set'] as num?)?.toDouble(),
    price: (j['price'] as num?)?.toDouble(),
    stockPrice: (j['stock_price'] as num?)?.toDouble(),
  );

  double? resolveQuantity(double currentQty) {
    if (quantitySet != null) return quantitySet;
    if (quantityChange != null) return currentQty + quantityChange!;
    return null;
  }

  bool get hasAnyChange =>
      quantityChange != null ||
      quantitySet != null ||
      price != null ||
      stockPrice != null;
}

class DeepSeekService {
  // Must match your deployed PHP proxy path
  static const _proxyUrl = 'https://blueichor.org/api/deepseek_proxy.php';
  final String shopid;
  DeepSeekService(this.shopid);

  Future<List<StockUpdateItem>> parseTextCommand(
      String text, List<StockProduct> products) async {
    final catalog = products.map((p) => p.name).toList();
    final catalogStr = catalog.take(500).join(' | '); // cap at 500 for token cost

    final prompt = '''
You are a stock-update parser for a POS system.
Available products in this shop:
$catalogStr

User said: "$text"

Return STRICT JSON with this schema and nothing else:
{"updates":[{"product":"<closest available product name>","quantity_change":<number|null>,"quantity_set":<number|null>,"price":<number|null>,"stock_price":<number|null>}]}

Rules:
- "add 5", "received 5", "got 5" → quantity_change: 5
- "remove 2", "sold 2", "lost 2", "reduce by 2" → quantity_change: -2
- "set to 10", "make it 10", "now 10" → quantity_set: 10
- "price 2.50", "sell at 2.50" → price: 2.50
- "cost 1.20", "buy at 1.20" → stock_price: 1.20
- Default to quantity_change when ambiguous (delta)
- Match product names to the CLOSEST available product from the list above
- If user mentions multiple products, return multiple items
- Only include fields the user actually mentioned; use null otherwise
''';

    final result = await _callDeepSeek(prompt: prompt);
    return _parseUpdates(result);
  }

  Future<List<StockUpdateItem>> parseReceiptImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final ext = imageFile.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';

    const prompt = '''
You are a receipt/invoice OCR extractor for a POS system.
Look at the image and extract all product line items.

Return STRICT JSON:
{"updates":[{"product":"<name from receipt>","quantity_change":<number>,"stock_price":<number|null>,"price":<number|null>}]}

Rules:
- quantity_change = number of units received (positive)
- stock_price = cost/unit if shown, else null
- price = sell price/unit if shown, else null
- Use the product name as printed on the receipt
- Skip subtotal/tax/total lines
- If a line is unreadable, skip it
''';

    final result = await _callDeepSeek(
      prompt: prompt,
      imageBase64: b64,
      imageMime: 'image/$ext',
    );
    return _parseUpdates(result);
  }

  List<StockUpdateItem> _parseUpdates(Map<String, dynamic> result) {
    final list = result['updates'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(StockUpdateItem.fromJson)
        .where((u) => u.product.isNotEmpty && u.hasAnyChange)
        .toList();
  }

  Future<Map<String, dynamic>> _callDeepSeek({
    required String prompt,
    String? imageBase64,
    String? imageMime,
  }) async {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
    ];
    if (imageBase64 != null && imageMime != null) {
      content.add({
        'type': 'image_url',
        'image_url': {'url': 'data:$imageMime;base64,$imageBase64'},
      });
    }

    final body = {
      'shopid': shopid,
      'model': 'deepseek-flash',
      'messages': [
        {'role': 'user', 'content': content},
      ],
      'response_format': {'type': 'json_object'},
      'max_tokens': 2000,
    };

    final resp = await http.post(
      Uri.parse(_proxyUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw Exception('AI proxy ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = data['choices']?[0]?['message']?['content']?.toString() ?? '{}';
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}