import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/wallet_models.dart';
import 'package:intl/intl.dart';

class TransactionExportService {
  static Future<String> exportToCSV(List<WalletTransaction> transactions) async {
    final buffer = StringBuffer();
    
    // CSV Header
    buffer.writeln('Date,Time,Type,Description,Amount (BYC),Status,Fee (BYC),Recipient,Sender,Transaction ID,Note');
    
    // CSV Rows
    for (final transaction in transactions) {
      final date = DateFormat('yyyy-MM-dd').format(transaction.timestamp);
      final time = DateFormat('HH:mm:ss').format(transaction.timestamp);
      final amount = transaction.amount.toStringAsFixed(2);
      final fee = transaction.fee.toStringAsFixed(2);
      final status = _getStatusText(transaction.status);
      final type = transaction.type.name.toUpperCase();
      
      buffer.writeln([
        date,
        time,
        type,
        _escapeCsvField(transaction.description),
        amount,
        status,
        fee,
        _escapeCsvField(transaction.recipientName ?? ''),
        _escapeCsvField(transaction.senderName ?? ''),
        transaction.transactionHash ?? '',
        _escapeCsvField(transaction.note ?? ''),
      ].join(','));
    }
    
    return buffer.toString();
  }

  static Future<String> exportToJSON(List<WalletTransaction> transactions) async {
    final List<Map<String, dynamic>> jsonList = transactions.map((t) => {
      'id': t.id,
      'type': t.type.name,
      'amount': t.amount,
      'status': t.status.name,
      'description': t.description,
      'timestamp': t.timestamp.toIso8601String(),
      'fee': t.fee,
      'recipientName': t.recipientName,
      'senderName': t.senderName,
      'transactionHash': t.transactionHash,
      'note': t.note,
    }).toList();
    
    return jsonEncode({
      'exportDate': DateTime.now().toIso8601String(),
      'totalTransactions': transactions.length,
      'transactions': jsonList,
    });
  }

  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.processing:
        return 'Processing';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
      case TransactionStatus.refunded:
        return 'Refunded';
    }
  }

  static Future<File> saveToFile(String content, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content);
    return file;
  }
}

