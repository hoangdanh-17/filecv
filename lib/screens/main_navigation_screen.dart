import 'package:flutter/material.dart';

// Import các màn hình cùng nằm trong thư mục lib/screens/
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const Center(child: Text('Màn hình Chat (Đang phát triển)')),
    const Center(child: Text('Màn hình Short Video (Đang phát triển)')),
    const Center(child: Text('Màn hình Chat AI (Đang phát triển)')),
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6558F5);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ConnectAI',
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.slideshow_outlined),
            activeIcon: Icon(Icons.slideshow),
            label: 'Short Video',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.smart_toy),
            label: 'Chat AI',
          ),
        ],
      ),
    );
  }
}