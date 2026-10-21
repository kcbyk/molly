/// Bu platformda yerel dosyaya indirme desteklenmiyor.
Future<({bool ok, String? localPath})> streamUrlToLocalFile({
  required String url,
  required String safeId,
}) async {
  return (ok: false, localPath: null);
}
