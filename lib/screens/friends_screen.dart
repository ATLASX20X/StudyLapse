import 'package:flutter/material.dart';
import '../main.dart';
import '../services/friend_service.dart';
import '../services/auth_service.dart';
import 'user_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.userId});

  final String userId;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();
  final AuthService _authService = AuthService();

  List<dynamic> _friends = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _loadFriends();
  }

  Future<void> _getCurrentUserId() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUserId = user?.id;
      });
    }
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final friends = await _friendService.getFriends(widget.userId);
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    try {
      await _friendService.removeFriend(friendId);
      await _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ami supprimé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Amis'),
        backgroundColor: backgroundColor,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: accentColor),
            )
          : _friends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 64,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucun ami',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    return _FriendTile(
                      friend: friend,
                      isCurrentUser: _currentUserId == widget.userId,
                      onRemove: () => _removeFriend(friend['id']),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(userId: friend['id']),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.isCurrentUser,
    required this.onRemove,
    required this.onTap,
  });

  final dynamic friend;
  final bool isCurrentUser;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: surfaceColor,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 24,
            color: accentColor,
          ),
        ),
        title: Text(
          friend['name'] ?? friend['username'] ?? 'Utilisateur',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '@${friend['username'] ?? ''}',
          style: const TextStyle(
            color: Colors.white70,
          ),
        ),
        trailing: isCurrentUser
            ? IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                onPressed: onRemove,
              )
            : const Icon(Icons.chevron_right_rounded, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }
}
