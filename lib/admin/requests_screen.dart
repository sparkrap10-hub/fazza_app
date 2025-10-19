import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_tracking_screen.dart';

class RequestsScreen extends StatefulWidget {
  final String? searchQuery;
  const RequestsScreen({super.key, this.searchQuery});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _updateRequestStatus(String id, String status) async {
    await _firestore.collection('requests').doc(id).update({'status': status});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تم تحديث حالة الطلب إلى $status")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة الطلبات")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('requests').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final requests = snapshot.data!.docs;
          final query = widget.searchQuery?.toLowerCase() ?? '';

          final filteredRequests = requests.where((r) {
            final data = r.data() as Map<String, dynamic>;
            final service = (data['service_type'] ?? '').toString().toLowerCase();
            final status = (data['status'] ?? '').toString().toLowerCase();
            final userEmail = (data['user_email'] ?? '').toString().toLowerCase();
            return service.contains(query) || status.contains(query) || userEmail.contains(query);
          }).toList();

          if (filteredRequests.isEmpty) {
            return const Center(child: Text("لا توجد طلبات مطابقة للبحث"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredRequests.length,
            itemBuilder: (context, index) {
              final req = filteredRequests[index];
              final data = req.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.request_page),
                  title: Text("الخدمة: ${data['service_type'] ?? 'غير معروف'}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("الوصف: ${data['notes'] ?? 'لا يوجد'}"),
                      Text("المستخدم: ${data['user_email'] ?? 'غير معروف'}"),
                      Text("الحالة: ${data['status'] ?? 'pending'}"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        onSelected: (status) => _updateRequestStatus(req.id, status),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'accepted', child: Text("قبول الطلب")),
                          PopupMenuItem(value: 'rejected', child: Text("رفض الطلب")),
                        ],
                        child: const Icon(Icons.more_vert),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map, color: Colors.blue),
                        tooltip: 'تتبع الطلب',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrackingScreen(requestId: req.id),
                            ),
                          );
                        },
                      ),
                    ],
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
