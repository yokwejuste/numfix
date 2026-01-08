import 'package:libphonenumber_plugin/libphonenumber_plugin.dart';

class PhoneFormatterService {
  static Future<String?> formatToE164(String phoneNumber, String region) async {
    try {
      final trimmed = phoneNumber.trim();
      if (trimmed.startsWith('+') || trimmed.startsWith('00')) {
        return null;
      }

      String cleaned = trimmed;

      cleaned = cleaned.replaceAll(RegExp(r'[^\d+]'), '');

      if (cleaned.isEmpty || cleaned.length < 4) {
        return null;
      }

      String numberToValidate = cleaned;
      if (!cleaned.startsWith('+')) {
        final countryCode = _getCountryCode(region);
        numberToValidate = '+$countryCode$cleaned';
      }

      final bool? isValid = await PhoneNumberUtil.isValidPhoneNumber(
        numberToValidate,
        region,
      );

      if (isValid == true) {
        return numberToValidate;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static String _getCountryCode(String region) {
    const codes = {
      'CM': '237',
      'FR': '33',
      'US': '1',
      'GB': '44',
      'DE': '49',
      'IT': '39',
      'ES': '34',
      'CA': '1',
      'NG': '234',
      'GH': '233',
      'KE': '254',
      'ZA': '27',
      'EG': '20',
      'MA': '212',
      'TN': '216',
      'DZ': '213',
      'CI': '225',
      'SN': '221',
      'ML': '223',
      'BF': '226',
      'NE': '227',
      'TG': '228',
      'BJ': '229',
      'MR': '222',
      'TD': '235',
      'CF': '236',
      'CG': '242',
      'GA': '241',
      'GQ': '240',
      'CD': '243',
      'AO': '244',
      'GW': '245',
      'SC': '248',
      'SD': '249',
      'RW': '250',
      'ET': '251',
      'SO': '252',
      'DJ': '253',
      'UG': '256',
      'TZ': '255',
      'BI': '257',
      'MZ': '258',
      'ZM': '260',
      'MG': '261',
      'RE': '262',
      'ZW': '263',
      'NA': '264',
      'MW': '265',
      'LS': '266',
      'BW': '267',
      'SZ': '268',
      'KM': '269',
    };
    return codes[region] ?? '237'; // Default to Cameroon
  }
}
