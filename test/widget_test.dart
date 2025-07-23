import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardscreen/main.dart'; // Make sure this import path is correct

void main() {
  testWidgets('DashboardScreen loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const MaterialApp(
      home: DashboardScreen(),
    ));

    // Verify that the app title is displayed
    expect(find.text('Trade Dashboard'), findsOneWidget);
    
    // Verify that the initial balance card is displayed
    expect(find.text('\$50000.00'), findsOneWidget);
  });

  testWidgets('Add trade functionality works', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DashboardScreen(),
    ));

    // Tap the 'Add Trade' button (initially disabled since no data entered)
    await tester.tap(find.text('Add Trade'));
    await tester.pump();

    // Verify no trade was added
    expect(find.text('Trade History'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    // Enter trade data
    await tester.enterText(find.byType(TextField).at(0), '2024-01-01');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.enterText(find.byType(TextField).at(2), '100.50');
    await tester.enterText(find.byType(TextField).at(3), 'Test trade');
    await tester.pump();

    // Tap the 'Add Trade' button
    await tester.tap(find.text('Add Trade'));
    await tester.pump();

    // Verify trade was added
    expect(find.text('2024-01-01 - Trade 1'), findsOneWidget);
    expect(find.text('PnL: \$100.50'), findsOneWidget);
  });
}

