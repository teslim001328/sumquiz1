import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumquiz/main.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sumquiz/services/notification_service.dart';

// Create a mock for the AuthService
class MockAuthService extends Mock implements AuthService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Create a mock AuthService instance
    final mockAuthService = MockAuthService();

    // When the user stream is accessed, return a stream that emits null.
    when(mockAuthService.user).thenAnswer((_) => Stream.value(null));

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
        authService: mockAuthService,
        notificationService: NotificationService()));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
