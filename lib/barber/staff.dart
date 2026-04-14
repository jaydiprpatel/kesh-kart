import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:google_fonts/google_fonts.dart';

class BarberStaffScreen extends StatefulWidget {
  final String barberId;
  const BarberStaffScreen({super.key, required this.barberId});

  @override
  State<BarberStaffScreen> createState() => _BarberStaffScreenState();
}

class _BarberStaffScreenState extends State<BarberStaffScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _staffList = [];
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      debugPrint("DEBUG STAFF: Loading staff for ID: ${widget.barberId}");
      final doc =
          await BaasClient.collection('users').doc(widget.barberId).get();
      final data = (doc as dynamic).data() as Map<String, dynamic>?;
      debugPrint("DEBUG STAFF: Fetched data: $data");

      if (data != null) {
        if (mounted) {
          setState(() {
            _staffList = List<Map<String, dynamic>>.from(data['staff'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint("DEBUG STAFF: Error loading staff: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addStaff() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    debugPrint("DEBUG STAFF: Attempting to add staff: $name");
    setState(() => _isLoading = true);

    try {
      final newStaff = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'role': 'Barber',
        'isActive': true,
      };

      final updatedList = List<Map<String, dynamic>>.from(_staffList);
      updatedList.add(newStaff);

      debugPrint(
        "DEBUG STAFF: Updating backend with ${updatedList.length} staff items",
      );

      // Use update if document exists, otherwise set
      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'staff': updatedList});

      debugPrint("DEBUG STAFF: Update success!");
      _nameController.clear();
      _loadStaff();
    } catch (e) {
      debugPrint("DEBUG STAFF: Error adding staff: $e");
      // Fallback: If update failed because field is missing or something, try reading whole doc and setting
      try {
        debugPrint("DEBUG STAFF: Retrying with full document set...");
        final doc =
            await BaasClient.collection('users').doc(widget.barberId).get();
        final data = Map<String, dynamic>.from((doc as dynamic).data() ?? {});
        data['staff'] = [
          ..._staffList,
          {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'name': name,
            'role': 'Barber',
            'isActive': true,
          },
        ];
        await BaasClient.collection('users').doc(widget.barberId).set(data);
        debugPrint("DEBUG STAFF: Retry success!");
        _nameController.clear();
        _loadStaff();
      } catch (retryErr) {
        debugPrint("DEBUG STAFF: Retry also failed: $retryErr");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to add staff: $retryErr")),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeStaff(int index) async {
    setState(() => _isLoading = true);
    try {
      final updatedList = List<Map<String, dynamic>>.from(_staffList);
      updatedList.removeAt(index);

      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'staff': updatedList});
      _loadStaff();
    } catch (e) {
      debugPrint("DEBUG STAFF: Error removing staff: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditDialog(int index, Map<String, dynamic> staff) {
    final nameCtrl = TextEditingController(text: staff['name']);
    final roleCtrl = TextEditingController(text: staff['role'] ?? 'Barber');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1B1B1B),
            title: Text(
              'Edit Staff Member',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00D189)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: roleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00D189)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed:
                    () => _updateStaff(index, nameCtrl.text, roleCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D189),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Save Changes'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateStaff(int index, String newName, String newRole) async {
    Navigator.pop(context);
    setState(() => _isLoading = true);
    try {
      final updatedList = List<Map<String, dynamic>>.from(_staffList);
      updatedList[index] = {
        ...updatedList[index],
        'name': newName.trim(),
        'role': newRole.trim(),
      };

      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'staff': updatedList});
      _loadStaff();
    } catch (e) {
      debugPrint("DEBUG STAFF: Error updating staff: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to update staff: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "Manage Staff",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          _isLoading && _staffList.isEmpty
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D189)),
              )
              : Column(
                children: [
                  _buildAddStaffSection(),
                  if (_isLoading && _staffList.isNotEmpty)
                    const LinearProgressIndicator(
                      color: Color(0xFF00D189),
                      backgroundColor: Colors.black,
                    ),
                  Expanded(
                    child:
                        _staffList.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _staffList.length,
                              itemBuilder: (context, index) {
                                final staff = _staffList[index];
                                return Card(
                                  color: Colors.white10,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFF00D189),
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.black,
                                      ),
                                    ),
                                    title: Text(
                                      staff['name'] ?? 'Unknown',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      staff['role'] ?? 'Barber',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white54,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: Color(0xFF00D189),
                                            size: 20,
                                          ),
                                          onPressed:
                                              () =>
                                                  _showEditDialog(index, staff),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          onPressed: () => _removeStaff(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }

  Widget _buildAddStaffSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter staff member name",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.white38,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D189)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _addStaff,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D189),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Add",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            "No staff added yet",
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Add your team members to manage their bookings.",
            style: GoogleFonts.poppins(color: Colors.white24, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
