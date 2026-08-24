class OrderStatusService {
  static const String newStatus = 'new';
  static const String preparing = 'preparing';
  static const String accepted = 'accepted';
  static const String inRoute = 'in_route';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const Map<String, String> _aliases = {
    'new': newStatus,
    'pending': newStatus,
    'pending_order': newStatus,
    'preparing': preparing,
    'processing': preparing,
    'accepted': inRoute,
    'accept': inRoute,
    'captain_accept': inRoute,
    'captain_accepted': inRoute,
    'driver_accept': inRoute,
    'driver_accepted': inRoute,
    'in_route': inRoute,
    'inroute': inRoute,
    'in_route_accepted': inRoute,
    'in route': inRoute,
    'on_the_way': inRoute,
    'on the way': inRoute,
    'completed': completed,
    'complete': completed,
    'done': completed,
    'delivered': completed,
    'finished': completed,
    'cancelled': cancelled,
    'canceled': cancelled,
  };

  static String normalizeStatus(String? rawStatus) {
    if (rawStatus == null) return newStatus;

    final value = rawStatus.trim();
    if (value.isEmpty) return newStatus;

    final key = value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '_');
    return _aliases[key] ?? key;
  }

  String captainAcceptsOrder(String? rawStatus) {
    final normalized = OrderStatusService.normalizeStatus(rawStatus);
    if (normalized == completed || normalized == cancelled) {
      return normalized;
    }
    return inRoute;
  }

  String captainMarksDelivered(String? rawStatus) {
    final normalized = OrderStatusService.normalizeStatus(rawStatus);
    if (normalized == cancelled) {
      return cancelled;
    }
    return completed;
  }

  static String displayStatus(String? rawStatus) {
    switch (normalizeStatus(rawStatus)) {
      case newStatus:
        return 'جديد';
      case preparing:
        return 'قيد التحضير';
      case inRoute:
        return 'في الطريق';
      case completed:
        return 'مكتمل';
      case cancelled:
        return 'ملغي';
      default:
        return rawStatus?.trim().isNotEmpty == true
            ? rawStatus!.trim()
            : 'غير معروف';
    }
  }
}
