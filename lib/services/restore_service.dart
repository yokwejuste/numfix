import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'backup_service.dart';

class RestoreResult {
  final int totalEntries;
  final int restored;
  final int failed;
  final int notFound;
  final List<String> logs;

  RestoreResult({
    required this.totalEntries,
    required this.restored,
    required this.failed,
    required this.notFound,
    required this.logs,
  });
}

class RestoreService {
  static Future<RestoreResult> restoreFromBackup(
    BackupSession backup, {
    void Function(double)? onProgress,
    void Function(String)? onLog,
  }) async {
    final logs = <String>[];
    int restored = 0;
    int failed = 0;
    int notFound = 0;
    int processed = 0;
    final total = backup.entries.length;

    final contactIds = backup.entries.map((e) => e.contactId).toSet();
    final contactsMap = <String, Contact>{};

    debugPrint('RestoreService: Starting restore for ${backup.entries.length} entries');
    onLog?.call('Loading contacts...');
    logs.add('Loading contacts...');

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
        withAccounts: true,
      );

      debugPrint('RestoreService: Loaded ${contacts.length} contacts');

      for (final contact in contacts) {
        if (contactIds.contains(contact.id)) {
          contactsMap[contact.id] = contact;
        }
      }

      debugPrint('RestoreService: Found ${contactsMap.length} matching contacts out of ${contactIds.length} needed');
    } catch (e) {
      debugPrint('RestoreService: Failed to load contacts: $e');
      onLog?.call('Failed to load contacts: $e');
      logs.add('Failed to load contacts: $e');
      return RestoreResult(
        totalEntries: total,
        restored: 0,
        failed: total,
        notFound: 0,
        logs: logs,
      );
    }

    onLog?.call('Restoring ${backup.entries.length} changes...');
    logs.add('Restoring ${backup.entries.length} changes...');

    final modifiedContacts = <String, Contact>{};

    for (final entry in backup.entries) {
      debugPrint('RestoreService: Processing ${entry.contactName} (ID: ${entry.contactId})');
      try {
        final contact = contactsMap[entry.contactId];
        if (contact == null) {
          notFound++;
          debugPrint('RestoreService: Contact not found: ${entry.contactName}');
          onLog?.call('Not found: ${entry.contactName}');
          logs.add('Not found: ${entry.contactName}');
          processed++;
          onProgress?.call(total > 0 ? processed / total : 1.0);
          continue;
        }

        debugPrint('RestoreService: Contact has ${contact.phones.length} phones, need index ${entry.phoneIndex}');

        if (entry.phoneIndex >= contact.phones.length) {
          failed++;
          debugPrint('RestoreService: Phone index ${entry.phoneIndex} out of range (${contact.phones.length} phones)');
          onLog?.call('Phone index out of range: ${entry.contactName}');
          logs.add('Phone index out of range: ${entry.contactName}');
          processed++;
          onProgress?.call(total > 0 ? processed / total : 1.0);
          continue;
        }

        final currentPhone = contact.phones[entry.phoneIndex];
        debugPrint('RestoreService: Current phone at index: ${currentPhone.number}, expected: ${entry.newNumber}');

        if (currentPhone.number != entry.newNumber) {
          int matchIdx = -1;
          for (int i = 0; i < contact.phones.length; i++) {
            if (contact.phones[i].number == entry.newNumber) {
              matchIdx = i;
              break;
            }
          }

          if (matchIdx == -1) {
            failed++;
            debugPrint('RestoreService: Number ${entry.newNumber} not found in any phone slot');
            onLog?.call('Number not found: ${entry.contactName} (expected ${entry.newNumber})');
            logs.add('Number not found: ${entry.contactName} (expected ${entry.newNumber})');
            processed++;
            onProgress?.call(total > 0 ? processed / total : 1.0);
            continue;
          }

          debugPrint('RestoreService: Found number at different index: $matchIdx');
          contact.phones[matchIdx] = Phone(
            entry.originalNumber,
            label: contact.phones[matchIdx].label,
            customLabel: contact.phones[matchIdx].customLabel,
            isPrimary: contact.phones[matchIdx].isPrimary,
          );
        } else {
          contact.phones[entry.phoneIndex] = Phone(
            entry.originalNumber,
            label: currentPhone.label,
            customLabel: currentPhone.customLabel,
            isPrimary: currentPhone.isPrimary,
          );
        }

        modifiedContacts[entry.contactId] = contact;
        restored++;
        debugPrint('RestoreService: Restored ${entry.contactName}: ${entry.newNumber} -> ${entry.originalNumber}');
        onLog?.call('Restored: ${entry.contactName} ${entry.newNumber} -> ${entry.originalNumber}');
        logs.add('Restored: ${entry.contactName} ${entry.newNumber} -> ${entry.originalNumber}');
      } catch (e) {
        failed++;
        debugPrint('RestoreService: Error restoring ${entry.contactName}: $e');
        onLog?.call('Error restoring ${entry.contactName}: $e');
        logs.add('Error restoring ${entry.contactName}: $e');
      }

      processed++;
      if (processed % 5 == 0) {
        onProgress?.call(total > 0 ? processed / total : 1.0);
        await Future.delayed(Duration(milliseconds: 1));
      }
    }

    debugPrint('RestoreService: Saving ${modifiedContacts.length} contacts...');
    onLog?.call('Saving ${modifiedContacts.length} contacts...');
    logs.add('Saving ${modifiedContacts.length} contacts...');

    int saveErrors = 0;
    for (final contact in modifiedContacts.values) {
      try {
        debugPrint('RestoreService: Saving ${contact.displayName}...');
        await contact.update();
        debugPrint('RestoreService: Saved ${contact.displayName}');
      } catch (e) {
        saveErrors++;
        debugPrint('RestoreService: Failed to save ${contact.displayName}: $e');
        onLog?.call('Failed to save ${contact.displayName}: $e');
        logs.add('Failed to save ${contact.displayName}: $e');
      }
    }

    if (saveErrors > 0) {
      failed += saveErrors;
      restored -= saveErrors;
    }

    onProgress?.call(1.0);
    debugPrint('RestoreService: Complete - restored: $restored, failed: $failed, notFound: $notFound');
    onLog?.call('Restore complete: $restored restored, $failed failed, $notFound not found');
    logs.add('Restore complete: $restored restored, $failed failed, $notFound not found');

    return RestoreResult(
      totalEntries: total,
      restored: restored,
      failed: failed,
      notFound: notFound,
      logs: logs,
    );
  }
}
