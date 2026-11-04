import 'package:flutter_test/flutter_test.dart';
import 'package:studylapse/main.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('StudyLapse démarre et permet de naviguer', (tester) async {
    await tester.pumpWidget(const StudyLapseApp());

    expect(find.text('StudyLapse'), findsOneWidget);
    expect(find.text('Construis ta progression.'), findsOneWidget);

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Session'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav_session')));
    await tester.pumpAndSettle();

    expect(find.text('Concentre-toi sur l’essentiel.'), findsOneWidget);
    expect(find.text('Démarrer'), findsOneWidget);
  });
}
