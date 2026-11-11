import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
      ),
      body: user == null
          ? const Center(child: Text('Vui lòng đăng nhập.'))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Bạn chưa có thông báo nào.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final notification = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.notifications, color: Color(0xFF6558F5)),
                title: Text(notification['title'] ?? 'Thông báo'),
                subtitle: Text(notification['body'] ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}