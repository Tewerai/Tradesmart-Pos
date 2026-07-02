class CashierShift {
  String name;
  DateTime shiftStart;
  DateTime? shiftEnd;
  String day;
  double hours;
  double sales;

  CashierShift({
    required this.name,
    required this.shiftStart,
    this.shiftEnd,
    required this.day,
    required this.hours,
    required this.sales,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'shiftStart': shiftStart.toIso8601String(),
        'shiftEnd': shiftEnd?.toIso8601String(),
        'day': day,
        'hours': hours,
        'sales': sales,
      };

  factory CashierShift.fromJson(Map<String, dynamic> json) => CashierShift(
        name: json['name'],
        shiftStart: DateTime.parse(json['shiftStart']),
        shiftEnd:
            json['shiftEnd'] != null ? DateTime.parse(json['shiftEnd']) : null,
        day: json['day'],
        hours: json['hours'],
        sales: json['sales'],
      );
}
