import re

with open('lib/customer/home.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# We want to replace from `  @override\n  Widget build(BuildContext context) {` 
# up to `  List<String> _services(Map<String, dynamic> barber) {`

pattern = re.compile(r'  @override\n  Widget build\(BuildContext context\) \{.*?  List<String> _services\(Map<String, dynamic> barber\) \{', re.DOTALL)

new_ui = """  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadHome,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildAIBanner(),
                      const SizedBox(height: 24),
                      _buildSmartRecommendations(),
                      const SizedBox(height: 24),
                      _buildBarberRadar(),
                    ],
                  ),
                ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openSmartStylist,
          backgroundColor: const Color(0xFF091426),
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.auto_awesome, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: _openProfile,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF091426),
              child: Text(
                _initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting,',
                  style: const TextStyle(color: Color(0xFF54647A), fontSize: 12),
                ),
                Text(
                  _name,
                  style: const TextStyle(
                      color: Color(0xFF091426), fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _pickAndSaveLocation,
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF191C1D), size: 16),
                const SizedBox(width: 4),
                Text(
                  _lat == null || _lng == null ? 'Add location' : _locationLabel,
                  style: const TextStyle(
                      color: Color(0xFF191C1D), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF191C1D), size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your AI Stylist is Ready',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF091426)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Discover your perfect look with our AI analysis. Tap to start your personalized style journey.',
            style: TextStyle(fontSize: 13, color: Color(0xFF45474C), height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openSmartStylist,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF091426),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            icon: const Icon(Icons.filter_center_focus, size: 18),
            label: const Text('SCAN FACE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Smart Recommendations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF091426)),
              ),
              TextButton(
                onPressed: _openSmartStylist,
                child: const Text('See All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF54647A))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildRecommendationCard(
                'Best for Your Face',
                'AI Recommended Styles',
                'assets/images/barber.png',
                Icons.auto_awesome,
              ),
              const SizedBox(width: 12),
              _buildRecommendationCard(
                'Trending',
                'In Khambhat',
                null,
                Icons.trending_up,
                isPlaceholder: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(String title, String subtitle, String? imagePath, IconData icon, {bool isPlaceholder = false}) {
    return InkWell(
      onTap: _openSmartStylist,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1E3E4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0E1FB),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  image: imagePath != null ? DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover) : null,
                ),
                child: isPlaceholder ? Center(child: Icon(icon, size: 40, color: const Color(0xFF54647A))) : Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF091426).withValues(alpha: 0.8),
                      child: Icon(icon, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF091426))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF45474C))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarberRadar() {
    final barbers = _visibleBarbers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: const [
              Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF091426)),
              SizedBox(width: 8),
              Text(
                'Barber Radar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF091426)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (barbers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No barbers found nearby.'),
          )
        else
          ...barbers.map((barber) => _buildBarberListItem(barber)),
      ],
    );
  }

  Widget _buildBarberListItem(Map<String, dynamic> barber) {
    final shopName = _string(barber['shopName'], fallback: _string(barber['name'], fallback: 'Barber Shop'));
    final distance = _distanceKm(barber);
    final photo = _firstPhoto(barber);
    final ratingLabel = _ratingLabel(barber);
    final services = _services(barber);
    final availability = _availabilityLabel(barber);

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E3E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo == null)
                  Image.asset('assets/images/barber.png', fit: BoxFit.cover)
                else
                  Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/images/barber.png', fit: BoxFit.cover)),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      availability.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF091426), letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF091426)),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_outline, size: 16, color: Color(0xFFFFB347)),
                        const SizedBox(width: 4),
                        Text(ratingLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF091426))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_distanceLabel(distance)} • ${barber['shopAddress'] ?? 'Main Street'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF45474C)),
                ),
                const SizedBox(height: 12),
                if (services.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services.take(3).map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(s, style: const TextStyle(fontSize: 11, color: Color(0xFF45474C))),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _openBooking(barber),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF091426),
                      side: const BorderSide(color: Color(0xFF091426)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Book Appointment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E3E4))),
      ),
      padding: const EdgeInsets.only(bottom: 20, top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_filled,
            label: 'Home',
            active: true,
          ),
          _NavItem(
            icon: Icons.calendar_month_outlined,
            label: 'Bookings',
            onTap: _openBookings,
          ),
          _NavItem(
            icon: Icons.auto_awesome_outlined,
            label: 'AI Stylist',
            onTap: _openSmartStylist,
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            onTap: _openProfile,
          ),
        ],
      ),
    );
  }

  List<String> _services(Map<String, dynamic> barber) {"""

if pattern.search(content):
    content = pattern.sub(new_ui, content)
    with open('lib/customer/home.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patch applied successfully")
else:
    print("Pattern not found")

