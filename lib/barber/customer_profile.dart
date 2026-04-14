import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';

class BarberCustomerProfileScreen extends StatefulWidget {
  final String barberId;
  final String customerId;
  final String customerName;

  const BarberCustomerProfileScreen({
    super.key,
    required this.barberId,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<BarberCustomerProfileScreen> createState() =>
      _BarberCustomerProfileScreenState();
}

class _BarberCustomerProfileScreenState
    extends State<BarberCustomerProfileScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool isLoading = true;
  String? noteId;
  int visitCount = 0;
  DateTime? lastVisit;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    await Future.wait([_loadNotes(), _loadStats()]);
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadNotes() async {
    try {
      final snapshot =
          await BaasClient.collection('notes')
              .where('barberId', isEqualTo: widget.barberId)
              .where('customerId', isEqualTo: widget.customerId)
              .limit(1)
              .snapshots()
              .first;

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        noteId = doc.id;
        final data = doc.data() as Map<String, dynamic>;
        _notesController.text = data['content'] ?? '';
      }
    } catch (e) {
      debugPrint("Error loading notes: $e");
    }
  }

  Future<void> _loadStats() async {
    try {
      final snapshot =
          await BaasClient.collection('appointments')
              .where('barberId', isEqualTo: widget.barberId)
              .where('customerId', isEqualTo: widget.customerId)
              .where('status', isEqualTo: 'confirmed')
              // .where('isDone', isEqualTo: true) // Optional: only count completed
              .snapshots()
              .first;

      final docs = snapshot.docs;
      visitCount = docs.length;

      if (docs.isNotEmpty) {
        // Sort to find last visit (client-side sort if index missing)
        // Ideally orderBy('time', descending: true)
        // Taking the latest time
        DateTime? latest;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final rawTime = data['time'];
          final time =
              rawTime is Timestamp
                  ? rawTime.toDate()
                  : DateTime.tryParse(rawTime.toString()) ?? DateTime.now();
          if (latest == null || time.isAfter(latest)) {
            latest = time;
          }
        }
        lastVisit = latest;
      }
    } catch (e) {
      debugPrint("Error loading stats: $e");
    }
  }

  Future<void> _saveNote() async {
    final content = _notesController.text.trim();
    if (content.isEmpty && noteId == null) return;

    try {
      if (noteId != null) {
        await BaasClient.collection('notes').doc(noteId!).update({
          'content': content,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        final ref = await BaasClient.collection('notes').add({
          'barberId': widget.barberId,
          'customerId': widget.customerId,
          'content': content,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        noteId = ref.id;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Note saved')));
      }
    } catch (e) {
      debugPrint("Error saving note: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Customer Profile",
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.greenAccent),
            onPressed: _saveNote,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.customerName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Member since 2024", // Placeholder
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "$visitCount",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Visits",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  lastVisit != null
                                      ? "${lastVisit!.day}/${lastVisit!.month}"
                                      : "N/A",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Last Visit",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Private Notes
                    const Text(
                      "Private Notes 🔒",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.yellow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.yellow.withOpacity(0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _notesController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: "Add notes (e.g., preference, behavior)...",
                          hintStyle: TextStyle(color: Colors.white30),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Recent History
                    const Text(
                      "Recent History",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder(
                      stream:
                          BaasClient.collection('appointments')
                              .where('barberId', isEqualTo: widget.barberId)
                              .where('customerId', isEqualTo: widget.customerId)
                              .limit(5)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final docs = (snapshot.data as dynamic).docs;

                        // TODO: Sort locally if needed

                        return Column(
                          children:
                              docs.map<Widget>((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final rawTime = data['time'];
                                final time =
                                    rawTime is Timestamp
                                        ? rawTime.toDate()
                                        : DateTime.tryParse(
                                              rawTime.toString(),
                                            ) ??
                                            DateTime.now();

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['service'] ?? 'Service',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            "${time.day}/${time.month}/${time.year}",
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "₹${data['price'] ?? 0}",
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
    );
  }
}
