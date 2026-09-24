import 'package:flutter/material.dart';
import 'package:kesh_kart/customer/select_slot.dart';
import 'package:kesh_kart/theme/keshkart_theme.dart';

/// First booking step: customers choose one or more published services before
/// they can see appointment times.
class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key, required this.barber});

  final Map<String, dynamic> barber;

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  final Set<String> _selectedNames = <String>{};

  bool get _shopIsOpen =>
      widget.barber.containsKey('isOpen')
          ? widget.barber['isOpen'] == true
          : widget.barber['isActive'] == true;

  List<Map<String, dynamic>> get _menu {
    final raw = widget.barber['services'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (service) => Map<String, dynamic>.from(
            service,
          ).map((key, value) => MapEntry(key.toString(), value)),
        )
        .where((service) => _text(service['name']).isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> get _selectedServices =>
      _menu
          .where((service) => _selectedNames.contains(_text(service['name'])))
          .toList();

  int get _totalDuration =>
      _selectedServices.fold(0, (total, service) => total + _duration(service));

  double get _totalPrice => _selectedServices.fold(
    0,
    (total, service) => total + _price(service['price']),
  );

  @override
  Widget build(BuildContext context) {
    final menu = _menu;
    final shopName = _text(
      widget.barber['shopName'],
      fallback: _text(widget.barber['name'], fallback: 'Barber shop'),
    );
    return Scaffold(
      backgroundColor: KeshColors.warmIvory,
      appBar: AppBar(
        title: const Text('Choose services'),
        backgroundColor: KeshColors.warmIvory,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed:
                !_shopIsOpen || _selectedServices.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => SelectSlotScreen(
                              barber: widget.barber,
                              selectedServices: _selectedServices,
                            ),
                      ),
                    ),
            child: Text(
              !_shopIsOpen
                  ? 'Shop is closed'
                  : _selectedServices.isEmpty
                  ? 'Select at least one service'
                  : 'Choose a time',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
        children: [
          Text(
            shopName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select all the services you want. Your appointment length and available times update automatically.',
            style: TextStyle(color: KeshColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 22),
          if (menu.isEmpty)
            const _EmptyMenuCard()
          else ...[
            for (final service in menu)
              _ServiceTile(
                service: service,
                selected: _selectedNames.contains(_text(service['name'])),
                onChanged:
                    (selected) => setState(() {
                      final name = _text(service['name']);
                      if (selected) {
                        _selectedNames.add(name);
                      } else {
                        _selectedNames.remove(name);
                      }
                    }),
              ),
            if (_selectedServices.isNotEmpty) ...[
              const SizedBox(height: 14),
              _BookingSummary(
                count: _selectedServices.length,
                duration: _totalDuration,
                price: _totalPrice,
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _duration(Map<String, dynamic> service) {
    final value = service['durationMinutes'] ?? service['duration'];
    final duration = value is num ? value.toInt() : int.tryParse('$value');
    return (duration == null || duration < 5)
        ? 30
        : duration.clamp(5, 360).toInt();
  }

  static double _price(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.selected,
    required this.onChanged,
  });

  final Map<String, dynamic> service;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final name = service['name']?.toString().trim() ?? 'Service';
    final durationValue = service['durationMinutes'] ?? service['duration'];
    final duration =
        durationValue is num
            ? durationValue.toInt()
            : int.tryParse('$durationValue') ?? 30;
    final priceValue = service['price'];
    final price =
        priceValue is num
            ? priceValue.toDouble()
            : double.tryParse('$priceValue') ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? KeshColors.signatureCoral : KeshColors.borderIvory,
          width: selected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        activeColor: KeshColors.signatureCoral,
        controlAffinity: ListTileControlAffinity.trailing,
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '₹${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
              style: const TextStyle(
                color: KeshColors.signatureCoral,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '$duration min',
          style: const TextStyle(color: KeshColors.textSecondary),
        ),
        secondary: const CircleAvatar(
          backgroundColor: KeshColors.chipBackground,
          child: Icon(
            Icons.content_cut_outlined,
            color: KeshColors.navyPrimary,
          ),
        ),
      ),
    );
  }
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({
    required this.count,
    required this.duration,
    required this.price,
  });

  final int count;
  final int duration;
  final double price;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: KeshColors.navyPrimary,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Icon(Icons.event_available_outlined, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'service' : 'services'} · $duration min',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '₹${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _EmptyMenuCard extends StatelessWidget {
  const _EmptyMenuCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: KeshColors.borderIvory),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Column(
      children: [
        Icon(Icons.menu_book_outlined, size: 40, color: KeshColors.navyPrimary),
        SizedBox(height: 12),
        Text(
          'Menu not published yet',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text(
          'This shop must add its services and appointment times before customers can book.',
          textAlign: TextAlign.center,
          style: TextStyle(color: KeshColors.textSecondary),
        ),
      ],
    ),
  );
}
