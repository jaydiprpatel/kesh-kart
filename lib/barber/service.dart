import 'package:flutter/material.dart';
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
    await BedrockClient().updateDocument(
      'users', 
      widget.barberId, 
      {'services': services}
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grooming menu updated successfully')),
    );
  }

  void _editService(int? index) {
    final isNew = index == null;

    final List<String> predefinedServices = [
      'Hair cut',
      'Beard Trim',
      'Facial',
      'Head Massage',
      'Shave',
      'Hair Color',
      'Other',
    ];

    String selectedService = isNew ? '' : services[index]['name'];
    bool isOther = false;

    final TextEditingController nameController = TextEditingController();

    final TextEditingController priceController = TextEditingController(
      text: isNew ? '' : services[index]['price'].toString(),
    );

    final List<String> alreadyUsed =
        services
            .map((s) => s['name'] as String)
            .where((s) => s != selectedService) // allow editing same value
            .toList();

    final List<String> availableOptions =
        predefinedServices.where((s) => !alreadyUsed.contains(s)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
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
                          value:
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
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Select Service',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              selectedService = val ?? '';
                              if (selectedService == 'Other') {
                                isOther = true;
                              } else {
                                isOther = false;
                              }
                            });
                            setModalState(() {}); // update inside modal
                          },
                        ),
                        isOther
                            ? TextField(
                              controller: nameController,
                              enabled: isOther,
                              style: TextStyle(
                                color: isOther ? Colors.white : Colors.white54,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Custom Service Name',
                                labelStyle: TextStyle(
                                  color:
                                      isOther ? Colors.white70 : Colors.white38,
                                ),
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white54),
                                ),
                                disabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white30),
                                ),
                              ),
                            )
                            : SizedBox(),

                        TextField(
                          controller: priceController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Price (₹)',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
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

                            setState(() {
                              if (isNew) {
                                services.add(newService);
                              } else {
                                services[index] = newService;
                              }
                            });

                            await BedrockClient().updateDocument(
                              'users', 
                              widget.barberId, 
                              {'services': services}
                            );

                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Grooming Menu',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _saveServices,
            icon: const Icon(Icons.save, color: Colors.white),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : services.isEmpty
              ? Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your Grooming Menu is empty.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap + to add your first service!',
                        style: TextStyle(color: Colors.white54),
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
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
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
                                        color: Colors.white,
                                        fontFamily: 'Popins',
                                        fontSize: 23,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '₹${service['price']}',
                                      style: const TextStyle(
                                        fontFamily: 'Popins',
                                        color: Colors.white,
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
                                      backgroundColor: Colors.greenAccent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
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
                                      backgroundColor: Colors.greenAccent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editService(null),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}
