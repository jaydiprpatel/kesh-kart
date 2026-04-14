import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';

class GroomingMenuScreen extends StatefulWidget {
  final String barberId;
  const GroomingMenuScreen({super.key, required this.barberId});

  @override
  State<GroomingMenuScreen> createState() => _GroomingMenuScreenState();
}

class _GroomingMenuScreenState extends State<GroomingMenuScreen> {
  List<Map<String, dynamic>> services = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final doc =
          await BaasClient.collection('users').doc(widget.barberId).get();
      if (doc.exists && doc.data()!.containsKey('services')) {
        setState(() {
          services = List<Map<String, dynamic>>.from(doc['services']);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading services: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveServices() async {
    try {
      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'services': services});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grooming menu updated successfully')),
        );
      }
    } catch (e) {
      debugPrint("Error saving services: $e");
    }
  }

  void _editService(int? index) {
    final isNew = index == null;
    final List<String> predefinedNames = [
      'Haircut',
      'Beard Trim',
      'Facial',
      'Head Massage',
      'Shave',
      'Hair Color',
      'Other',
    ];
    final List<String> categoriesList = [
      'General',
      'Hair',
      'Beard',
      'Face',
      'Massage',
      'Combos',
      'Other',
    ];

    String selectedName = isNew ? '' : services[index]['name'];
    String selectedCategory =
        isNew ? 'Hair' : (services[index]['category'] ?? 'General');
    int selectedDuration =
        isNew ? 30 : (services[index]['duration'] as int? ?? 30);
    List<Map<String, dynamic>> variants =
        isNew
            ? []
            : List<Map<String, dynamic>>.from(
              services[index]['variants'] ?? [],
            );

    final nameController = TextEditingController(text: selectedName);
    final descController = TextEditingController(
      text: isNew ? '' : (services[index]['description'] ?? ''),
    );
    final priceController = TextEditingController(
      text:
          isNew
              ? ''
              : (services[index]['price']?.toString() ?? '').replaceAll(
                '*',
                '',
              ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setModalState) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    left: 20,
                    right: 20,
                    top: 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value:
                              predefinedNames.contains(selectedName)
                                  ? selectedName
                                  : 'Other',
                          items:
                              predefinedNames
                                  .map(
                                    (n) => DropdownMenuItem(
                                      value: n,
                                      child: Text(n),
                                    ),
                                  )
                                  .toList(),
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Service Type',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          onChanged:
                              (val) => setModalState(() {
                                selectedName = val ?? '';
                                if (selectedName != 'Other') {
                                  nameController.text = selectedName;
                                }
                              }),
                        ),
                        if (selectedName == 'Other')
                          TextField(
                            controller: nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Custom Name',
                            ),
                          ),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          items:
                              categoriesList
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          onChanged:
                              (val) => setModalState(
                                () => selectedCategory = val ?? 'General',
                              ),
                        ),
                        TextField(
                          controller: priceController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Base Price (₹)',
                          ),
                        ),
                        TextField(
                          controller: descController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        DropdownButtonFormField<int>(
                          value: selectedDuration,
                          items:
                              [15, 30, 45, 60, 90, 120]
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text("$m Min"),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (v) => setModalState(() => selectedDuration = v!),
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        _buildVariantManager(
                          ctx,
                          variants,
                          (v) => setModalState(() => variants = v),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (nameController.text.isEmpty ||
                                  (variants.isEmpty &&
                                      priceController.text.isEmpty)) {
                                return;
                              }
                              final finalPrice =
                                  variants.isNotEmpty
                                      ? "*${variants.map((v) => double.tryParse(v['price'].toString()) ?? 0).reduce((a, b) => a < b ? a : b)}"
                                      : priceController.text;
                              final newService = {
                                'name': nameController.text.trim(),
                                'category': selectedCategory,
                                'price': finalPrice,
                                'duration': selectedDuration,
                                'description': descController.text.trim(),
                                'variants': variants,
                              };
                              setState(() {
                                if (isNew) {
                                  services.add(newService);
                                } else {
                                  services[index] = newService;
                                }
                              });
                              _saveServices();
                              Navigator.pop(ctx);
                            },
                            child: const Text("Save Service"),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildVariantManager(
    BuildContext context,
    List<Map<String, dynamic>> variants,
    Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Styles / Brands",
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed:
                  () => _showAddVariantDialog(context, (v) {
                    variants.add(v);
                    onUpdate(variants);
                  }),
              icon: const Icon(Icons.add, size: 16, color: Colors.greenAccent),
              label: const Text(
                "Add Option",
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        ),
        ...variants.asMap().entries.map(
          (e) => ListTile(
            dense: true,
            title: Text(
              e.value['name'],
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              "₹${e.value['price']} • ${e.value['duration']}m",
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
              onPressed: () {
                variants.removeAt(e.key);
                onUpdate(variants);
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showAddVariantDialog(
    BuildContext context,
    Function(Map<String, dynamic>) onAdd,
  ) {
    final nameC = TextEditingController();
    final priceC = TextEditingController();
    int dur = 30;
    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setS) => AlertDialog(
                  backgroundColor: Colors.grey[900],
                  title: const Text(
                    "Add Option",
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameC,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Name"),
                      ),
                      TextField(
                        controller: priceC,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Price"),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        if (nameC.text.isEmpty || priceC.text.isEmpty) return;
                        onAdd({
                          'name': nameC.text,
                          'price': priceC.text,
                          'duration': dur,
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text("Add"),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var s in services) {
      final cat = s['category'] ?? 'General';
      grouped.putIfAbsent(cat, () => []).add(s);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Grooming Menu',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              )
              : services.isEmpty
              ? const Center(
                child: Text(
                  "Menu is empty",
                  style: TextStyle(color: Colors.white30),
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children:
                    grouped.entries
                        .map(
                          (g) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  g.key.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...g.value.map((s) => _buildServiceCard(s)),
                            ],
                          ),
                        )
                        .toList(),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editService(null),
        backgroundColor: Colors.greenAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final List variants = service['variants'] ?? [];
    final int idx = services.indexOf(service);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ExpansionTile(
        title: Text(
          service['name'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          variants.isNotEmpty
              ? "Starts ₹${service['price'].toString().replaceAll('*', '')}"
              : "₹${service['price']} • ${service['duration']}m",
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Wrap(
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.greenAccent, size: 18),
              onPressed: () => _editService(idx),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
              onPressed: () {
                setState(() => services.removeAt(idx));
                _saveServices();
              },
            ),
          ],
        ),
        children: [
          if (service['description']?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                service['description'],
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ...variants.map(
            (v) => ListTile(
              dense: true,
              title: Text(
                v['name'],
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: Text(
                "₹${v['price']}",
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
