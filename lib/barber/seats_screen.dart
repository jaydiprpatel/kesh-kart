import 'package:flutter/material.dart';
import '../bedrock_client.dart';

class BarberSeatsScreen extends StatefulWidget {
  const BarberSeatsScreen({super.key});
  @override
  State<BarberSeatsScreen> createState() => _BarberSeatsScreenState();
}

class _BarberSeatsScreenState extends State<BarberSeatsScreen> {
  List<Map<String, dynamic>> _seats = [];
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await BedrockClient.instance.keshKartSeats();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result == null || result['error'] != null) {
        _error = result?['error']?.toString() ?? 'Unable to load seats.';
      } else {
        _seats =
            (result['seats'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
      }
    });
  }

  Future<void> _save(Map<String, dynamic> changes) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await BedrockClient.instance.keshKartSeats(changes: changes);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null || result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?['error']?.toString() ?? 'Could not save the seat.',
          ),
        ),
      );
      return;
    }
    await _load();
  }

  Future<void> _edit([Map<String, dynamic>? seat]) async {
    var enteredName = seat?['name']?.toString() ?? '';
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(seat == null ? 'Add salon seat' : 'Rename seat'),
            content: TextFormField(
              initialValue: enteredName,
              onChanged: (value) => enteredName = value,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Seat name',
                hintText: 'e.g. Chair 1',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (enteredName.trim().isNotEmpty) {
                    Navigator.pop(context, enteredName.trim());
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (!mounted || name == null) return;
    await _save({
      if (seat != null) 'id': seat['id'],
      'name': name,
      'is_active': seat?['is_active'] ?? true,
    });
  }

  Future<void> _delete(Map<String, dynamic> seat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete ${seat['name']}?'),
            content: const Text(
              'This removes the seat from your salon list. It does not cancel appointments.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep seat'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (mounted && confirmed == true) {
      await _save({'id': seat['id'], 'delete': true});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Salon seats'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('Add seat'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            const Text('Manage names and availability of your salon seats.'),
            const Text(
              'Only active seats appear to customers. A selected seat is reserved for its booked time.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (!_busy && _error == null && _seats.isEmpty)
              const Text('No seats yet. Add your first salon seat.'),
            ..._seats.map(
              (seat) => Card(
                child: ListTile(
                  leading: const Icon(Icons.chair_outlined),
                  title: Text(seat['name'].toString()),
                  subtitle: Text(
                    seat['is_active'] == true ? 'Available' : 'Out of service',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: seat['is_active'] == true,
                        onChanged:
                            _busy
                                ? null
                                : (value) =>
                                    _save({...seat, 'is_active': value}),
                      ),
                      IconButton(
                        tooltip: 'Rename',
                        onPressed: _busy ? null : () => _edit(seat),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: _busy ? null : () => _delete(seat),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
