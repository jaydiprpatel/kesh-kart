import 'package:flutter/material.dart';

class CustomerSmartStylistPage extends StatelessWidget {
  const CustomerSmartStylistPage({super.key});

  static const Color _primary = Color(0xFF091426);

  @override
  Widget build(BuildContext context) {
    final styles = const [
      ('Classic Gentleman', 'Clean office look', 'assets/images/barber.png'),
      ('Low Fade', 'Sharp everyday style', 'assets/images/image1.png'),
      ('Textured Crop', 'Casual modern cut', 'assets/images/customer.png'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Smart Stylist',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find your next haircut',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Pick a style category now. Visual matching can plug into this screen when the smart style flow is ready.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...styles.map(
            (style) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE1E3E4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    style.$3,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  style.$1,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  style.$2,
                  style: const TextStyle(color: Color(0xFF8590A6)),
                ),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFC5C6CD)),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${style.$1} selected')),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
