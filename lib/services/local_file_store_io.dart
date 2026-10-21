import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';

/// MP3'ü parça parça indirip uygulama klasörüne yazar.
/// Bellekte tüm dosyayı tutmadığı için büyük şarkılarda bile bellek şişmez.
Future<({bool ok, String? localPath})> streamUrlToLocalFile({
  required String url,
  required String safeId,
}) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final file = File('${docsDir.path}/molly_$safeId.mp3');

  try {
    debugPrint('MP3 indiriliyor: $url');

    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final ioClient = IOClient(httpClient);

    final request = http.Request('GET', Uri.parse(url));
    final streamedResponse = await ioClient.send(request).timeout(
      const Duration(seconds: 30),
    );

    if (streamedResponse.statusCode != 200) {
      debugPrint('İndirme HTTP hatası: ${streamedResponse.statusCode}');
      ioClient.close();
      return (ok: false, localPath: null);
    }

    final sink = file.openWrite();
    int totalBytes = 0;
    await for (final chunk in streamedResponse.stream) {
      sink.add(chunk);
      totalBytes += chunk.length;
    }
    await sink.flush();
    await sink.close();
    ioClient.close();

    if (totalBytes < 10000) {
      await file.delete();
      debugPrint('İndirme hatalı: dosya çok küçük ($totalBytes bytes)');
      return (ok: false, localPath: null);
    }

    debugPrint('✓ Dosya kaydedildi: ${file.path} ($totalBytes bytes)');
    return (ok: true, localPath: file.path);
  } catch (error) {
    debugPrint('İndirme hatası: $error');
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
    return (ok: false, localPath: null);
  }
}
