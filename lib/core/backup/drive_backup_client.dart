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
  static const _fields = 'id,name,createdTime,size,appProperties';

  Future<Map<String, String>> _headers() async {
    final headers = await _auth.authHeaders();
    if (headers == null) {
      throw BackupException(
        'Google Drive access is missing. Sign out and sign in again.',
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

  /// Newest first.
  Future<List<CloudBackup>> list() async {
    final response = await http.get(
      Uri.parse(_filesUrl).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'orderBy': 'createdTime desc',
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

  Future<CloudBackup> upload({
    required String name,
    required String json,
    required BackupSummary summary,
  }) async {
    final boundary = 'sarisari${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': name,
      'parents': ['appDataFolder'],
      'mimeType': 'application/json',
      'appProperties': summary.toProps(),
    });
    final body =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$json\r\n'
        '--$boundary--';
    final headers = <String, String>{
      ...await _headers(),
      'Content-Type': 'multipart/related; boundary=$boundary',
    };
    final response = await http.post(
      Uri.parse(_uploadUrl).replace(
        queryParameters: {'uploadType': 'multipart', 'fields': _fields},
      ),
      headers: headers,
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
