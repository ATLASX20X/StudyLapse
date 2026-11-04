import 'package:flutter/material.dart';
import '../main.dart';
import '../models/post.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/friend_service.dart';
import '../widgets/post_card.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key, this.subjectFilter});

  final String? subjectFilter;

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();
  final FriendService _friendService = FriendService();

  final List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 10;
  String _feedType = 'community'; // 'community' or 'friends'
  List<String> _friendIds = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadPosts();
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

  Future<void> _loadFriendIds() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) return;

      final friends = await _friendService.getFriends(currentUser.id);
      final ids = friends.map((friend) => friend['id'] as String).toList();
      
      debugPrint('Loaded ${ids.length} friend IDs: $ids');
      
      if (mounted) {
        setState(() {
          _friendIds = ids;
        });
      }
    } catch (e) {
      debugPrint('Error loading friend IDs: $e');
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Try to get current user
      final currentUser = await _authService.getCurrentUser();
      
      // If not authenticated, just show empty state
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        return;
      }

      // Load friend IDs if in friends mode
      if (_feedType == 'friends' && _friendIds.isEmpty) {
        await _loadFriendIds();
      }

      final newPosts = await _postService.getFeed(
        userId: currentUser.id,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        subject: widget.subjectFilter,
        friendsOnly: _feedType == 'friends',
        friendIds: _feedType == 'friends' ? _friendIds : null,
      );

      setState(() {
        _posts.addAll(newPosts);
        _currentPage++;
        _hasMore = newPosts.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading posts: $e');
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _currentPage = 0;
      _hasMore = true;
    });
    await _loadPosts();
  }

  void refresh() {
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Do NOT auto-refresh on every dependency change to reduce Supabase calls
    // User can manually refresh with the refresh button
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.subjectFilter ?? 'Feed'),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
        bottom: widget.subjectFilter == null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _FeedTypeButton(
                        label: 'Communauté',
                        isSelected: _feedType == 'community',
                        onTap: () {
                          setState(() {
                            _feedType = 'community';
                            _posts.clear();
                            _currentPage = 0;
                            _hasMore = true;
                            _loadPosts();
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      _FeedTypeButton(
                        label: 'Amis',
                        isSelected: _feedType == 'friends',
                        onTap: () async {
                          await _loadFriendIds();
                          setState(() {
                            _feedType = 'friends';
                            _posts.clear();
                            _currentPage = 0;
                            _hasMore = true;
                          });
                          _loadPosts();
                        },
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: accentColor,
        child: _posts.isEmpty && !_isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: 64,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun timelapse pour le moment',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sois le premier à publier !',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _posts.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _posts.length) {
                    // Load more indicator
                    if (_isLoading) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: accentColor),
                        ),
                      );
                    }
                    // Load more when scrolling to bottom
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _loadPosts();
                    });
                    return const SizedBox.shrink();
                  }

                  return PostCard(
                    post: _posts[index],
                    onTap: () {
                      // TODO: Navigate to post detail screen
                    },
                    isOwnPost: _currentUserId != null && _posts[index].authorId == _currentUserId,
                    onDelete: () {
                      setState(() {
                        _posts.removeAt(index);
                      });
                    },
                    onChanged: () {
                      // Refresh the feed when post changes
                      _refresh();
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _FeedTypeButton extends StatelessWidget {
  const _FeedTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? backgroundColor : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
