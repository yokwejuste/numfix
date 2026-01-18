import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactBackupEntry {
  final String contactId;
  final String contactName;
  final String originalNumber;
  final String newNumber;
  final int phoneIndex;

  ContactBackupEntry({
    required this.contactId,
    required this.contactName,
    required this.originalNumber,
    required this.newNumber,
    required this.phoneIndex,
  });

  Map<String, dynamic> toJson() => {
    'contactId': contactId,
    'contactName': contactName,
    'originalNumber': originalNumber,
    'newNumber': newNumber,
    'phoneIndex': phoneIndex,
  };

  factory ContactBackupEntry.fromJson(Map<String, dynamic> json) => ContactBackupEntry(
    contactId: json['contactId'] as String,
    contactName: json['contactName'] as String,
    originalNumber: json['originalNumber'] as String,
    newNumber: json['newNumber'] as String,
    phoneIndex: json['phoneIndex'] as int,
  );
}

class BackupSession {
  final String id;
  final DateTime timestamp;
  final String region;
  final int totalChanges;
  final List<ContactBackupEntry> entries;

  BackupSession({
    required this.id,
    required this.timestamp,
    required this.region,
    required this.totalChanges,
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'region': region,
    'totalChanges': totalChanges,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory BackupSession.fromJson(Map<String, dynamic> json) => BackupSession(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    region: json['region'] as String,
    totalChanges: json['totalChanges'] as int,
    entries: (json['entries'] as List).map((e) => ContactBackupEntry.fromJson(e as Map<String, dynamic>)).toList(),
  );

  String get formattedDate {
    final d = timestamp;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
           '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class BackupService {
  static const String _backupsKey = 'contact_backups';
  static const int _maxBackups = 10;

  static Future<List<BackupSession>> getBackups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_backupsKey);
      if (json == null || json.isEmpty) return [];

      final list = jsonDecode(json) as List;
      return list.map((e) => BackupSession.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('BackupService: Failed to load backups: $e');
      return [];
    }
  }

  static Future<void> saveBackup(BackupSession backup) async {
    try {
      final backups = await getBackups();
      backups.insert(0, backup);

      while (backups.length > _maxBackups) {
        backups.removeLast();
      }

      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(backups.map((e) => e.toJson()).toList());
      await prefs.setString(_backupsKey, json);
      debugPrint('BackupService: Saved backup ${backup.id} with ${backup.totalChanges} changes');
    } catch (e) {
      debugPrint('BackupService: Failed to save backup: $e');
    }
  }

  static Future<void> deleteBackup(String backupId) async {
    try {
      final backups = await getBackups();
      backups.removeWhere((b) => b.id == backupId);

      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(backups.map((e) => e.toJson()).toList());
      await prefs.setString(_backupsKey, json);
      debugPrint('BackupService: Deleted backup $backupId');
    } catch (e) {
      debugPrint('BackupService: Failed to delete backup: $e');
    }
  }

  static Future<void> clearAllBackups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_backupsKey);
      debugPrint('BackupService: Cleared all backups');
    } catch (e) {
      debugPrint('BackupService: Failed to clear backups: $e');
    }
  }

  static String generateBackupId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
