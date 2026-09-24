import 'package:flutter/material.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/customer_bookings_page.dart';
import 'package:kesh_kart/customer/legal_document_page.dart';
import 'package:kesh_kart/customer/customer_smart_stylist_page.dart';
import 'package:kesh_kart/customer/qr_scanner_screen.dart';
import 'package:kesh_kart/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  static const Color _green = Color(0xFF00D084);

  bool _loading = true;
  bool _saving = false;
  String? _userId;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId =
        prefs.getString('bedrock_user_id') ?? prefs.getString('userId');
    Map<String, dynamic> data = {
      'name': prefs.getString('name') ?? 'User',
      'phone': prefs.getString('phone') ?? '',
      'email': prefs.getString('email') ?? '',
      'locationLabel': prefs.getString('locationLabel') ?? '',
    };

    if (userId != null && userId.isNotEmpty) {
      final doc = await BedrockClient().getDocument('users', userId);
      final remote = _normalize(doc);
      if (remote.isNotEmpty) data = {...data, ...remote};
    }

    if (!mounted) return;
    setState(() {
      _userId = userId;
      _profile = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = _text(_profile['name'], fallback: 'User');
    final phone = _text(_profile['phone'], fallback: 'Phone not set');
    final initials = _initials(name);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: const Color(0xFF091426),
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed: _loading || _saving ? null : _showEditProfileSheet,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : RefreshIndicator(
                onRefresh: _loadProfile,
                color: const Color(0xFF091426),
                backgroundColor: Colors.white,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ProfileHeader(
                      initials: initials,
                      name: name,
                      phone: phone,
                      saving: _saving,
                      onEdit: _showEditProfileSheet,
                    ),
                    const SizedBox(height: 14),
                    _InfoTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: _text(_profile['email'], fallback: 'Not added'),
                    ),
                    _InfoTile(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: _locationLabel,
                    ),
                    const SizedBox(height: 10),
                    _SectionTitle('Account'),
                    _ActionTile(
                      icon: Icons.calendar_month_outlined,
                      title: 'My bookings',
                      subtitle: 'View upcoming and past appointments',
                      onTap: () => _push(const CustomerBookingsPage()),
                    ),
                    _ActionTile(
                      icon: Icons.qr_code_scanner,
                      title: 'Scan shop QR',
                      subtitle: 'Check in when you reach the barber shop',
                      onTap: () => _push(const QrScannerScreen()),
                    ),
                    _ActionTile(
                      icon: Icons.auto_awesome,
                      title: 'Smart Stylist',
                      subtitle: 'Explore style suggestions',
                      onTap: () => _push(const CustomerSmartStylistPage()),
                    ),
                    const SizedBox(height: 10),
                    _SectionTitle('Preferences'),
                    _ActionTile(
                      icon: Icons.notifications_none,
                      title: 'Notifications',
                      subtitle: 'Booking reminders and service updates',
                      onTap: _showNotificationPreferences,
                    ),
                    _ActionTile(
                      icon: Icons.favorite_border,
                      title: 'Favourite barbers',
                      subtitle: 'Saved shops and preferred stylists',
                      onTap:
                          () => _showMessage(
                            'Favourite barbers saved to your profile.',
                          ),
                    ),
                    _ActionTile(
                      icon: Icons.help_outline,
                      title: 'Help and support',
                      subtitle: 'Contact KeshKart support',
                      onTap: () => _showSupportSheet(),
                    ),
                    const SizedBox(height: 10),
                    _SectionTitle('Legal & Account'),
                    _ActionTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy policy',
                      subtitle: 'How KeshKart handles your data and privacy',
                      onTap: () => _openLegal(LegalDocument.privacy),
                    ),
                    _ActionTile(
                      icon: Icons.description_outlined,
                      title: 'Terms of service',
                      subtitle:
                          'Platform usage, booking and cancellation rules',
                      onTap: () => _openLegal(LegalDocument.terms),
                    ),
                    _ActionTile(
                      icon: Icons.delete_outline,
                      title: 'Delete account',
                      subtitle:
                          'Permanently remove your profile and booking history',
                      onTap: _showAccountDeletionDialog,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Log out',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Future<void> _showNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    bool reminders = prefs.getBool('pref_notify_reminders') ?? true;
    bool queueUpdates = prefs.getBool('pref_notify_queue') ?? true;
    bool offers = prefs.getBool('pref_notify_offers') ?? false;

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Settings',
                    style: TextStyle(
                      color: Color(0xFF091426),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Customize what alerts you receive on this device.',
                    style: TextStyle(color: Color(0xFF45474C), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: reminders,
                    onChanged: (val) {
                      setSheetState(() => reminders = val);
                      prefs.setBool('pref_notify_reminders', val);
                    },
                    title: const Text(
                      '30-Minute Reminders',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Get push notifications 30 minutes before your slot starts.',
                    ),
                    activeThumbColor: const Color(0xFFE2613B),
                  ),
                  SwitchListTile(
                    value: queueUpdates,
                    onChanged: (val) {
                      setSheetState(() => queueUpdates = val);
                      prefs.setBool('pref_notify_queue', val);
                    },
                    title: const Text(
                      'Queue & Check-In Updates',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Alerts when your barber is ready or your queue position moves.',
                    ),
                    activeThumbColor: const Color(0xFFE2613B),
                  ),
                  SwitchListTile(
                    value: offers,
                    onChanged: (val) {
                      setSheetState(() => offers = val);
                      prefs.setBool('pref_notify_offers', val);
                    },
                    title: const Text(
                      'Promotional Offers',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Exclusive discounts and festival grooming packages.',
                    ),
                    activeThumbColor: const Color(0xFFE2613B),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await prefs.setBool('pref_notify_reminders', reminders);
                        await prefs.setBool('pref_notify_queue', queueUpdates);
                        await prefs.setBool('pref_notify_offers', offers);
                        nav.pop();
                        if (mounted) {
                          _showMessage(
                            'Notification preferences saved successfully.',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE2613B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save Preferences',
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
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Log out?',
              style: TextStyle(
                color: Color(0xFF091426),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'You will need OTP verification to sign in again.',
              style: TextStyle(color: Color(0xFF45474C)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Log out',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    final client = BedrockClient.instance;
    await client.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LogInScreen()),
      (_) => false,
    );
  }

  void _openLegal(LegalDocument document) {
    _push(LegalDocumentPage(document: document));
  }

  Future<void> _showAccountDeletionDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Delete KeshKart Account?',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'This action is irreversible. All your profile information, booking history, and preferences will be permanently deleted from KeshKart.',
              style: TextStyle(color: Color(0xFF45474C)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete Forever',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final client = BedrockClient.instance;
      await client.deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted successfully.'),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LogInScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to complete deletion: $e');
    }
  }

  String get _locationLabel {
    final location = _profile['location'];
    if (location is Map) {
      final city = _text(
        location['city'],
        fallback: _text(
          location['locality'],
          fallback: _text(location['area']),
        ),
      );
      final pincode = _text(
        location['pincode'],
        fallback: _text(
          location['postalCode'],
          fallback: _text(location['zip']),
        ),
      );
      final joined = [
        city,
        pincode,
      ].where((part) => part.isNotEmpty).join(' - ');
      if (joined.isNotEmpty) return joined;

      final label = _text(
        location['label'],
        fallback: _text(location['address']),
      );
      if (label.isNotEmpty && !_looksLikeCoordinates(label)) return label;
      return 'Location saved';
    }
    return _text(_profile['locationLabel'], fallback: 'Not added');
  }

  Future<void> _showEditProfileSheet() async {
    final nameController = TextEditingController(text: _text(_profile['name']));
    final emailController = TextEditingController(
      text: _text(_profile['email']),
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit profile',
                style: TextStyle(
                  color: Color(0xFF091426),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _EditField(controller: nameController, label: 'Name'),
              const SizedBox(height: 12),
              _EditField(
                controller: emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF091426),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save changes',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) return;
    await _saveProfile(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
    );
  }

  Future<void> _saveProfile({
    required String name,
    required String email,
  }) async {
    if (_userId == null || _userId!.isEmpty) {
      _showMessage('Please login again to update profile.');
      return;
    }
    if (name.isEmpty) {
      _showMessage('Name cannot be empty.');
      return;
    }

    setState(() => _saving = true);
    final patch = {'name': name, 'email': email};
    final result = await BedrockClient().updateDocument(
      'users',
      _userId!,
      patch,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result == null) {
      _showMessage('Could not update profile. Try again.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('barberName', name);
    await prefs.setString('email', email);
    await _loadProfile();
    _showMessage('Profile updated.');
  }

  void _showSupportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help and support',
                  style: TextStyle(
                    color: Color(0xFF091426),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'For booking, OTP, or account help, contact KeshKart support from your registered phone number.',
                  style: TextStyle(color: Color(0xFF45474C), height: 1.4),
                ),
                SizedBox(height: 18),
              ],
            ),
          ),
    );
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static Map<String, dynamic> _normalize(dynamic row) {
    if (row is! Map) return {};
    final data = row['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(row);
  }

  static String _initials(String name) {
    final initials =
        name
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .map((part) => part[0])
            .take(2)
            .join()
            .toUpperCase();
    return initials.isEmpty ? 'US' : initials;
  }

  static bool _looksLikeCoordinates(String value) {
    return RegExp(r'^-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?$').hasMatch(value.trim());
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

class _ProfileHeader extends StatelessWidget {
  final String initials;
  final String name;
  final String phone;
  final bool saving;
  final VoidCallback onEdit;

  const _ProfileHeader({
    required this.initials,
    required this.name,
    required this.phone,
    required this.saving,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1E3E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFF091426),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF091426),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(phone, style: const TextStyle(color: Color(0xFF8590A6))),
              ],
            ),
          ),
          IconButton(
            onPressed: saving ? null : onEdit,
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF091426)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF091426),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E3E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF091426)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF8590A6))),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF091426),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E3E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF091426)),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF091426),
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF8590A6)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFC5C6CD)),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  const _EditField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF091426)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8590A6)),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE1E3E4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF091426)),
        ),
      ),
    );
  }
}
