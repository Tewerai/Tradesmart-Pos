import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(settings);
    _initialized = true;
  }

  static Future<void> showLowStockNotification({
    required String productName,
    required int remainingQuantity,
    required String shopName,
  }) async {
    // Fixed: Removed 'const' and fixed color issues
    final AndroidNotificationDetails androidDetails = 
        AndroidNotificationDetails(
      'low_stock_channel',
      'Low Stock Alerts',
      channelDescription: 'Notifications when products are running low',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Colors.red, // Fixed: Use Color directly instead of value
      enableLights: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      styleInformation: const BigTextStyleInformation(
        '', // Will be set in the show method
        htmlFormatBigText: false,
        contentTitle: '⚠️ Low Stock Alert',
        summaryText: 'Product running out of stock',
      ),
    );
    
    const DarwinNotificationDetails iosDetails = 
        DarwinNotificationDetails(
      categoryIdentifier: 'lowStock',
      subtitle: 'Product running low',
    );
    
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    final int id = DateTime.now().millisecondsSinceEpoch.hashCode;
    
    await _notifications.show(
      id,
      '⚠️ Low Stock Alert',
      '$productName has only $remainingQuantity units left!',
      details,
    );
  }

  static Future<void> showMultipleLowStockNotification({
    required List<Map<String, dynamic>> lowStockProducts,
    required String shopName,
  }) async {
    if (lowStockProducts.isEmpty) return;
    
    StringBuffer productList = StringBuffer();
    for (var product in lowStockProducts) {
      productList.writeln('• ${product['name']}: ${product['quantity']} left');
    }
    
    // Fixed: Removed 'const' and fixed color issues
    final AndroidNotificationDetails androidDetails = 
        AndroidNotificationDetails(
      'low_stock_channel',
      'Low Stock Alerts',
      channelDescription: 'Notifications when products are running low',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Colors.orange, // Fixed: Use Color directly instead of value
      enableLights: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      styleInformation: BigTextStyleInformation(
        productList.toString(),
        htmlFormatBigText: false,
        contentTitle: '⚠️ Multiple Products Running Low',
        summaryText: 'Check stock levels',
      ),
    );
    
    const DarwinNotificationDetails iosDetails = 
        DarwinNotificationDetails(
      categoryIdentifier: 'lowStock',
      subtitle: 'Multiple products running low',
    );
    
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    final int id = DateTime.now().millisecondsSinceEpoch.hashCode;
    
    await _notifications.show(
      id,
      '⚠️ Low Stock Alerts',
      '${lowStockProducts.length} products are running low on stock',
      details,
    );
  }

  static Future<void> showOutOfStockNotification({
    required String productName,
    required String shopName,
  }) async {
    // Fixed: Removed 'const' and fixed color issues
    final AndroidNotificationDetails androidDetails = 
        AndroidNotificationDetails(
      'out_of_stock_channel',
      'Out of Stock Alerts',
      channelDescription: 'Notifications when products are out of stock',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Colors.red, // Fixed: Use Color directly instead of value
      enableLights: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      styleInformation: BigTextStyleInformation(
        '$productName is now OUT OF STOCK! Please restock immediately.',
        htmlFormatBigText: false,
        contentTitle: '🚫 Out of Stock Alert',
        summaryText: 'Product is out of stock',
      ),
    );
    
    const DarwinNotificationDetails iosDetails = 
        DarwinNotificationDetails(
      categoryIdentifier: 'outOfStock',
      subtitle: 'Product out of stock',
    );
    
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    final int id = DateTime.now().millisecondsSinceEpoch.hashCode;
    
    await _notifications.show(
      id,
      '🚫 Out of Stock Alert',
      '$productName is OUT OF STOCK!',
      details,
    );
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}