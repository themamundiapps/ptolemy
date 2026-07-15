// Google Identity Services refuses to launch sign-in from any
// application-provided UI on web -- only a button the SDK itself renders is
// allowed to trigger it. That widget lives in `google_sign_in_web`, which
// can't be imported unconditionally (it's web-only), so this file
// re-exports the right implementation per platform, mirroring the
// google_sign_in package's own example (web_wrapper.dart).
export 'google_web_button_stub.dart' if (dart.library.js_interop) 'google_web_button_web.dart';
