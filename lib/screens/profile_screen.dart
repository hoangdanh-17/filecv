import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingAvatar = false;
  bool _isSavingName = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.logout_rounded,
          size: 36,
          color: Color(0xFF6558F5),
        ),
        title: const Text(
          'Xác nhận đăng xuất',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi ConnectAI không?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6558F5),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    try {
      await AuthService().logout();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Không thể đăng xuất. Hãy thử lại.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Chọn ảnh đại diện từ thư viện.
  Future<void> _changeAvatar(String uid) async {
    if (_isUploadingAvatar) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (image == null || !mounted) return;

      setState(() => _isUploadingAvatar = true);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child(uid)
          .child('profile.jpg');

      await storageRef.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final imageUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'photoUrl': imageUrl,
      }, SetOptions(merge: true));

      await AuthService().currentUser?.updatePhotoURL(imageUrl);

      if (!mounted) return;
      _showMessage('Đổi ảnh đại diện thành công!');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Không thể đổi ảnh đại diện. Hãy thử lại.');
      debugPrint('Lỗi đổi avatar: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  // Đổi tên người dùng (Đã khắc phục hoàn toàn lỗi assertion)
  Future<void> _changeName({
    required String uid,
    required String currentName,
  }) async {
    final newName = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _EditNameDialog(initialName: currentName),
    );

    if (newName == null || !mounted) return;

    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      _showMessage('Tên không được để trống.');
      return;
    }

    if (trimmedName == currentName) return;

    setState(() => _isSavingName = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'displayName': trimmedName,
      }, SetOptions(merge: true));

      await AuthService().currentUser?.updateDisplayName(trimmedName);

      if (!mounted) return;
      _showMessage('Đổi tên thành công!');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Không thể đổi tên. Hãy thử lại.');
      debugPrint('Lỗi đổi tên: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingName = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ConnectAI • Hồ sơ'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Không thể tải hồ sơ. Hãy kiểm tra Firestore.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = (snapshot.data?.data() as Map<String, dynamic>?) ?? {};

        final name = (data['displayName'] ??
            user.displayName ??
            'Người dùng')
            .toString();

        final email = user.email ?? '';

        final bio = (data['bio'] ?? 'Chưa cập nhật giới thiệu')
            .toString();

        final photoUrl = (data['photoUrl'] ??
            user.photoURL ??
            '')
            .toString();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),

            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: const Color(0xFFE8E5FF),
                    backgroundImage: photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl.isEmpty
                        ? Text(
                      name.trim().isNotEmpty
                          ? name.trim()[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6558F5),
                      ),
                    )
                        : null,
                  ),
                  Material(
                    color: const Color(0xFF6558F5),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isUploadingAvatar
                          ? null
                          : () => _changeAvatar(user.uid),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: _isUploadingAvatar
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Đổi tên',
                  onPressed: _isSavingName
                      ? null
                      : () => _changeName(
                    uid: user.uid,
                    currentName: name,
                  ),
                  icon: _isSavingName
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: Color(0xFF6558F5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),

            const SizedBox(height: 28),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Giới thiệu bản thân',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(bio),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: ListTile(
                leading: Icon(
                  user.emailVerified
                      ? Icons.verified_user_rounded
                      : Icons.warning_amber_rounded,
                  color: user.emailVerified
                      ? Colors.green
                      : Colors.orange,
                ),
                title: Text(
                  user.emailVerified
                      ? 'Tài khoản đã xác minh'
                      : 'Email chưa xác minh',
                ),
                subtitle: Text(
                  user.emailVerified
                      ? 'Email được xác minh bởi Firebase'
                      : 'Vui lòng xác minh địa chỉ email của bạn',
                ),
              ),
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.red),
              ),
            ),

            const SizedBox(height: 16),
          ],
        );
      },
      ),
    );
  }
}

// Widget Dialog riêng biệt để quản lý lifecycle an toàn
class _EditNameDialog extends StatefulWidget {
  final String initialName;
  const _EditNameDialog({required this.initialName});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi tên hiển thị'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Tên mới',
          hintText: 'Nhập tên của bạn',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_outline),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6558F5),
          ),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}