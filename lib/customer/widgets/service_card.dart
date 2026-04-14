import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:glowy_borders/glowy_borders.dart';
import '../../models/grooming_service.dart';
import '../../providers/booking_provider.dart';

class ServiceCard extends StatefulWidget {
  final GroomingService service;
  final VoidCallback? onAdd;

  const ServiceCard({
    super.key,
    required this.service,
    this.onAdd,
  });

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final provider = Provider.of<BookingProvider>(context, listen: false);
    if (provider.isAdded(widget.service.id)) return;

    setState(() => _isLoading = true);
    await _controller.forward();
    await _controller.reverse();

    // Simulate network delay for "Level Up" feel
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      provider.addService(widget.service);
      setState(() => _isLoading = false);
      widget.onAdd?.call();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${widget.service.name} added to your booking!"),
          backgroundColor: const Color(0xFF00D189),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, child) {
        final isAdded = provider.isAdded(widget.service.id);
        
        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTap: _handleTap,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 16),
                    child: AnimatedGradientBorder(
                      borderSize: 1,
                      glowSize: widget.service.isRecommended ? 5 : 0,
                      gradientColors: [
                        const Color(0xFF00D189),
                        Colors.blueAccent.withOpacity(0.5),
                        Colors.purpleAccent.withOpacity(0.3),
                      ],
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon/Image Area
                            Center(
                              child: Container(
                                height: 60,
                                width: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D189).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getServiceIcon(widget.service.category),
                                  color: const Color(0xFF00D189),
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Name
                            Text(
                              widget.service.name,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            const SizedBox(height: 4),
                            
                            // Rating and Duration
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  widget.service.rating.toString(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  widget.service.duration,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            
                            const Spacer(),
                            
                            // Price and Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "₹${widget.service.price.toInt()}",
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF00D189),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                _buildAddButton(isAdded),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddButton(bool isAdded) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isAdded ? 12 : 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isAdded 
          ? Colors.white.withOpacity(0.1) 
          : const Color(0xFF00D189),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isAdded ? [] : [
          BoxShadow(
            color: const Color(0xFF00D189).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isLoading
          ? const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isAdded)
                  const Icon(Icons.add, color: Colors.black, size: 14),
                if (isAdded)
                  const Icon(Icons.check, color: Color(0xFF00D189), size: 14),
                const SizedBox(width: 2),
                Text(
                  isAdded ? "Added" : "Add",
                  style: GoogleFonts.poppins(
                    color: isAdded ? Colors.white60 : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
    );
  }

  IconData _getServiceIcon(String category) {
    switch (category.toLowerCase()) {
      case 'hair':
        return Icons.content_cut;
      case 'beard':
        return Icons.face;
      case 'spa':
        return Icons.spa;
      case 'facial':
        return Icons.face_retouching_natural;
      case 'massage':
        return Icons.dry_cleaning_outlined; // Close enough for massage
      case 'styling':
        return Icons.brush;
      default:
        return Icons.auto_awesome;
    }
  }
}
