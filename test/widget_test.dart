import 'package:barq/firebase_options.dart';
import 'package:barq/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app builds without crashing', (WidgetTester tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await tester.pumpWidget(const YallaDeliveryApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
