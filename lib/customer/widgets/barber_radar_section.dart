import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kesh_kart/models/radar_barber.dart';
import 'package:kesh_kart/customer/widgets/barber_radar_card.dart';

class BarberRadarSection extends StatelessWidget {
  final List<RadarBarber> barbers;
  final Function(RadarBarber) onBarberTap;

  const BarberRadarSection({
    super.key,
    required this.barbers,
    required this.onBarberTap,
  });

  @override
  Widget build(BuildContext context) {
    if (barbers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top barbers near you',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Icon(Icons.radar, color: Color(0xFF00D189), size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: barbers.length,
            itemBuilder: (context, index) {
              return BarberRadarCard(
                barber: barbers[index],
                onTap: () => onBarberTap(barbers[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
