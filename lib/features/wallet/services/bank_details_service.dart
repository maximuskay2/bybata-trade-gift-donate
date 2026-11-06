import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bank_details_model.dart';

/// Service for managing saved bank account details locally
class BankDetailsService {
  static const String _storageKey = 'saved_bank_accounts';

  /// Save bank account details to local storage
  static Future<void> saveBankAccount(BankDetails account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await getSavedBankAccounts();
      
      // Check if account already exists (by account number)
      final existingIndex = accounts.indexWhere(
        (acc) => acc.accountNumber == account.accountNumber,
      );

      if (existingIndex >= 0) {
        // Update existing account
        accounts[existingIndex] = account;
      } else {
        // Add new account
        accounts.add(account);
      }

      // Save updated list
      final jsonList = accounts.map((acc) => jsonEncode(acc.toJson())).toList();
      await prefs.setStringList(_storageKey, jsonList);
    } catch (e) {
      print('Error saving bank account: $e');
    }
  }

  /// Get all saved bank accounts
  static Future<List<BankDetails>> getSavedBankAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? [];

      return jsonList
          .map((jsonString) {
            try {
              final json = jsonDecode(jsonString) as Map<String, dynamic>;
              return BankDetails.fromJson(json);
            } catch (e) {
              print('Error parsing bank account: $e');
              return null;
            }
          })
          .whereType<BankDetails>()
          .toList();
    } catch (e) {
      print('Error retrieving bank accounts: $e');
      return [];
    }
  }

  /// Delete a saved bank account
  static Future<void> deleteBankAccount(String accountNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await getSavedBankAccounts();

      accounts.removeWhere((acc) => acc.accountNumber == accountNumber);

      final jsonList = accounts.map((acc) => jsonEncode(acc.toJson())).toList();
      await prefs.setStringList(_storageKey, jsonList);
    } catch (e) {
      print('Error deleting bank account: $e');
    }
  }

  /// Clear all saved bank accounts
  static Future<void> clearAllBankAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      print('Error clearing bank accounts: $e');
    }
  }

  /// Get a specific bank account by account number
  static Future<BankDetails?> getBankAccountByNumber(String accountNumber) async {
    try {
      final accounts = await getSavedBankAccounts();
      return accounts.firstWhere(
        (acc) => acc.accountNumber == accountNumber,
        orElse: () => null as dynamic,
      ) as BankDetails?;
    } catch (e) {
      print('Error getting bank account: $e');
      return null;
    }
  }
}
