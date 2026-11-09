// credit_model.dart
class CreditRecord {
  final String id;
  final String debtorName;
  final String debtorPhone;
  final String debtorAddress;
  final String? debtorEmail;
  final double amount;
  final DateTime expectedDate;
  final DateTime createdAt;
  final String orderNumber;
  final String cashierName;
  final List<Map<String, dynamic>> products;
  final String? notes;
  bool settled;
  DateTime? settledAt;
  double? amountPaid;

  CreditRecord({
    required this.id,
    required this.debtorName,
    required this.debtorPhone,
    required this.debtorAddress,
    this.debtorEmail,
    required this.amount,
    required this.expectedDate,
    required this.createdAt,
    required this.orderNumber,
    required this.cashierName,
    required this.products,
    this.notes,
    this.settled = false,
    this.settledAt,
    this.amountPaid,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'debtorName': debtorName,
        'debtorPhone': debtorPhone,
        'debtorAddress': debtorAddress,
        'debtorEmail': debtorEmail,
        'amount': amount,
        'expectedDate': expectedDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'orderNumber': orderNumber,
        'cashierName': cashierName,
        'products': products,
        'notes': notes,
        'settled': settled,
        'settledAt': settledAt?.toIso8601String(),
        'amountPaid': amountPaid,
      };

  factory CreditRecord.fromJson(Map<String, dynamic> j) => CreditRecord(
        id: j['id'],
        debtorName: j['debtorName'],
        debtorPhone: j['debtorPhone'],
        debtorAddress: j['debtorAddress'],
        debtorEmail: j['debtorEmail'],
        amount: (j['amount'] as num).toDouble(),
        expectedDate: DateTime.parse(j['expectedDate']),
        createdAt: DateTime.parse(j['createdAt']),
        orderNumber: j['orderNumber'],
        cashierName: j['cashierName'],
        products: List<Map<String, dynamic>>.from(j['products']),
        notes: j['notes'],
        settled: j['settled'] ?? false,
        settledAt: j['settledAt'] != null
            ? DateTime.parse(j['settledAt'])
            : null,
        amountPaid: j['amountPaid'] != null
            ? (j['amountPaid'] as num).toDouble()
            : null,
      );
}