import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/google_auth_service.dart';
import 'backup_models.dart';

/// Talks to the app's private folder in the user's Google Drive.
class DriveBackupClient {
  DriveBackupClient(this._auth);
  final GoogleAuthService _auth;

  static const _filesUrl = 'https://www.googleapis.com/drive/v3/files';
  static const _uploadUrl = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _fields = 'id,name,createdTime,modifiedTime,size,appProperties';

  Future<Map<String, String>> _headers() async {
    final headers = await _auth.authHeaders();
    if (headers == null) {
      throw BackupException(
        'Not connected to Google. Open More → Backup and tap Reconnect.',
      );
    }
    return headers;
  }

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      throw BackupException(
        'Your Google session expired. Sign out and sign in again.',
      );
    }
    throw BackupException(
      'Google Drive said ${response.statusCode}: ${response.body}',
    );
  }

  /// Most recently updated first.
  Future<List<CloudBackup>> list() async {
    final response = await http.get(
      Uri.parse(_filesUrl).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'orderBy': 'modifiedTime desc',
          'pageSize': '50',
          'fields': 'files($_fields)',
        },
      ),
      headers: await _headers(),
    );
    _check(response);
    final files = (jsonDecode(response.body)['files'] as List)
        .cast<Map<String, dynamic>>();
    return files.map(CloudBackup.fromJson).toList();
  }

  // Builds the "details + file content" body Drive expects. Returns the body
  // and the Content-Type header (which carries the boundary).
  (String, String) _multipart(Map<String, Object?> metadata, String json) {
    final boundary = 'sarisari${DateTime.now().microsecondsSinceEpoch}';
    final body =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '${jsonEncode(metadata)}\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$json\r\n'
        '--$boundary--';
    return (body, 'multipart/related; boundary=$boundary');
  }

  Future<CloudBackup> upload({
    required String name,
    required String json,
    required BackupSummary summary,
  }) async {
    final (body, contentType) = _multipart({
      'name': name,
      'parents': ['appDataFolder'],
      'mimeType': 'application/json',
      'appProperties': summary.toProps(),
    }, json);
    final response = await http.post(
      Uri.parse(_uploadUrl).replace(
        queryParameters: {'uploadType': 'multipart', 'fields': _fields},
      ),
      headers: {...await _headers(), 'Content-Type': contentType},
      body: utf8.encode(body),
    );
    _check(response);
    return CloudBackup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Replaces the content of an existing backup file.
  Future<CloudBackup> update({
    required String id,
    required String json,
    required BackupSummary summary,
  }) async {
    final (body, contentType) = _multipart({
      'appProperties': summary.toProps(),
    }, json);
    final response = await http.patch(
      Uri.parse('$_uploadUrl/$id').replace(
        queryParameters: {'uploadType': 'multipart', 'fields': _fields},
      ),
      headers: {...await _headers(), 'Content-Type': contentType},
      body: utf8.encode(body),
    );
    _check(response);
    return CloudBackup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> download(String id) async {
    final response = await http.get(
      Uri.parse('$_filesUrl/$id?alt=media'),
      headers: await _headers(),
    );
    _check(response);
    return utf8.decode(response.bodyBytes);
  }

  Future<void> delete(String id) async {
    final response = await http.delete(
      Uri.parse('$_filesUrl/$id'),
      headers: await _headers(),
    );
    _check(response);
  }
}
