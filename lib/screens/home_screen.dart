import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/phone_formatter_service.dart';
import '../services/settings_service.dart';
import '../models/contact_result.dart';
import '../widgets/buttons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static List<ContactResult> lastResults = [];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProcessing = false;
  bool _hasPermission = false;
  double _progress = 0.0;

  int _totalContacts = 0;
  int _contactsWithoutPhones = 0;
  int _scannedNumbers = 0;
  int _updatedNumbers = 0;
  int _skippedNumbers = 0;
  int _failedNumbers = 0;

  String _statusMessage = 'Ready to format contacts';
  String _currentRegion = 'CM';
  final List<ContactResult> _results = [];
  final List<String> _logMessages = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkPermission();
    await _loadRegion();
  }

  Future<void> _loadRegion() async {
    final region = await SettingsService.getDefaultRegion();
    setState(() {
      _currentRegion = region;
    });
  }

  Future<void> _checkPermission() async {
    final status = await Permission.contacts.status;
    setState(() {
      _hasPermission = status.isGranted;
      if (!_hasPermission) {
        _statusMessage = 'Contacts permission required';
      }
    });
  }

  Future<void> _requestPermission() async {
    final status = await Permission.contacts.request();
    setState(() {
      _hasPermission = status.isGranted;
      if (_hasPermission) {
        _statusMessage = 'Permission granted. Ready to format contacts';
      } else {
        _statusMessage = 'Permission denied. Cannot access contacts';
      }
    });
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add(message);
      if (_logMessages.length > 50) {
        _logMessages.removeAt(0);
      }
    });
  }

  String _maskPhoneNumber(String phoneNumber) {
    if (phoneNumber.length < 8) return phoneNumber;
    final start = phoneNumber.substring(0, 4);
    final end = phoneNumber.substring(phoneNumber.length - 2);
    return '$start${"x" * (phoneNumber.length - 6)}$end';
  }

  String _abbreviateName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) return parts[0];
    final first = parts[0];
    final rest = parts
        .sublist(1)
        .map((p) => p.isNotEmpty ? '${p[0]}.' : '')
        .join(' ');
    return '$first ${rest.trim()}';
  }

  Future<void> _processContacts() async {
    if (!_hasPermission) {
      await _requestPermission();
      return;
    }

    await _loadRegion();

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _totalContacts = 0;
      _contactsWithoutPhones = 0;
      _scannedNumbers = 0;
      _updatedNumbers = 0;
      _skippedNumbers = 0;
      _failedNumbers = 0;
      _statusMessage = 'Loading contacts...';
      _results.clear();
      _logMessages.clear();
    });

    _addLog('Starting contact processing...');
    _addLog('Using region: $_currentRegion');
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
        withAccounts: true,
      );

      _totalContacts = contacts.length;

      if (_totalContacts == 0) {
        setState(() {
          _statusMessage = 'No contacts found';
          _isProcessing = false;
        });
        _addLog('No contacts found on device');
        return;
      }

      _addLog('Loaded $_totalContacts contacts');

      setState(() {
        _statusMessage = 'Processing $_totalContacts contacts...';
      });

      int processedContacts = 0;

      for (final contact in contacts) {
        final contactName = contact.displayName.isNotEmpty
            ? contact.displayName
            : 'Unknown';

        if (contact.phones.isEmpty) {
          _contactsWithoutPhones++;
          final displayName = _abbreviateName(contactName);
          _addLog('Skipped: $displayName (no phone numbers)');
          processedContacts++;
          setState(() {
            _progress = processedContacts / _totalContacts;
          });
          continue;
        }

        bool contactModified = false;
        int numbersInContact = contact.phones.length;
        final displayName = _abbreviateName(contactName);

        if (numbersInContact > 1) {
          _addLog('$displayName has $numbersInContact phone numbers');
        }

        for (int i = 0; i < contact.phones.length; i++) {
          _scannedNumbers++;

          final phone = contact.phones[i];
          final originalNumber = phone.number.trim();

          if (originalNumber.isEmpty || originalNumber.length < 4) {
            _skippedNumbers++;
            _results.add(
              ContactResult(
                contactName: contactName,
                originalNumber: originalNumber,
                finalNumber: originalNumber,
                status: 'Skipped (too short)',
              ),
            );
            continue;
          }

          if (originalNumber.startsWith('+')) {
            _skippedNumbers++;
            _results.add(
              ContactResult(
                contactName: contactName,
                originalNumber: originalNumber,
                finalNumber: originalNumber,
                status: 'Skipped (already E.164)',
              ),
            );
            continue;
          }

          if (originalNumber.startsWith('00')) {
            final convertedNumber = '+${originalNumber.substring(2)}';
            contact.phones[i] = Phone(
              convertedNumber,
              label: phone.label,
              customLabel: phone.customLabel,
              isPrimary: phone.isPrimary,
            );
            contactModified = true;
            _updatedNumbers++;
            _results.add(
              ContactResult(
                contactName: contactName,
                originalNumber: originalNumber,
                finalNumber: convertedNumber,
                status: 'Updated',
              ),
            );
            _addLog(
              'Updated: $displayName - ${_maskPhoneNumber(originalNumber)} -> ${_maskPhoneNumber(convertedNumber)}',
            );
            continue;
          }

          final formattedNumber = await PhoneFormatterService.formatToE164(
            originalNumber,
            _currentRegion,
          );

          if (formattedNumber != null && formattedNumber != originalNumber) {
            contact.phones[i] = Phone(
              formattedNumber,
              label: phone.label,
              customLabel: phone.customLabel,
              isPrimary: phone.isPrimary,
            );
            contactModified = true;
            _updatedNumbers++;
            _results.add(
              ContactResult(
                contactName: contactName,
                originalNumber: originalNumber,
                finalNumber: formattedNumber,
                status: 'Updated',
              ),
            );
            _addLog(
              'Updated: $displayName - ${_maskPhoneNumber(originalNumber)} -> ${_maskPhoneNumber(formattedNumber)}',
            );
          } else {
            _failedNumbers++;
            _results.add(
              ContactResult(
                contactName: contactName,
                originalNumber: originalNumber,
                finalNumber: originalNumber,
                status: 'Failed (invalid)',
              ),
            );
            _addLog(
              'FAILED: $displayName - ${_maskPhoneNumber(originalNumber)} (invalid number)',
            );
          }
        }

        if (contactModified) {
          try {
            await contact.update();
            _addLog('Saved: $displayName');
          } catch (e) {
            _addLog('ERROR saving $displayName: ${e.toString()}');
            debugPrint('ERROR saving $displayName: ${e.toString()}');
          }
        }

        processedContacts++;
        setState(() {
          _progress = processedContacts / _totalContacts;
          _statusMessage = 'Processing... $_updatedNumbers updated';
        });
      }

      setState(() {
        _statusMessage = 'Completed successfully';
        _isProcessing = false;
        _progress = 1.0;
      });

      _addLog('Processing complete');
      _addLog(
        'Updated: $_updatedNumbers | Skipped: $_skippedNumbers | Failed: $_failedNumbers',
      );

      HomeScreen.lastResults = List.from(_results);
      _addLog('Processing complete. Generate report from Settings.');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _isProcessing = false;
      });
      _addLog('Error: ${e.toString()}');
      debugPrint('\nERROR: ${e.toString()}');
    }
  }

  void _resetStats() {
    setState(() {
      _progress = 0.0;
      _totalContacts = 0;
      _contactsWithoutPhones = 0;
      _scannedNumbers = 0;
      _updatedNumbers = 0;
      _skippedNumbers = 0;
      _failedNumbers = 0;
      _statusMessage = 'Ready to format contacts';
      _results.clear();
      _logMessages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo/logo_96.png',
                    width: 32,
                    height: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NumFyx',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Region: $_currentRegion',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _hasPermission ? Icons.check_circle : Icons.info_outline,
                    color: _hasPermission ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isProcessing) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 120,
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.phone_android,
                            size: 36,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_totalContacts > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow('Contacts', _totalContacts.toString(), theme),
                    _buildStatRow(
                      'Without Phones',
                      _contactsWithoutPhones.toString(),
                      theme,
                    ),
                    _buildStatRow('Scanned', _scannedNumbers.toString(), theme),
                    _buildStatRow('Updated', _updatedNumbers.toString(), theme),
                    _buildStatRow('Skipped', _skippedNumbers.toString(), theme),
                    _buildStatRow('Failed', _failedNumbers.toString(), theme),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_logMessages.isNotEmpty) ...[
              Text(
                'Activity Log',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    itemCount: _logMessages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          _logMessages[index],
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.secondary,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else if (!_isProcessing)
              const Spacer(),

            if (!_hasPermission)
              PrimaryButton(
                onPressed: _isProcessing ? null : _requestPermission,
                icon: Icons.check_circle_outline,
                label: 'Grant Permission',
              )
            else
              PrimaryButton(
                onPressed: _isProcessing ? null : _processContacts,
                icon: _isProcessing ? Icons.hourglass_empty : Icons.play_arrow,
                label: _isProcessing ? 'Processing...' : 'Start Formatting',
                isLoading: _isProcessing,
              ),

            if (_totalContacts > 0 && !_isProcessing) ...[
              const SizedBox(height: 12),
              SecondaryButton(
                onPressed: _resetStats,
                icon: Icons.refresh,
                label: 'Reset Statistics',
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.grey[850]
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
