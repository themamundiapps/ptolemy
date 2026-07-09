import 'api_client.dart';

/// Maps a caught error to user-facing copy. Timeout and generic backend
/// failures get distinct messages since the right next action differs (try
/// a shorter range vs. just retry).
String friendlyApiError(Object error) {
  if (error is ApiTimeoutException) {
    return 'The scan is taking longer than expected — try a shorter date range.';
  }
  if (error is ApiException) {
    return 'Calculations temporarily unavailable — please try again shortly.';
  }
  return 'Something went wrong. Please try again.';
}
