import 'dart:convert';

import 'package:http/http.dart' as http;

/// Central helper for uploading files to Cloudinary. Used across all screens instead of
/// duplicating upload logic.
class CloudinaryService {
  static const String _cloudName = 'dsu1bewrx';
  static const String _uploadPreset = 'zad_upload';

  /// Uploads [bytes] and returns the Cloudinary secure_url, or null on failure.
  Future<String?> uploadBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );

      final response = await request.send();
      if (response.statusCode == 200) {
        final json = jsonDecode(await response.stream.bytesToString())
            as Map<String, dynamic>;
        return json['secure_url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
