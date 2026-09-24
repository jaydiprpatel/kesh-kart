import 'package:flutter/material.dart';
import 'package:kesh_kart/layout/keshkart_desktop_frame.dart';
import 'package:kesh_kart/bedrock_client.dart';

class GroomingMenuScreen extends StatefulWidget {
  final String barberId;
  const GroomingMenuScreen({super.key, required this.barberId});

  @override
  State<GroomingMenuScreen> createState() => _GroomingMenuScreenState();
}

class _GroomingMenuScreenState extends State<GroomingMenuScreen> {
  List<Map<String, dynamic>> services = [];
  bool isLoading = true;
  final List<String> predefinedServices = [
    'Haircut',
    'Beard Trim',
    'Facial',
    'Head Massage',
    'Shave',
    'Hair Color',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final doc = await BedrockClient().getDocument('users', widget.barberId);
    if (!mounted) return;

    if (doc != null) {
      final data = doc['data'] ?? {};
      if (data.containsKey('services')) {
        final serviceList = List<Map<String, dynamic>>.from(data['services']);
        setState(() {
          services = serviceList;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveServices() async {
    final saved = await BedrockClient().updateDocument(
      'users',
      widget.barberId,
      {'services': services},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? 'Could not save the menu. Please retry.'
              : 'Grooming menu updated successfully',
        ),
      ),
    );
  }

  void _editService(int? index) {
    final isNew = index == null;

    final predefinedServices =
        <String>{
          ...this.predefinedServices.map((service) => service.trim()),
        }.toList();
    final savedName = isNew ? '' : '${services[index]['name'] ?? ''}'.trim();
    final isSavedPreset = predefinedServices.contains(savedName);
    String selectedService = isNew ? '' : (isSavedPreset ? savedName : 'Other');
    bool isOther = !isNew && !isSavedPreset;

    final TextEditingController nameController = TextEditingController(
      text: isOther ? savedName : '',
    );

    final TextEditingController priceController = TextEditingController(
      text: isNew ? '' : services[index]['price'].toString(),
    );
    final TextEditingController durationController = TextEditingController(
      text:
          isNew
              ? '30'
              : (services[index]['durationMinutes'] ??
                      services[index]['duration'] ??
                      30)
                  .toString(),
    );

    final alreadyUsed =
        services
            .asMap()
            .entries
            .where((entry) => entry.key != index)
            .map((entry) => '${entry.value['name'] ?? ''}'.trim())
            .toSet();
    final availableOptions =
        <String>{
          if (selectedService.isNotEmpty &&
              predefinedServices.contains(selectedService))
            selectedService,
          ...predefinedServices.where(
            (service) =>
                service == selectedService || !alreadyUsed.contains(service),
          ),
        }.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder:
                    (context, setModalState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue:
                              selectedService.isNotEmpty && !isOther
                                  ? selectedService
                                  : null,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text("Choose service"),
                            ),
                            ...availableOptions.map((name) {
                              return DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              );
                            }),
                          ],
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Color(0xFF091426)),
                          decoration: const InputDecoration(
                            labelText: 'Select Service',
                            labelStyle: TextStyle(color: Color(0xFF54647A)),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE1E6EE)),
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              selectedService = val ?? '';
                              isOther = selectedService == 'Other';
                            });
                          },
                        ),
                        isOther
                            ? TextField(
                              controller: nameController,
                              enabled: isOther,
                              style: TextStyle(
                                color:
                                    isOther
                                        ? const Color(0xFF091426)
                                        : const Color(0xFF98A3B3),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Custom Service Name',
                                labelStyle: TextStyle(
                                  color:
                                      isOther
                                          ? const Color(0xFF54647A)
                                          : const Color(0xFF98A3B3),
                                ),
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFFE1E6EE),
                                  ),
                                ),
                                disabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFFF0F2F5),
                                  ),
                                ),
                              ),
                            )
                            : SizedBox(),

                        TextField(
                          controller: priceController,
                          style: const TextStyle(color: Color(0xFF091426)),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Price (₹)',
                            labelStyle: TextStyle(color: Color(0xFF54647A)),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE1E6EE)),
                            ),
                          ),
                        ),
                        TextField(
                          controller: durationController,
                          style: const TextStyle(color: Color(0xFF091426)),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Time required (minutes)',
                            helperText:
                                'Customers will only see slots that fit this time.',
                            labelStyle: TextStyle(color: Color(0xFF54647A)),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE1E6EE)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () async {
                            final newService = {
                              'name':
                                  isOther
                                      ? nameController.text.trim()
                                      : selectedService,
                              'price': priceController.text.trim(),
                              'durationMinutes': durationController.text.trim(),
                            };

                            if (newService['name']!.isEmpty ||
                                newService['price']!.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill all fields'),
                                ),
                              );
                              return;
                            }

                            final parsedPrice = double.tryParse(
                              newService['price']!,
                            );
                            final duration = int.tryParse(
                              newService['durationMinutes']!,
                            );
                            if (parsedPrice == null ||
                                !parsedPrice.isFinite ||
                                parsedPrice < 0 ||
                                duration == null ||
                                duration < 5 ||
                                duration > 360) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter a valid price and a duration from 5 to 360 minutes.',
                                  ),
                                ),
                              );
                              return;
                            }
                            newService['durationMinutes'] = duration.toString();
                            final previousServices =
                                List<Map<String, dynamic>>.from(services);
                            setState(() {
                              if (isNew) {
                                services.add(newService);
                              } else {
                                services[index] = newService;
                              }
                            });

                            final saved = await BedrockClient().updateDocument(
                              'users',
                              widget.barberId,
                              {'services': services},
                            );
                            if (saved == null) {
                              if (mounted) {
                                setState(() => services = previousServices);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not save this service. Please retry.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF091426),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
              ),
            ),
          ),
    );
  }

  Widget _getServiceIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('hair')) {
      return Image.asset('assets/images/haircut.png', height: 70);
    } else if (lower.contains('beard')) {
      return Image.asset('assets/images/haircut.png', height: 40);
    } else if (lower.contains('facial')) {
      return Image.asset('assets/images/haircut.png', height: 40);
    }
    return Image.asset('assets/images/haircut.png', height: 40);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Grooming Menu',
          style: TextStyle(color: Color(0xFF091426)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF091426),
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _saveServices,
            tooltip: 'Save grooming menu',
            icon: const Icon(Icons.save, color: Color(0xFF091426)),
          ),
        ],
      ),
      body: KeshKartDesktopFrame(
        maxWidth: 960,
        child:
            isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF091426)),
                )
                : services.isEmpty
                ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE1E6EE)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Color(0xFFCAD2DE),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 30,
                            color: Color(0xFF091426),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your Grooming Menu is empty.',
                          style: TextStyle(
                            color: Color(0xFF091426),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap + to add your first service!',
                          style: TextStyle(color: Color(0xFF54647A)),
                        ),
                      ],
                    ),
                  ),
                )
                : ListView.builder(
                  itemCount: services.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE1E6EE)),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          _getServiceIcon(service['name']),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        service['name'],
                                        style: const TextStyle(
                                          color: Color(0xFF091426),
                                          fontFamily: 'Popins',
                                          fontSize: 23,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '₹${service['price']} · ${service['durationMinutes'] ?? service['duration'] ?? 30} min',
                                        style: const TextStyle(
                                          fontFamily: 'Popins',
                                          color: Color(0xFF54647A),
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _editService(index),
                                      style: TextButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFE8F0FE,
                                        ),
                                        foregroundColor: const Color(
                                          0xFF174EA6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Edit'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed:
                                          () => setState(
                                            () => services.removeAt(index),
                                          ),
                                      style: TextButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFDECE8,
                                        ),
                                        foregroundColor: const Color(
                                          0xFFC43E23,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editService(null),
        backgroundColor: const Color(0xFF091426),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
