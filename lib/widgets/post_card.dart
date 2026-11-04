import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../main.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/like_service.dart';
import '../services/comment_service.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.isOwnPost = false,
    this.onDelete,
    this.onChanged,
  });

  final Post post;
  final VoidCallback onTap;
  final bool isOwnPost;
  final VoidCallback? onDelete;
  final VoidCallback? onChanged;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLiked = false;
  bool _isLikeLoading = false;
  String? _currentUserId;
  int _localLikesCount = 0;
  int _localCommentsCount = 0;
  bool _showComments = false;
  List<Comment> _comments = [];
  bool _isLoadingComments = false;
  bool _hasMoreComments = false;
  int _commentsPage = 0;
  final int _commentsPageSize = 10;
  final TextEditingController _commentController = TextEditingController();

  final LikeService _likeService = LikeService();
  final CommentService _commentService = CommentService();
  final PostService _postService = PostService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _localLikesCount = widget.post.likesCount;
    _localCommentsCount = widget.post.commentsCount;
    _initializePlayer();
    _checkLikeStatus();
    _getCurrentUserId();
    // Reload counts from database to ensure accuracy
    _reloadCountsFromDatabase();
  }

  Future<void> _reloadCountsFromDatabase() async {
    try {
      // Reload the post from database to get accurate counts
      final updatedPost = await _postService.getPost(widget.post.id);
      if (updatedPost != null && mounted) {
        setState(() {
          _localLikesCount = updatedPost.likesCount;
          _localCommentsCount = updatedPost.commentsCount;
        });
      }
    } catch (e) {
      debugPrint('Error reloading counts: $e');
    }
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local counts when post data changes
    if (oldWidget.post.id != widget.post.id) {
      // Post changed completely, reset everything
      _localLikesCount = widget.post.likesCount;
      _localCommentsCount = widget.post.commentsCount;
      _checkLikeStatus();
    } else {
      // Same post, update counts if they changed
      if (oldWidget.post.likesCount != widget.post.likesCount) {
        _localLikesCount = widget.post.likesCount;
      }
      if (oldWidget.post.commentsCount != widget.post.commentsCount) {
        _localCommentsCount = widget.post.commentsCount;
      }
    }
  }

  Future<void> _getCurrentUserId() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUserId = user?.id;
      });
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.post.videoUrl));
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.pause(); // Start paused
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize video player: $e');
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  Future<void> _checkLikeStatus() async {
    if (!_authService.isAuthenticated) return;
    
    try {
      final isLiked = await _likeService.isLiked(widget.post.id);
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    } catch (e) {
      debugPrint('Error checking like status: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (!_authService.isAuthenticated) return;

    setState(() {
      _isLikeLoading = true;
    });

    try {
      if (_isLiked) {
        await _likeService.unlikePost(widget.post.id);
        setState(() {
          _isLiked = false;
          _localLikesCount--;
        });
      } else {
        await _likeService.likePost(widget.post.id);
        setState(() {
          _isLiked = true;
          _localLikesCount++;
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
        });
      }
    }
  }

  Future<void> _loadComments({bool loadMore = false}) async {
    if (loadMore && !_hasMoreComments) return;

    setState(() {
      _isLoadingComments = true;
    });

    try {
      final commentsData = await _commentService.getPostComments(
        postId: widget.post.id,
        limit: _commentsPageSize,
        offset: loadMore ? _commentsPage * _commentsPageSize : 0,
      );
      final comments = commentsData.map((json) => Comment.fromJson(json)).toList();
      
      if (mounted) {
        setState(() {
          if (loadMore) {
            _comments.addAll(comments);
            _commentsPage++;
          } else {
            _comments = comments;
            _commentsPage = 1;
          }
          _hasMoreComments = comments.length >= _commentsPageSize;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _toggleComments() async {
    if (!_showComments) {
      await _loadComments();
    }
    setState(() {
      _showComments = !_showComments;
    });
  }

  Future<void> _addComment(String text) async {
    if (!_authService.isAuthenticated) return;

    try {
      await _commentService.addComment(widget.post.id, text);
      await _loadComments();
      if (mounted) {
        setState(() {
          _localCommentsCount++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commentaire ajouté')),
        );
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
    }
  }

  Future<void> _deletePost() async {
    if (_currentUserId != widget.post.authorId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceColor,
        title: const Text(
          'Supprimer la publication',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette publication ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete from storage first
      if (widget.post.videoUrl.isNotEmpty) {
        await _storageService.deleteFile(widget.post.videoUrl);
      }
      if (widget.post.thumbnailUrl != null && widget.post.thumbnailUrl!.isNotEmpty) {
        await _storageService.deleteFile(widget.post.thumbnailUrl!);
      }
      
      // Delete from database
      await _postService.deletePost(widget.post.id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication supprimée')),
      );
      
      // Notify parent to remove from list and refresh
      widget.onDelete?.call();
      widget.onChanged?.call();
    } catch (e) {
      debugPrint('Error deleting post: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la suppression')),
      );
    }
  }

  Future<void> _downloadVideo() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléchargement en cours...')),
      );

      // Download video
      final response = await http.get(Uri.parse(widget.post.videoUrl));
      final bytes = response.bodyBytes;

      // Save to gallery
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await file.writeAsBytes(bytes);

      await Gal.putVideo(file.path, album: 'StudyLapse');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vidéo téléchargée dans la galerie')),
        );
      }
    } catch (e) {
      debugPrint('Error downloading video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement: $e')),
        );
      }
    }
  }

  Future<void> _changeVisibility() async {
    final visibility = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceColor,
        title: const Text(
          'Changer la visibilité',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Public', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(dialogContext, 'public'),
            ),
            ListTile(
              title: const Text('Amis uniquement', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(dialogContext, 'friends'),
            ),
            ListTile(
              title: const Text('Privé', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(dialogContext, 'private'),
            ),
          ],
        ),
      ),
    );

    if (visibility == null) return;

    try {
      await _postService.updatePost(
        postId: widget.post.id,
        visibility: visibility == 'public' 
            ? PostVisibility.public 
            : visibility == 'friends' 
                ? PostVisibility.friends 
                : PostVisibility.private,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visibilité mise à jour')),
        );
        // Notify parent to refresh
        widget.onChanged?.call();
      }
    } catch (e) {
      debugPrint('Error changing visibility: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: surfaceColor,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video preview
            AspectRatio(
              aspectRatio: 9 / 16,
              child: GestureDetector(
                onTap: _isInitialized ? _togglePlayPause : null,
                child: Container(
                  color: Colors.black,
                  child: _isInitialized
                      ? Stack(
                          children: [
                            VideoPlayer(_controller),
                            if (!_isPlaying)
                              const Center(
                                child: Icon(
                                  Icons.play_circle_outline,
                                  size: 64,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: accentColor),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Post info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.post.authorUsername,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.post.formattedDuration,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Subject
                  if (widget.post.subject != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.post.subject!,
                        style: const TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (widget.post.subject != null)
                      const SizedBox(height: 8),

                  // Description
                  if (widget.post.description != null)
                    Text(
                      widget.post.description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (widget.post.description != null)
                      const SizedBox(height: 8),

                  // Stats row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _isLikeLoading ? null : _toggleLike,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 24,
                            color: _isLiked ? Colors.red : Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _localLikesCount.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _toggleComments,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _showComments ? Icons.comment_rounded : Icons.comment_outlined,
                            size: 24,
                            color: _showComments ? accentColor : Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _localCommentsCount.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      // Additional buttons for own posts only
                      if (widget.isOwnPost) ...[
                        // Settings button
                        IconButton(
                          icon: const Icon(Icons.settings_rounded, size: 24),
                          color: Colors.white70,
                          onPressed: _changeVisibility,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        // Download button
                        IconButton(
                          icon: const Icon(Icons.download_rounded, size: 24),
                          color: Colors.white70,
                          onPressed: _downloadVideo,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        // Delete button
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 24),
                          color: Colors.white70,
                          onPressed: _deletePost,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                  if (_showComments) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    if (_isLoadingComments)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: accentColor),
                        ),
                      )
                    else if (_comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Aucun commentaire',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      ..._comments.map((comment) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment.authorUsername,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment.text,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    if (_hasMoreComments)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: TextButton(
                            onPressed: _isLoadingComments 
                                ? null 
                                : () => _loadComments(loadMore: true),
                            child: _isLoadingComments
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accentColor,
                                    ),
                                  )
                                : const Text('Charger plus de commentaires'),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Ajouter un commentaire...',
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: accentColor),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (text) {
                                if (text.trim().isNotEmpty) {
                                  _addComment(text.trim());
                                  _commentController.clear();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: accentColor),
                            onPressed: () {
                              final text = _commentController.text.trim();
                              if (text.isNotEmpty) {
                                _addComment(text);
                                _commentController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
