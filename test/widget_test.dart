
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_notebook/app.dart';

void main() {
  testWidgets('La aplicación inicia correctamente', (tester) async {
    await tester.pumpWidget(const GymNotebookApp());

    expect(find.text('GYM NOTEBOOK'), findsOneWidget);
  });
}
