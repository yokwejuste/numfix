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
    List<Contact> contacts = [];

    onLog?.call('Loading contacts...');
    logs.add('Loading contacts...');

    try {
      contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
        withAccounts: true,
      );

      for (final contact in contacts) {
        if (contactIds.contains(contact.id)) {
          contactsMap[contact.id] = contact;
        }
      }
    } catch (e) {
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
      try {
        var contact = contactsMap[entry.contactId];
        if (contact == null) {
          final fallbackContact = contacts.where((c) => c.displayName == entry.contactName).toList();
          if (fallbackContact.isNotEmpty) {
            contact = fallbackContact.first;
          } else {
            notFound++;
            onLog?.call('Not found: ${entry.contactName}');
            logs.add('Not found: ${entry.contactName}');
            processed++;
            onProgress?.call(total > 0 ? processed / total : 1.0);
            continue;
          }
        }

        if (entry.phoneIndex >= contact.phones.length) {
          failed++;
          onLog?.call('Phone index out of range: ${entry.contactName}');
          logs.add('Phone index out of range: ${entry.contactName}');
          processed++;
          onProgress?.call(total > 0 ? processed / total : 1.0);
          continue;
        }

        final currentPhone = contact.phones[entry.phoneIndex];

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
            onLog?.call('Number not found: ${entry.contactName} (expected ${entry.newNumber})');
            logs.add('Number not found: ${entry.contactName} (expected ${entry.newNumber})');
            processed++;
            onProgress?.call(total > 0 ? processed / total : 1.0);
            continue;
          }

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
        onLog?.call('Restored: ${entry.contactName} ${entry.newNumber} -> ${entry.originalNumber}');
        logs.add('Restored: ${entry.contactName} ${entry.newNumber} -> ${entry.originalNumber}');
      } catch (e) {
        failed++;
        onLog?.call('Error restoring ${entry.contactName}: $e');
        logs.add('Error restoring ${entry.contactName}: $e');
      }

      processed++;
      if (processed % 5 == 0) {
        onProgress?.call(total > 0 ? processed / total : 1.0);
        await Future.delayed(Duration(milliseconds: 1));
      }
    }

    onLog?.call('Saving ${modifiedContacts.length} contacts...');
    logs.add('Saving ${modifiedContacts.length} contacts...');

    int saveErrors = 0;
    for (final contact in modifiedContacts.values) {
      try {
        await contact.update();
      } catch (e) {
        saveErrors++;
        onLog?.call('Failed to save ${contact.displayName}: $e');
        logs.add('Failed to save ${contact.displayName}: $e');
      }
    }

    if (saveErrors > 0) {
      failed += saveErrors;
      restored -= saveErrors;
    }

    onProgress?.call(1.0);
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
