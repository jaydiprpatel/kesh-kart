import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';

class BarberEarningsScreen extends StatefulWidget {
  final String barberId;
  const BarberEarningsScreen({super.key, required this.barberId});

  @override
  State<BarberEarningsScreen> createState() => _BarberEarningsScreenState();
}

class _BarberEarningsScreenState extends State<BarberEarningsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Earnings & Analytics",
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream:
            BaasClient.collection(
              'appointments',
            ).where('barberId', isEqualTo: widget.barberId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            );
          }

          if (!snapshot.hasData || (snapshot.data as dynamic).docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = (snapshot.data as dynamic).docs;
          return _buildAnalytics(docs);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            "No data available yet",
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            "Complete appointments to see analytics",
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics(List<dynamic> docs) {
    double totalRevenue = 0;
    int completedCount = 0;
    int cancelledCount = 0;
    int pendingCount = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'pending';
      var rawPrice = data['price'];
      double price = 0.0;
      if (rawPrice is num) {
        price = rawPrice.toDouble();
      } else if (rawPrice is String) {
        price =
            double.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      }

      if (status == 'completed') {
        totalRevenue += price;
        completedCount++;
      } else if (status == 'cancelled' || status == 'rejected') {
        cancelledCount++;
      } else {
        pendingCount++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(totalRevenue, completedCount),
          const SizedBox(height: 24),
          const Text(
            "Statistics",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatGrid(completedCount, cancelledCount, pendingCount),
          const SizedBox(height: 32),
          const Text(
            "Recent Completed Jobs",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecentJobs(docs),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double revenue, int totalJobs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.greenAccent, Colors.tealAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Revenue",
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "₹${revenue.toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.black54,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "$totalJobs Successful Jobs",
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(int completed, int cancelled, int pending) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 0.8,
      crossAxisSpacing: 12,
      children: [
        _buildStatItem("Completed", completed.toString(), Colors.greenAccent),
        _buildStatItem("Cancelled", cancelled.toString(), Colors.redAccent),
        _buildStatItem("Pending", pending.toString(), Colors.orangeAccent),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentJobs(List<dynamic> docs) {
    final completedDocs =
        docs.where((d) => d.data()['status'] == 'completed').toList();

    // Sort by createdAt descending if exists, otherwise by time
    completedDocs.sort((a, b) {
      final aTime = a.data()['time']?.toString() ?? '';
      final bTime = b.data()['time']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });

    final recent = completedDocs.take(5).toList();

    if (recent.isEmpty) {
      return const Text(
        "No completed jobs yet",
        style: TextStyle(color: Colors.white38),
      );
    }

    return Column(
      children:
          recent.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['customerName'] ?? 'Customer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        data['service'] ?? 'Service',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "+₹${data['price']}",
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
  }
}
