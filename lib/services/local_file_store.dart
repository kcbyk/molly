// Platforma göre indirme davranışı:
//  - io (Android/iOS/Windows): akış halinde diske yazar, dosya yolunu döner
//  - web: tarayıcının indirme mekanizmasını tetikler
export 'local_file_store_stub.dart'
    if (dart.library.io) 'local_file_store_io.dart'
    if (dart.library.html) 'local_file_store_web.dart';
