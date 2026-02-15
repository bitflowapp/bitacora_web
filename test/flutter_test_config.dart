import 'dart:async';
import 'dart:io';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const allowHttp = bool.fromEnvironment(
    'ALLOW_HTTP_IN_TESTS',
    defaultValue: false,
  );
  if (!allowHttp) {
    HttpOverrides.global = _NoNetworkHttpOverrides();
  }
  await testMain();
}

class _NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _NoNetworkHttpClient();
  }
}

class _NoNetworkHttpClient implements HttpClient {
  Never _fail(Invocation invocation) {
    Uri? uri;
    for (final arg in invocation.positionalArguments) {
      if (arg is Uri) {
        uri = arg;
        break;
      }
    }
    final target = uri?.toString() ?? '<unknown>';
    throw UnsupportedError(
      'Outbound HTTP is blocked in widget/unit tests. '
      'Attempted target: $target. '
      'Use fake/mocked clients, or run integration-only flows with '
      '--dart-define=ALLOW_HTTP_IN_TESTS=true.',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _fail(invocation);
}
