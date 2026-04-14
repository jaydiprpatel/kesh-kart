import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';

// For slideUpRoute if accessible or commonly used

class AppointmentHistoryScreen extends StatelessWidget {
  final String barberId;

  const AppointmentHistoryScreen({super.key, required this.barberId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Appointment History",
          style: TextStyle(fontFamily: 'Popins', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream:
            BaasClient.collection(
              'appointments',
            ).where('barberId', isEqualTo: barberId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final allDocs = (snapshot.data as dynamic).docs as List;

          // History includes: Done, Cancelled, or any appointment in the past
          final docs =
              allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isDone = data['isDone'] == true;
                final status = data['status']?.toString().toLowerCase() ?? '';
                final time = _parseTime(data['time']);

                return isDone ||
                    status == 'cancelled' ||
                    status == 'completed' ||
                    status == 'rejected' ||
                    time.isBefore(DateTime.now());
              }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text(
                    "No past appointments",
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            );
          }

          // Client-side sort if index is missing
          // Assuming docs is a List<DocumentSnapshot> or similar wrapper
          // We need to convert to list to sort
          List<dynamic> sortedDocs = List.from(docs);
          sortedDocs.sort((a, b) {
            final tA = _parseTime(a.data()['time']);
            final tB = _parseTime(b.data()['time']);
            return tB.compareTo(tA); // Descending
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDocs.length,
            itemBuilder: (context, index) {
              final doc = sortedDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              final customerName = data['customerName'] ?? 'Unknown Customer';
              final serviceName = data['service'] ?? 'Unknown Service';
              final isDone = data['isDone'] == true;
              final time = _parseTime(data['time']);

              Color statusColor = Colors.white;
              String statusText = 'Pending';
              final displayStatus =
                  (data['status']?.toString().toLowerCase() ?? 'pending');

              if (displayStatus == 'cancelled') {
                statusColor = Colors.redAccent;
                statusText = 'Cancelled';
              } else if (displayStatus == 'rejected') {
                statusColor = Colors.red;
                statusText = 'Rejected';
              } else if (displayStatus == 'completed' || isDone) {
                statusColor = Colors.greenAccent;
                statusText = 'Completed';
              } else if (time.isBefore(DateTime.now())) {
                statusColor = Colors.orangeAccent;
                statusText = 'Expired';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          serviceName,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${time.day}/${time.month}/${time.year} • ${TimeOfDay.fromDateTime(time).format(context)}",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  DateTime _parseTime(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String)
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    return DateTime.now();
  }
}
