import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/user.dart' as models;
import '../models/post.dart';
import '../models/friend_request.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../services/friend_service.dart';
import '../widgets/post_card.dart';
import 'login_screen.dart';
import 'friends_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    this.userId,
  });

  final String? userId; // If null, show current user's profile

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final PostService _postService = PostService();
  final FriendService _friendService = FriendService();

  models.AppUser? _user;
  models.AppUser? _currentUser; // Current authenticated user
  List<Post> _posts = [];
  List<FriendRequest> _pendingRequests = [];
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isFriend = false;
  bool _hasPendingRequest = false;
  bool _isSendingRequest = false;

  bool get isOwnProfile => widget.userId == null || widget.userId == _currentUser?.id;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isUsernameAvailable = false;
  bool _isCheckingUsername = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Do NOT auto-refresh on every dependency change to reduce Supabase calls
    // Profile is refreshed via callbacks from PostCard
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) {
      setState(() {
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
      });
      return;
    }

    // If username hasn't changed, it's available
    if (_user != null && username == _user!.username) {
      setState(() {
        _isUsernameAvailable = true;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    try {
      final isAvailable = await _userService.isUsernameAvailable(username);
      if (mounted) {
        setState(() {
          _isUsernameAvailable = isAvailable;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      if (mounted) {
        setState(() {
          _isUsernameAvailable = false;
          _isCheckingUsername = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await _authService.logout();
        if (mounted) {
          // Navigate to login screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de déconnexion: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void refreshProfile() {
    _loadProfile();
  }

  Future<void> _acceptFriendRequest(FriendRequest request) async {
    try {
      await _friendService.acceptFriendRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande acceptée !')),
        );
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _rejectFriendRequest(FriendRequest request) async {
    try {
      await _friendService.rejectFriendRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande rejetée')),
        );
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current authenticated user
      final currentUser = await _authService.getCurrentUser();
      _currentUser = currentUser;

      String userId = widget.userId ?? '';

      if (userId.isEmpty) {
        // Show own profile
        if (currentUser != null) {
          userId = currentUser.id;
          _user = currentUser;
        } else {
          // User not authenticated - show placeholder
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else {
        // Show another user's profile
        _user = await _userService.getUser(userId);
      }

      if (_user != null && userId.isNotEmpty) {
        _nameController.text = _user!.name ?? '';
        _usernameController.text = _user!.username;
        _bioController.text = _user!.bio ?? '';
        
        debugPrint('Loaded profile: name="${_user!.name}", username="${_user!.username}"');

        final posts = await _postService.getUserPosts(userId: userId);

        // Load pending requests if own profile
        if (isOwnProfile) {
          _pendingRequests = await _friendService.getPendingRequests();
        }

        // Check friendship status if viewing another user's profile
        if (!isOwnProfile && currentUser != null) {
          await _checkFriendshipStatus();
        }

        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkFriendshipStatus() async {
    if (_currentUser == null || _user == null) return;

    try {
      final friends = await _friendService.getFriends(_currentUser!.id);
      final friendIds = friends.map((f) => f['id'] as String).toSet();
      final isFriend = friendIds.contains(_user!.id);

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
    if (_currentUser == null || _user == null) return;

    setState(() {
      _isSendingRequest = true;
    });

    try {
      await _friendService.sendFriendRequest(_user!.id);
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
    if (_currentUser == null || _user == null) return;

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
        await _friendService.removeFriend(_user!.id);
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

  Future<void> _saveProfile() async {
    if (_user == null) return;

    try {
      await _userService.updateProfile(
        userId: _user!.id,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Profil'),
          backgroundColor: backgroundColor,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: accentColor),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Profil'),
          backgroundColor: backgroundColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_rounded,
                size: 64,
                color: Colors.white24,
              ),
              const SizedBox(height: 16),
              const Text(
                'Profil introuvable',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Se déconnecter'),
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isOwnProfile = widget.userId == null || widget.userId == _currentUser?.id;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_user!.username),
        backgroundColor: backgroundColor,
        actions: [
          if (!isOwnProfile && !_isFriend && !_hasPendingRequest)
            ElevatedButton(
              onPressed: _isSendingRequest ? null : _sendFriendRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: backgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          if (!isOwnProfile && _hasPendingRequest)
            const Text(
              'En attente',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          if (!isOwnProfile && _isFriend)
            ElevatedButton(
              onPressed: _removeFriend,
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                foregroundColor: backgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Ami'),
            ),
          if (isOwnProfile) ...[
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: _user!.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              _user!.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person_rounded,
                                  size: 52,
                                  color: accentColor,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            size: 52,
                            color: accentColor,
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Display name (large)
                  if (_isEditing)
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]')),
                      ],
                    )
                  else
                    Text(
                      _user!.name ?? 'Sans nom',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Username (@format)
                  if (_isEditing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('@', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _usernameController,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              isDense: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                            ],
                            onChanged: (value) {
                              _checkUsernameAvailability(value.trim());
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isCheckingUsername)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentColor,
                            ),
                          )
                        else if (_usernameController.text.isNotEmpty)
                          Icon(
                            _isUsernameAvailable ? Icons.check_circle : Icons.cancel,
                            color: _isUsernameAvailable ? Colors.green : Colors.red,
                            size: 20,
                          ),
                      ],
                    )
                  else
                    Text(
                      '@${_user!.username}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Bio
                  if (_isEditing)
                    TextField(
                      controller: _bioController,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: 'Ajouter une bio...',
                        border: UnderlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      maxLines: 3,
                    )
                  else
                    Text(
                      _user!.bio ?? 'Aucune bio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(
                        label: 'Posts',
                        value: _user!.postsCount.toString(),
                      ),
                      _StatItem(
                        label: 'Amis',
                        value: _user!.friendsCount.toString(),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FriendsScreen(userId: _user!.id),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Storage usage
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Stockage utilisé',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${(_user!.storageUsedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / 1 GB',
                              style: const TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: _user!.storageUsedPercentage / 100,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _user!.storageUsedPercentage > 80
                                ? Colors.red
                                : accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Pending friend requests (only for own profile)
            if (isOwnProfile && _pendingRequests.isNotEmpty) ...[
              const Divider(height: 1, color: Colors.white10),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Demandes d\'amis (${_pendingRequests.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              ..._pendingRequests.map((request) => ListTile(
                leading: const CircleAvatar(
                  backgroundColor: accentColor,
                  child: Icon(Icons.person_rounded, color: backgroundColor),
                ),
                title: Text(
                  request.fromUsername,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Veut être ton ami',
                  style: TextStyle(color: Colors.white70),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () {
                        _acceptFriendRequest(request);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () {
                        _rejectFriendRequest(request);
                      },
                    ),
                  ],
                ),
              )),
            ],

            // Posts grid
            const Divider(height: 1, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Timelapses (${_posts.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white10),

            if (_posts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Text(
                  'Aucun timelapse publié',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  return PostCard(
                    post: _posts[index],
                    onTap: () {
                      // TODO: Navigate to post detail
                    },
                    isOwnPost: isOwnProfile,
                    onDelete: () {
                      setState(() {
                        _posts.removeAt(index);
                      });
                    },
                    onChanged: () {
                      // Refresh the profile when post changes
                      _loadProfile();
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
