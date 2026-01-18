import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class DownloadsService {
  static const _channel = MethodChannel('numfyx/file_writer');

  static Future<String?> saveToDownloads({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
        'mimeType': mimeType,
      });
      return result;
    } catch (e) {
      return null;
    }
  }
}
