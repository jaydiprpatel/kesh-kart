import 'package:flutter/material.dart';
import '../models/grooming_service.dart';

class BookingProvider extends ChangeNotifier {
  final List<GroomingService> _addedServices = [];

  List<GroomingService> get addedServices => List.unmodifiable(_addedServices);

  double get totalAmount => _addedServices.fold(0, (sum, item) => sum + item.price);

  void addService(GroomingService service) {
    if (!_addedServices.any((s) => s.id == service.id)) {
      _addedServices.add(service);
      notifyListeners();
    }
  }

  void removeService(String serviceId) {
    _addedServices.removeWhere((s) => s.id == serviceId);
    notifyListeners();
  }

  bool isAdded(String serviceId) {
    return _addedServices.any((s) => s.id == serviceId);
  }

  void clearBooking() {
    _addedServices.clear();
    notifyListeners();
  }
}
