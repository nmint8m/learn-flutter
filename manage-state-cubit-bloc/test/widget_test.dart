import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manage_state_cubit_bloc/main.dart';
import 'package:manage_state_cubit_bloc/sign_up/sign_up_repository.dart';

Future<void> _fillAndSubmit(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('nameField')), 'Kayla');
  await tester.enterText(
    find.byKey(const Key('emailField')),
    'kayla@example.com',
  );
  await tester.enterText(find.byKey(const Key('passwordField')), 'secret123');
  await tester.tap(find.byKey(const Key('termsCheckbox')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('submitButton')));
  await tester.pumpAndSettle();
}

void main() {
  const fastRepository = SignUpRepository(delay: Duration.zero);

  testWidgets('submitting an empty form shows errors', (tester) async {
    await tester.pumpWidget(const App(repository: fastRepository));

    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('You must accept the terms'), findsOneWidget);
  });

  testWidgets('Cubit tab: a valid form signs up', (tester) async {
    await tester.pumpWidget(const App(repository: fastRepository));

    await _fillAndSubmit(tester);

    expect(find.text('Welcome, Kayla!'), findsOneWidget);
  });

  testWidgets('Bloc tab: a valid form signs up', (tester) async {
    await tester.pumpWidget(const App(repository: fastRepository));
    await tester.tap(find.text('Bloc'));
    await tester.pumpAndSettle();
    expect(find.text('Sign up (Bloc)'), findsOneWidget);

    await _fillAndSubmit(tester);

    expect(find.text('Welcome, Kayla!'), findsOneWidget);
  });
}
