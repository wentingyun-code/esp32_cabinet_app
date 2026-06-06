import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:esp32_cabinet_app/main.dart';
import 'package:esp32_cabinet_app/models/cabinet_data.dart';
import 'package:esp32_cabinet_app/services/mqtt_service.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    final cabinetData = CabinetData();
    final mqttService = MqttService(cabinetData);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cabinetData),
          Provider.value(value: mqttService),
        ],
        child: const AppRoot(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('环网柜实时监控'), findsOneWidget);
  });
}
