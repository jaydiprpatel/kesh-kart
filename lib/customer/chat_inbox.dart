import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/customer/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Messages",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream:
            BaasClient.collection(
              'chats',
            ).where('participants', arrayContains: _currentUserId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D189)),
            );
          }

          if (!snapshot.hasData || (snapshot.data as dynamic).docs.isEmpty) {
            return _buildEmptyState();
          }

          final chats = (snapshot.data as dynamic).docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: chats.length,
            separatorBuilder:
                (context, index) => const Divider(color: Colors.white10),
            itemBuilder: (context, index) {
              final data = chats[index].data();
              final participants = List<String>.from(
                data['participants'] ?? [],
              );
              final otherUserId = participants.firstWhere(
                (id) => id != _currentUserId,
                orElse: () => '',
              );

              // In a real app, we'd fetch the other user's name from the 'users' collection.
              // For MVP, if not in data, we can use a placeholder or the last chat msg.
              return _buildChatTile(
                otherUserId,
                data['lastMessage'] ?? 'No messages yet',
                data['updatedAt'],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            "No messages yet",
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            "Start a conversation with a barber!",
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(
    String otherUserId,
    String lastMessage,
    String? updatedAt,
  ) {
    // Dynamic name fetch simulation
    return FutureBuilder(
      future: BaasClient.collection('users').doc(otherUserId).get(),
      builder: (context, snapshot) {
        String name = "Loading...";
        if (snapshot.hasData) {
          final userData = (snapshot.data as dynamic).data();
          name = userData?['shopName'] ?? userData?['name'] ?? 'User';
        }

        return ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => ChatScreen(
                      otherUserId: otherUserId,
                      otherUserName: name,
                    ),
              ),
            );
          },
          leading: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              'https://ui-avatars.com/api/?name=$name&background=00D189&color=fff',
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    color: Colors.white12,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white54,
                      size: 30,
                    ),
                  ),
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54),
          ),
          trailing:
              updatedAt != null
                  ? Text(
                    DateFormat(
                      'hh:mm a',
                    ).format(DateTime.tryParse(updatedAt) ?? DateTime.now()),
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  )
                  : null,
        );
      },
    );
  }
}
