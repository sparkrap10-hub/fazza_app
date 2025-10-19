import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersScreen extends StatefulWidget {
  final String? searchQuery;
  const UsersScreen({super.key, this.searchQuery});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _updateUserRole(String uid, String newRole) async {
    await _firestore.collection('users').doc(uid).update({'role': newRole});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تم تغيير دور المستخدم إلى $newRole")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة المستخدمين")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data!.docs;
          final query = widget.searchQuery?.toLowerCase() ?? '';

          final filteredUsers = users.where((u) {
            final data = u.data() as Map<String, dynamic>;
            final email = (data['email'] ?? '').toString().toLowerCase();
            final role = (data['role'] ?? '').toString().toLowerCase();
            return email.contains(query) || role.contains(query);
          }).toList();

          if (filteredUsers.isEmpty) {
            return const Center(child: Text("لا توجد مستخدمين مطابقة للبحث"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              final data = user.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(data['email'] ?? 'غير معروف'),
                  subtitle: Text("الدور: ${data['role'] ?? 'user'}"),
                  trailing: PopupMenuButton<String>(
                    onSelected: (role) => _updateUserRole(user.id, role),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'user', child: Text("User")),
                      PopupMenuItem(value: 'admin', child: Text("Admin")),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
