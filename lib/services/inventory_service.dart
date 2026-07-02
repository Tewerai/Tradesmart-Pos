import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/synced_product.dart';

class InventoryService {
  // Update local inventory with synced data from server
  static Future<void> updateLocalInventory(List<SyncedProduct> syncedProducts) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Extract data for storage
      List<String> productNames = [];
      List<String> productPrices = [];
      List<String> productCodes = [];
      Map<String, int> productQuantities = {}; // Store quantities separately
      
      for (var product in syncedProducts) {
        productNames.add(product.name);
        productPrices.add(product.price.toString());
        productCodes.add(product.code);
        productQuantities[product.code] = product.quantity;
      }
      
      // Save to SharedPreferences
      await prefs.setString('products', jsonEncode(productNames));
      await prefs.setString('prices', jsonEncode(productPrices));
      await prefs.setString('codes', jsonEncode(productCodes));
      await prefs.setString('quantities', jsonEncode(productQuantities));
      
      // Also save a timestamp of last sync
      await prefs.setString('last_inventory_sync', DateTime.now().toIso8601String());
      
      print('Inventory updated: ${syncedProducts.length} products synced');
      
    } catch (e) {
      print('Error updating local inventory: $e');
      rethrow;
    }
  }
  
  // Check if a product has sufficient quantity
  static Future<bool> hasSufficientQuantity(String productCode, double requestedQuantity) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Get stored quantities
    String? quantitiesJson = prefs.getString('product_quantities');
    if (quantitiesJson == null) {
      // No quantity data, assume sufficient (legacy behavior)
      return true;
    }
    
    Map<String, dynamic> quantities = jsonDecode(quantitiesJson);
    int availableQuantity = quantities[productCode] ?? -1;
    
    if (availableQuantity == -1) {
      // Product not found in quantity map (maybe quick sale item)
      return true;
    }
    
    return availableQuantity >= requestedQuantity;
  }
  
  // Get available quantity for a product
  static Future<int> getAvailableQuantity(String productCode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    String? quantitiesJson = prefs.getString('product_quantities');
    if (quantitiesJson == null) return -1;
    
    Map<String, dynamic> quantities = jsonDecode(quantitiesJson);
    return quantities[productCode] ?? -1;
  }
  
  // Show warning if quantity is low
  static void checkAndWarnLowQuantity(int quantity, String productName) {
    if (quantity >= 0 && quantity < 5) {
      Fluttertoast.showToast(
        msg: "⚠️ Low stock: $productName ($quantity left)",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    } else if (quantity == 0) {
      Fluttertoast.showToast(
        msg: "❌ Out of stock: $productName",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}