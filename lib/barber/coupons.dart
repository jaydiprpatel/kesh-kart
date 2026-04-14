import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';

class BarberCouponsScreen extends StatefulWidget {
  final String barberId;
  const BarberCouponsScreen({super.key, required this.barberId});

  @override
  State<BarberCouponsScreen> createState() => _BarberCouponsScreenState();
}

class _BarberCouponsScreenState extends State<BarberCouponsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _coupons = [];
  final _codeController = TextEditingController();
  final _discountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoading = true);
    try {
      final doc =
          await BaasClient.collection('users').doc(widget.barberId).get();
      final data = (doc as dynamic).data() as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _coupons = List<Map<String, dynamic>>.from(data['coupons'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error loading coupons: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCoupon() async {
    final code = _codeController.text.trim().toUpperCase();
    final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;

    if (code.isEmpty || discount <= 0) return;

    setState(() => _isLoading = true);
    try {
      final newCoupon = {
        'code': code,
        'discount': discount,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      };

      _coupons.add(newCoupon);
      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'coupons': _coupons});
      _codeController.clear();
      _discountController.clear();
      _loadCoupons();
    } catch (e) {
      debugPrint("Error adding coupon: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCoupon(int index) async {
    setState(() => _isLoading = true);
    try {
      _coupons.removeAt(index);
      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'coupons': _coupons});
      _loadCoupons();
    } catch (e) {
      debugPrint("Error deleting coupon: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Promotions & Coupons",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D189)),
              )
              : Column(
                children: [
                  _buildAddCouponSection(),
                  Expanded(
                    child:
                        _coupons.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _coupons.length,
                              itemBuilder: (context, index) {
                                final coupon = _coupons[index];
                                return _buildCouponCard(coupon, index);
                              },
                            ),
                  ),
                ],
              ),
    );
  }

  Widget _buildAddCouponSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _codeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "CODE (e.g. FIRST50)",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Discount ₹",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addCoupon,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D189),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Create Coupon",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D189).withOpacity(0.3)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF00D189),
          child: Icon(Icons.confirmation_num, color: Colors.white),
        ),
        title: Text(
          coupon['code'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        subtitle: Text(
          "₹${coupon['discount']} OFF",
          style: const TextStyle(
            color: Color(0xFF00D189),
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _deleteCoupon(index),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.discount_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            "No active coupons",
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            "Create discounts to boost your bookings!",
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
