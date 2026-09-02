/// Platform-conditional database opener.
///
/// `drift/native` pulls in `dart:io` and `dart:ffi`, which do not exist in a
/// browser, so the implementation is switched at compile time. Native builds get
/// a real file; the web build uses drift's WASM backend — see db_opener_web.dart
/// for what that does and does not guarantee.
library;

export 'db_opener_native.dart' if (dart.library.js_interop) 'db_opener_web.dart';
