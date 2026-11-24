import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class NewStockItem {
  final String name;
  final double? price;
  final double? stockPrice;
  final double? quantity;
  final String? barcode;
  final String? category;

  NewStockItem({
    required this.name,
    this.price,
    this.stockPrice,
    this.quantity,
    this.barcode,
    this.category,
  });

  factory NewStockItem.fromJson(Map<String, dynamic> j) => NewStockItem(
        name: j['name']?.toString().trim() ?? '',
        price: (j['price'] as num?)?.toDouble(),
        stockPrice: (j['stock_price'] as num?)?.toDouble(),
        quantity: (j['quantity'] as num?)?.toDouble(),
        barcode: j['barcode']?.toString().trim(),
        category: j['category']?.toString().trim(),
      );

  bool get isComplete =>
      name.isNotEmpty &&
      price != null &&
      stockPrice != null &&
      quantity != null;
}

class AddStockAiService {
  static const _proxyUrl = 'https://blueichor.org/api/deepseek_proxy.php';
  final String shopid;
  AddStockAiService(this.shopid);

  // ====================================================================
  // Voice: single item
  // ====================================================================
  Future<NewStockItem?> parseVoiceSingleItem(String text) async {
    final prompt = '''
You are a stock-entry parser for a POS system.
The user is adding ONE new product by voice.

User said: "$text"

Return STRICT JSON with this shape and nothing else:
{"name":"<product name>","price":<sell price or null>,"stock_price":<cost price or null>,"quantity":<number or null>,"barcode":null,"category":null}

Rules:
- "price", "sell at", "sell for" → price
- "cost", "buy at", "stock price" → stock_price
- "quantity", "qty", "I have", "add" → quantity
- If a field is not mentioned, use null
- Keep the product name exactly as spoken, cleaned up (capitalize first letter)
''';

    final result = await _callDeepSeek(prompt: prompt);
    final item = NewStockItem.fromJson(result);
    return item.name.isEmpty ? null : item;
  }

  // ====================================================================
  // Voice: multiple items
  // ====================================================================
  Future<List<NewStockItem>> parseVoiceMultipleItems(String text) async {
    final prompt = '''
You are a stock-entry parser for a POS system.
The user is adding MULTIPLE new products by voice.

User said: "$text"

Return STRICT JSON:
{"items":[{"name":"<product name>","price":<sell price or null>,"stock_price":<cost price or null>,"quantity":<number or null>,"barcode":null,"category":null}]}

Rules:
- Detect each distinct product the user mentions
- "add 5 cokes price 2 stock 1.20" → 1 item with quantity 5, price 2, stock_price 1.20
- "add bread and milk" → 2 items, no prices/qty
- If a field is missing for an item, use null
- Keep names as spoken, capitalized
''';

    final result = await _callDeepSeek(prompt: prompt);
    final list = (result['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(NewStockItem.fromJson)
        .where((i) => i.name.isNotEmpty)
        .toList();
    return list;
  }

  // ====================================================================
  // Photo: printed receipt OR handwritten inventory book
  // ====================================================================
  Future<List<NewStockItem>> parseInventoryPhoto(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final ext = imageFile.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';

    const prompt = '''
You are an inventory extraction engine for a POS system.
Look at the image. It may be:
- a printed receipt or invoice
- a handwritten inventory list in a notebook
- a delivery note
- a photo of product labels

Extract every product line you can identify.

Return STRICT JSON:
{"items":[{"name":"<product name>","price":<sell price or null>,"stock_price":<cost price or null>,"quantity":<number or null>,"barcode":<string or null>,"category":<string or null>}]}

Rules:
- If the image is a handwritten book/list with columns like "Name | Qty | Buy | Sell", map the columns correctly
- If a column header is ambiguous, assume: first number after name = quantity, second = stock/cost price, third = sell price
- If only one price is shown, put it in stock_price (safer; user can adjust sell price in the review sheet)
- Barcode: extract if visible (usually a long digit sequence), else null
- Category: if written, use it. Else null
- Skip lines that are totals, tax, subtotal, change, date, time, phone, address
- If handwriting is unclear, skip that line rather than guessing
- Use the exact product name as written
''';

    final result = await _callDeepSeek(
      prompt: prompt,
      imageBase64: b64,
      imageMime: 'image/$ext',
    );
    final list = (result['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(NewStockItem.fromJson)
        .where((i) => i.name.isNotEmpty)
        .toList();
    return list;
  }

  // ====================================================================
  // Shared HTTP call
  // ====================================================================
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
      'max_tokens': 3000,
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