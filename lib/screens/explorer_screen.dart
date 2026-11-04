import 'package:flutter/material.dart';

import '../main.dart';
import 'home_feed_screen.dart';
import 'user_profile_screen.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../models/user.dart' as models;

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Subject> _filteredSubjects = [];
  final List<models.AppUser> _searchedUsers = [];
  bool _isSearchingUsers = false;
  bool _isLoading = false;
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _filteredSubjects.addAll(Subject.predefinedSubjects);
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUserId = user?.id;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearchingUsers = false;
        _searchedUsers.clear();
        _filteredSubjects.clear();
        _filteredSubjects.addAll(Subject.predefinedSubjects);
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // First check if it matches a subject
      final matchingSubjects = Subject.searchSubjects(query);
      
      // Also search for users
      final users = await _userService.searchUsers(query);

      setState(() {
        _filteredSubjects.clear();
        _filteredSubjects.addAll(matchingSubjects);
        _searchedUsers.clear();
        _searchedUsers.addAll(users);
        _isSearchingUsers = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToSubjectFeed(Subject subject) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HomeFeedScreen(subjectFilter: subject.name),
      ),
    );
  }

  void _navigateToUserProfile(models.AppUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: user.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Explorer'),
        backgroundColor: backgroundColor,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Rechercher un sujet ou un utilisateur...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Grille de sujets et utilisateurs
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: accentColor))
                : _isSearchingUsers
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_searchedUsers.isEmpty)
                            const Center(
                              child: Text(
                                'Aucun résultat',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ..._searchedUsers.map((user) => _UserTile(
                                user: user,
                                onTap: () => _navigateToUserProfile(user),
                                currentUserId: _currentUserId,
                              )),
                        ],
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _filteredSubjects.length,
                        itemBuilder: (context, index) {
                          final subject = _filteredSubjects[index];
                          return _SubjectTile(
                            subject: subject,
                            onTap: () => _navigateToSubjectFeed(subject),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subject,
    required this.onTap,
  });

  final Subject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Fond avec emoji
            Positioned.fill(
              child: Center(
                child: Text(
                  subject.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
            // Overlay avec nom du sujet
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  subject.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatefulWidget {
  const _UserTile({
    required this.user,
    required this.onTap,
    required this.currentUserId,
  });

  final models.AppUser user;
  final VoidCallback onTap;
  final String? currentUserId;

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  final FriendService _friendService = FriendService();
  bool _isSendingRequest = false;
  bool _isFriend = false;
  bool _hasPendingRequest = false;

  @override
  void initState() {
    super.initState();
    _checkFriendshipStatus();
  }

  Future<void> _checkFriendshipStatus() async {
    if (widget.currentUserId == null || widget.currentUserId == widget.user.id) {
      return;
    }

    try {
      // Check if already friends
      final friends = await _friendService.getFriends(widget.currentUserId!);
      final friendIds = friends.map((f) => f['id'] as String).toSet();
      final isFriend = friendIds.contains(widget.user.id);

      if (mounted) {
        setState(() {
          _isFriend = isFriend;
        });
      }
    } catch (e) {
      debugPrint('Error checking friendship status: $e');
    }
  }

  Future<void> _sendFriendRequest() async {
    if (widget.currentUserId == null) return;

    setState(() {
      _isSendingRequest = true;
    });

    try {
      await _friendService.sendFriendRequest(widget.user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande d\'ami envoyée !')),
        );
        setState(() {
          _hasPendingRequest = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
        });
      }
    }
  }

  Future<void> _removeFriend() async {
    if (widget.currentUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceColor,
        title: const Text('Retirer des amis', style: TextStyle(color: Colors.white)),
        content: const Text('Voulez-vous vraiment retirer cet utilisateur de vos amis ?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _friendService.removeFriend(widget.user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utilisateur retiré des amis')),
          );
          setState(() {
            _isFriend = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = widget.currentUserId == widget.user.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: Container(
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: widget.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name ?? widget.user.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${widget.user.username}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isCurrentUser && !_isFriend && !_hasPendingRequest)
            ElevatedButton(
              onPressed: _isSendingRequest ? null : _sendFriendRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: backgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isSendingRequest
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(backgroundColor),
                      ),
                    )
                  : const Text('Ajouter'),
            ),
          if (_hasPendingRequest)
            const Text(
              'En attente',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          if (_isFriend)
            ElevatedButton(
              onPressed: _removeFriend,
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                foregroundColor: backgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Ami'),
            ),
        ],
      ),
    );
  }
}
