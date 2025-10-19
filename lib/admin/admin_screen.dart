import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'users_screen.dart';
import 'requests_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة التحكم - الأدمن"),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _logout,
            tooltip: 'تسجيل خروج',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // شريط البحث
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'ابحث عن مستخدم أو طلب',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _onSearchChanged(),
            ),
            const SizedBox(height: 16),

            // أزرار إدارة المستخدمين والطلبات ومزودي الخدمة - مصححة
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildActionButton(
                    icon: Icons.people,
                    label: "المستخدمين",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UsersScreen(searchQuery: _searchQuery),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 5),
                  _buildActionButton(
                    icon: Icons.request_page,
                    label: "الطلبات",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestsScreen(searchQuery: _searchQuery),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 5),
                  _buildActionButton(
                    icon: Icons.business_center,
                    label: "المزودين",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProvidersScreen(searchQuery: _searchQuery),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // إحصائيات المستخدمين
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data!.docs;

                  // تصفية البحث
                  final filteredUsers = users.where((u) {
                    final email = (u.data() as Map<String, dynamic>)['email'] ?? '';
                    final role = (u.data() as Map<String, dynamic>)['role'] ?? '';
                    return email.toString().toLowerCase().contains(_searchQuery) ||
                        role.toString().toLowerCase().contains(_searchQuery);
                  }).toList();

                  return ListView(
                    children: [
                      Card(
                        child: ListTile(
                          title: Text("عدد المستخدمين: ${users.length}"),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          title: Text(
                              "عدد الأدمن: ${users.where((u) => (u.data() as Map<String, dynamic>)['role'] == 'admin').length}"),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...filteredUsers.map((u) {
                        final data = u.data() as Map<String, dynamic>;
                        final email = data['email'] ?? 'غير معروف';
                        final role = data['role'] ?? 'user';
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(email),
                            subtitle: Text("الدور: $role"),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة لبناء أزرار متجاوبة
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// صفحة مزودي الخدمة الجديدة
class ProvidersScreen extends StatefulWidget {
  final String searchQuery;
  
  const ProvidersScreen({super.key, required this.searchQuery});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // دالة لإضافة مزود جديد
  void _addNewProvider() {
    showDialog(
      context: context,
      builder: (context) => AddProviderDialog(),
    );
  }

  // دالة لعرض تفاصيل المزود
  void _showProviderDetails(DocumentSnapshot provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProviderDetailsSheet(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة مزودي الخدمة"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewProvider,
            tooltip: 'إضافة مزود جديد',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'ابحث عن مزود خدمة',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('providers').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final providers = snapshot.data!.docs;

                // تصفية البحث
                final filteredProviders = providers.where((provider) {
                  final data = provider.data() as Map<String, dynamic>;
                  final companyName = data['company_name']?.toString().toLowerCase() ?? '';
                  final email = data['email']?.toString().toLowerCase() ?? '';
                  final services = data['services']?.toString().toLowerCase() ?? '';
                  
                  final searchTerm = _searchController.text.trim().toLowerCase();
                  return companyName.contains(searchTerm) ||
                         email.contains(searchTerm) ||
                         services.contains(searchTerm);
                }).toList();

                if (filteredProviders.isEmpty) {
                  return const Center(
                    child: Text("لا توجد نتائج"),
                  );
                }

                return ListView.builder(
                  itemCount: filteredProviders.length,
                  itemBuilder: (context, index) {
                    final provider = filteredProviders[index];
                    final data = provider.data() as Map<String, dynamic>;
                    
                    return ProviderCard(
                      provider: provider,
                      onTap: () => _showProviderDetails(provider),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// بطاقة مزود الخدمة
class ProviderCard extends StatelessWidget {
  final DocumentSnapshot provider;
  final VoidCallback onTap;

  const ProviderCard({
    super.key,
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = provider.data() as Map<String, dynamic>;
    final companyName = data['company_name'] ?? 'غير محدد';
    final email = data['email'] ?? 'غير محدد';
    final rating = data['rating']?.toDouble() ?? 0.0;
    final completedRequests = data['completed_requests'] ?? 0;
    final status = data['status'] ?? 'pending';
    final services = data['services'] ?? 'خدمات متعددة';

    Color getStatusColor(String status) {
      switch (status) {
        case 'approved': return Colors.green;
        case 'pending': return Colors.orange;
        case 'rejected': return Colors.red;
        default: return Colors.grey;
      }
    }

    String getStatusText(String status) {
      switch (status) {
        case 'approved': return 'مفعل';
        case 'pending': return 'قيد المراجعة';
        case 'rejected': return 'مرفوض';
        default: return 'غير معروف';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            companyName.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(companyName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('$rating'),
                const SizedBox(width: 16),
                Icon(Icons.work, color: Colors.blue, size: 16),
                const SizedBox(width: 4),
                Text('$completedRequests طلبات'),
              ],
            ),
            const SizedBox(height: 4),
            Text('الخدمات: $services'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: getStatusColor(status)),
          ),
          child: Text(
            getStatusText(status),
            style: TextStyle(
              color: getStatusColor(status),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// نافذة إضافة مزود جديد
class AddProviderDialog extends StatefulWidget {
  const AddProviderDialog({super.key});

  @override
  State<AddProviderDialog> createState() => _AddProviderDialogState();
}

class _AddProviderDialogState extends State<AddProviderDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _servicesController = TextEditingController();
  String _selectedStatus = 'approved';

  @override
  void dispose() {
    _emailController.dispose();
    _companyNameController.dispose();
    _phoneController.dispose();
    _servicesController.dispose();
    super.dispose();
  }

  Future<void> _addProvider() async {
    if (_formKey.currentState!.validate()) {
      try {
        // التحقق من وجود المستخدم أولاً
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: _emailController.text.trim())
            .get();

        if (userQuery.docs.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد مستخدم بهذا البريد الإلكتروني'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final user = userQuery.docs.first;
        
        // إضافة/تحديث المزود
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(user.id)
            .set({
              'email': _emailController.text.trim(),
              'company_name': _companyNameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'services': _servicesController.text.trim(),
              'status': _selectedStatus,
              'rating': 0.0,
              'completed_requests': 0,
              'created_at': FieldValue.serverTimestamp(),
              'user_id': user.id,
            }, SetOptions(merge: true));

        // تحديث دور المستخدم
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({
              'role': 'provider',
            });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة المزود بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة المزود: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مزود خدمة جديد'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال البريد الإلكتروني';
                  }
                  if (!value.contains('@')) {
                    return 'يرجى إدخال بريد إلكتروني صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الشركة',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم الشركة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _servicesController,
                decoration: const InputDecoration(
                  labelText: 'الخدمات المقدمة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'الحالة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text('مفعل'),
                  ),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('قيد المراجعة'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('مرفوض'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _addProvider,
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}

// نافذة تعديل مزود
class EditProviderDialog extends StatefulWidget {
  final DocumentSnapshot provider;

  const EditProviderDialog({super.key, required this.provider});

  @override
  State<EditProviderDialog> createState() => _EditProviderDialogState();
}

class _EditProviderDialogState extends State<EditProviderDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _companyNameController;
  late TextEditingController _phoneController;
  late TextEditingController _servicesController;
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    final data = widget.provider.data() as Map<String, dynamic>;
    _companyNameController = TextEditingController(text: data['company_name'] ?? '');
    _phoneController = TextEditingController(text: data['phone'] ?? '');
    _servicesController = TextEditingController(text: data['services'] ?? '');
    _selectedStatus = data['status'] ?? 'approved';
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _phoneController.dispose();
    _servicesController.dispose();
    super.dispose();
  }

  Future<void> _updateProvider() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(widget.provider.id)
            .update({
              'company_name': _companyNameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'services': _servicesController.text.trim(),
              'status': _selectedStatus,
              'updated_at': FieldValue.serverTimestamp(),
            });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث بيانات المزود بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.provider.data() as Map<String, dynamic>;
    final email = data['email'] ?? 'غير محدد';

    return AlertDialog(
      title: const Text('تعديل بيانات المزود'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // البريد الإلكتروني (غير قابل للتعديل)
              TextFormField(
                initialValue: email,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                  filled: true,
                  enabled: false,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الشركة',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم الشركة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _servicesController,
                decoration: const InputDecoration(
                  labelText: 'الخدمات المقدمة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'الحالة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text('مفعل'),
                  ),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('قيد المراجعة'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('مرفوض'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _updateProvider,
          child: const Text('حفظ التغييرات'),
        ),
      ],
    );
  }
}

// صفحة تفاصيل المزود
class ProviderDetailsSheet extends StatelessWidget {
  final DocumentSnapshot provider;

  const ProviderDetailsSheet({super.key, required this.provider});

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'غير محدد';
    try {
      return timestamp.toDate().toString().substring(0, 16);
    } catch (e) {
      return 'غير محدد';
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved': return 'مفعل';
      case 'pending': return 'قيد المراجعة';
      case 'rejected': return 'مرفوض';
      default: return 'غير معروف';
    }
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '$title: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ));
  }

  Widget _buildCompletedRequestsTab(String providerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .where('provider_id', isEqualTo: providerId)
          .where('status', isEqualTo: 'completed')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return const Center(child: Text('لا توجد طلبات مكتملة'));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            
            return ListTile(
              leading: const Icon(Icons.assignment_turned_in, color: Colors.green),
              title: Text(data['service_type'] ?? 'خدمة غير محددة'),
              subtitle: Text('التاريخ: ${_formatDate(data['created_at'])}'),
              trailing: Text(data['is_rated'] == true ? 'تم التقييم' : 'لم يتم التقييم'),
            );
          },
        );
      },
    );
  }

  Widget _buildRatingsTab(String providerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ratings')
          .where('provider_id', isEqualTo: providerId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final ratings = snapshot.data!.docs;

        if (ratings.isEmpty) {
          return const Center(child: Text('لا توجد تقييمات'));
        }

        return ListView.builder(
          itemCount: ratings.length,
          itemBuilder: (context, index) {
            final rating = ratings[index];
            final data = rating.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text('${data['rating']} ⭐'),
                subtitle: data['review'] != null && data['review'].toString().isNotEmpty
                    ? Text(data['review'])
                    : const Text('لا يوجد تعليق'),
                trailing: Text(_formatDate(data['created_at'])),
              ),
            );
          },
        );
      },
    );
  }

  void _editProvider(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EditProviderDialog(provider: provider),
    );
  }

  void _deleteProvider(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المزود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('providers')
                    .doc(provider.id)
                    .delete();
                
                if (!context.mounted) return;
                Navigator.pop(context); // إغلاق dialog
                Navigator.pop(context); // إغلاق bottom sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف المزود بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('خطأ في الحذف: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = provider.data() as Map<String, dynamic>;
    final companyName = data['company_name'] ?? 'غير محدد';
    final email = data['email'] ?? 'غير محدد';
    final phone = data['phone'] ?? 'غير محدد';
    final services = data['services'] ?? 'غير محدد';
    final rating = data['rating']?.toDouble() ?? 0.0;
    final completedRequests = data['completed_requests'] ?? 0;
    final status = data['status'] ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue,
                child: Text(
                  companyName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow('رقم الهاتف', phone),
          _buildDetailRow('الخدمات', services),
          _buildDetailRow('التقييم', '$rating ⭐'),
          _buildDetailRow('الطلبات المكتملة', '$completedRequests طلب'),
          _buildDetailRow('الحالة', _getStatusText(status)),
          
          const SizedBox(height: 24),
          const Text(
            'الطلبات والتقييمات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'الطلبات المكتملة'),
                      Tab(text: 'التقييمات'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // تبويب الطلبات المكتملة
                        _buildCompletedRequestsTab(provider.id),
                        // تبويب التقييمات
                        _buildRatingsTab(provider.id),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _editProvider(context),
                  child: const Text('تعديل البيانات'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _deleteProvider(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حذف المزود'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}