import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brand_mobile_app/app.dart';
import 'package:brand_mobile_app/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';

void main() {
  HttpOverrides.global = MockHttpOverrides();
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseService.initialize();
  });

  testWidgets('App transitions from Splash to Login after animation completes', (tester) async {
    HttpOverrides.global = MockHttpOverrides();
    // Set a larger viewport to avoid RenderFlex overflows in test layout
    final dpi = tester.view.devicePixelRatio;
    tester.view.physicalSize = Size(600 * dpi, 1200 * dpi);

    await tester.pumpWidget(
      const ProviderScope(
        child: BrandApp(),
      ),
    );

    // Verify splash screen content is visible initially
    expect(find.text('Promo'), findsOneWidget);
    expect(find.text('Connect · Create · Collaborate'), findsOneWidget);

    // Wait for the splash screen animation timer to complete
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 1600));

    // Allow GoRouter transition to execute
    await tester.pumpAndSettle();

    // Verify that we successfully transitioned to the Login screen
    expect(find.textContaining('Sign in to'), findsOneWidget);
    expect(find.text('Your Email Address'), findsOneWidget);
    expect(find.text('Your Password'), findsOneWidget);

    // Reset the test view size
    tester.view.resetPhysicalSize();
  });
}

// ---------- Mock HTTP client using noSuchMethod to satisfy interface compilers ----------
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl || invocation.memberName == #openUrl) {
      return Future.value(MockHttpClientRequest());
    }
    return null;
  }
}

class MockHttpClientRequest implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #close) {
      return Future.value(MockHttpClientResponse());
    }
    if (invocation.memberName == #headers) {
      return MockHttpHeaders();
    }
    return null;
  }
}

class MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  static final List<int> _transparentImage = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
  ];

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
