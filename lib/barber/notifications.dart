import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BarberNotificationsScreen extends StatefulWidget {
  const BarberNotificationsScreen({super.key});

  @override
  State<BarberNotificationsScreen> createState() =>
      _BarberNotificationsScreenState();
}

class _BarberNotificationsScreenState extends State<BarberNotificationsScreen> {
  String barberId = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBarberId();
  }

  Future<void> _loadBarberId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      barberId = prefs.getString('userId') ?? '';
      isLoading = false;
    });
  }

  Future<void> _clearAllNotifications() async {
    try {
      final snapshot =
          await BaasClient.collection('notifications')
              .where('recipientId', isEqualTo: barberId)
              .where('isRead', isEqualTo: false)
              .get();

      for (var doc in snapshot.docs) {
        await BaasClient.collection(
          'notifications',
        ).doc(doc.id).update({'isRead': true});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      debugPrint("Error clearing notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _clearAllNotifications,
            child: const Text(
              "Clear All",
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : StreamBuilder(
                stream:
                    BaasClient.collection('notifications')
                        .where('recipientId', isEqualTo: barberId)
                        // .orderBy('createdAt', descending: true) // Ensure index exists if needed
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final docs = (snapshot.data as dynamic).docs;

                  // Sort manually if index is missing
                  // docs.sort((a, b) => b.data()['createdAt'].compareTo(a.data()['createdAt']));

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off,
                            size: 64,
                            color: Colors.grey[800],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No notifications yet",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isRead = data['isRead'] ?? false;
                      final type = data['type'] ?? 'info';
                      final title = data['title'] ?? 'Notification';
                      final body = data['body'] ?? '';
                      // Timestamp or String

                      IconData icon;
                      Color color;
                      if (type == 'booking_request') {
                        icon = Icons.calendar_today;
                        color = Colors.blueAccent;
                      } else if (type == 'cancellation') {
                        icon = Icons.cancel;
                        color = Colors.redAccent;
                      } else {
                        icon = Icons.info;
                        color = Colors.white70;
                      }

                      return Dismissible(
                        key: Key(doc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          BaasClient.collection(
                            'notifications',
                          ).doc(doc.id).delete();
                        },
                        child: GestureDetector(
                          onTap: () async {
                            if (!isRead) {
                              await BaasClient.collection(
                                'notifications',
                              ).doc(doc.id).update({'isRead': true});
                            }
                            // Navigate if needed, e.g. to appointment detail
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isRead ? Colors.white10 : Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  isRead
                                      ? null
                                      : Border.all(
                                        color: Colors.greenAccent.withOpacity(
                                          0.3,
                                        ),
                                      ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: color, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                              isRead
                                                  ? FontWeight.normal
                                                  : FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        body,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Time display could go here
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
