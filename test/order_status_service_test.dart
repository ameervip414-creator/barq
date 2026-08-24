import 'package:barq/order_status_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderStatusService', () {
    test('acceptance moves to in_route', () {
      final service = OrderStatusService();

      expect(service.captainAcceptsOrder('new'), 'in_route');
      expect(service.captainAcceptsOrder('accepted'), 'in_route');
      expect(service.captainAcceptsOrder('on_the_way'), 'in_route');
    });

    test('delivery moves to completed', () {
      final service = OrderStatusService();

      expect(service.captainMarksDelivered('in_route'), 'completed');
      expect(service.captainMarksDelivered('on_the_way'), 'completed');
      expect(service.captainMarksDelivered('delivered'), 'completed');
    });

    test('normalizes aliases for consistent UI', () {
      expect(OrderStatusService.normalizeStatus('on_the_way'), 'in_route');
      expect(OrderStatusService.normalizeStatus('delivered'), 'completed');
      expect(OrderStatusService.normalizeStatus('completed'), 'completed');
    });
  });
}
