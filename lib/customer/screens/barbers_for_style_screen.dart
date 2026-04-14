import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kesh_kart/services/style_service.dart';
import 'package:kesh_kart/customer/barber_profile.dart';

class BarbersForStyleScreen extends StatefulWidget {
  final String styleId;
  final String styleName;

  const BarbersForStyleScreen({
    super.key,
    required this.styleId,
    required this.styleName,
  });

  @override
  State<BarbersForStyleScreen> createState() => _BarbersForStyleScreenState();
}

class _BarbersForStyleScreenState extends State<BarbersForStyleScreen> {
  final StyleService _styleService = StyleService();
  bool _isLoading = true;
  List<dynamic> _barbers = [];

  @override
  void initState() {
    super.initState();
    _fetchBarbers();
  }

  Future<void> _fetchBarbers() async {
    setState(() => _isLoading = true);
    try {
      final barbers = await _styleService.getBarbersByStyle(widget.styleId);
      setState(() {
        _barbers = barbers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Barbers for ${widget.styleName}',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D189)))
          : _barbers.isEmpty
              ? _buildEmptyState()
              : _buildBarberList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_search, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'No barbers found for this style nearby.',
            style: GoogleFonts.poppins(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildBarberList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _barbers.length,
      itemBuilder: (context, index) {
        final barber = _barbers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(barber['profileImage'] ?? ''),
              backgroundColor: Colors.grey[900],
            ),
            title: Text(
              barber['name'] ?? 'Unknown Barber',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barber['shopName'] ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${barber['rating']} • ${barber['distance']} km',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BarberProfileScreen(
                      barberId: barber['barberId'],
                      barberData: barber,
                      distance: (barber['distance'] ?? 0.0).toDouble(),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D189),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Book', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}
