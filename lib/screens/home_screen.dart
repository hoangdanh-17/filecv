import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _postController = TextEditingController();
  bool _isPosting = false;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  // Đăng bài viết dạng văn bản
  Future<void> _createPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty || user == null) return;

    setState(() => _isPosting = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final authorName = userData['displayName'] ?? user!.displayName ?? 'Người dùng';
      final authorPhoto = userData['photoUrl'] ?? user!.photoURL ?? '';

      await FirebaseFirestore.instance.collection('posts').add({
        'authorId': user!.uid,
        'authorName': authorName,
        'authorPhoto': authorPhoto,
        'content': text,
        'likes': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      _postController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đăng bài viết!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đăng bài: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // Tăng / Giảm lượt Thích
  Future<void> _toggleLike(String postId, List likes) async {
    if (user == null) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    if (likes.contains(user!.uid)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([user!.uid])
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([user!.uid])
      });
    }
  }

  // Mở BottomSheet bình luận
  void _showCommentsSheet(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentsWidget(postId: postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Khung nhập bài viết
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Bạn đang nghĩ gì?',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isPosting ? null : _createPost,
                  icon: _isPosting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send_rounded, color: Color(0xFF6558F5)),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // Danh sách bài viết từ Firestore
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Lỗi khi tải bài viết.'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('Chưa có bài viết nào.'));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final post = docs[index].data() as Map<String, dynamic>;
                  final postId = docs[index].id;
                  final likes = List<String>.from(post['likes'] ?? []);
                  final isLiked = user != null && likes.contains(user!.uid);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: (post['authorPhoto'] ?? '').isNotEmpty
                                  ? NetworkImage(post['authorPhoto'])
                                  : null,
                              child: (post['authorPhoto'] ?? '').isEmpty
                                  ? Text((post['authorName'] ?? 'U')[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(
                              post['authorName'] ?? 'Người dùng',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            post['content'] ?? '',
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.red : Colors.grey,
                                ),
                                onPressed: () => _toggleLike(postId, likes),
                              ),
                              Text('${likes.length}'),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.mode_comment_outlined),
                                onPressed: () => _showCommentsSheet(postId),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// Sub-widget xử lý giao diện Bình luận
class CommentsWidget extends StatefulWidget {
  final String postId;
  const CommentsWidget({super.key, required this.postId});

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'authorId': user.uid,
      'authorName': userData['displayName'] ?? user.displayName ?? 'Người dùng',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Bình luận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final comments = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final data = comments[index].data() as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      title: Text(data['authorName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(data['text'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(hintText: 'Nhập bình luận...'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendComment,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}