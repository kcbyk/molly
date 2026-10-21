// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Tarayıcıda dosyayı indirme klasörüne kaydeder.
/// Yerel dosya yolu olmadığı için `localPath` null döner.
Future<({bool ok, String? localPath})> streamUrlToLocalFile({
  required String url,
  required String safeId,
}) async {
  try {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'molly_$safeId.mp3')
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    return (ok: true, localPath: null);
  } catch (_) {
    return (ok: false, localPath: null);
  }
}
