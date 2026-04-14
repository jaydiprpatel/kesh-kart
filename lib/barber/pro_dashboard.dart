import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:intl/intl.dart';

class ProDashboardScreen extends StatefulWidget {
  final String barberId;
  const ProDashboardScreen({super.key, required this.barberId});

  @override
  State<ProDashboardScreen> createState() => _ProDashboardScreenState();
}

class _ProDashboardScreenState extends State<ProDashboardScreen> {
  Map<String, dynamic>? _insights;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);
    final data = await BaasClient.instance.fetchInsights();
    if (mounted) {
      setState(() {
        _insights = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'KESH KART PRO',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInsights),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              )
              : _insights == null || _insights!.isEmpty
              ? const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.white54),
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildRevenueCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('BUSY HOURS'),
                  const SizedBox(height: 16),
                  _buildHourChart(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('POPULAR SERVICES'),
                  const SizedBox(height: 16),
                  _buildServicesList(),
                  const SizedBox(height: 40),
                ],
              ),
    );
  }

  Widget _buildRevenueCard() {
    final cur = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.greenAccent.withOpacity(0.2),
            Colors.blueAccent.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROJECTED REVENUE',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cur.format(_insights!['revenue'] ?? 0),
            style: GoogleFonts.robotoMono(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: Colors.greenAccent,
              ),
              const SizedBox(width: 8),
              Text(
                '${_insights!['appointment_count']} Total Appointments',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildHourChart() {
    final hours = List<int>.from(
      _insights!['busy_hours'] ?? List.filled(24, 0),
    );
    final maxVal = hours.reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (i) {
          final h = hours[i];
          final heightPct = maxVal > 0 ? h / maxVal : 0.0;
          final isWorkingHour = i >= 9 && i <= 21;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 100 * heightPct + 2,
                  decoration: BoxDecoration(
                    color:
                        h > 0
                            ? Colors.greenAccent
                            : (isWorkingHour
                                ? Colors.white12
                                : Colors.transparent),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                if (i % 4 == 0)
                  Text(
                    '${i}h',
                    style: const TextStyle(color: Colors.white24, fontSize: 8),
                  )
                else
                  const SizedBox(height: 10),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildServicesList() {
    final svcs = List<Map<String, dynamic>>.from(
      _insights!['popular_services'] ?? [],
    );
    if (svcs.isEmpty) {
      return const Text('No data', style: TextStyle(color: Colors.white24));
    }

    return Column(
      children:
          svcs.map((s) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cut,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      s['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${s['count']} bookings',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}
