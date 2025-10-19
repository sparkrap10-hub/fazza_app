import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'home.dart';

class UserRequestsPage extends StatefulWidget {
  const UserRequestsPage({super.key});

  @override
  State<UserRequestsPage> createState() => _UserRequestsPageState();
}

class _UserRequestsPageState extends State<UserRequestsPage> with SingleTickerProviderStateMixin {
  String _sortBy = "created_at";
  bool _descending = true;
  String? _filterStatus;
  int _currentIndex = 1;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "accepted":
        return Colors.green;
      case "rejected":
        return Colors.red;
      case "completed":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case "pending":
        return "قيد الانتظار";
      case "accepted":
        return "مقبول";
      case "rejected":
        return "مرفوض";
      case "completed":
        return "مكتمل";
      default:
        return "غير معروف";
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case "pending":
        return Icons.access_time;
      case "accepted":
        return Icons.check_circle;
      case "rejected":
        return Icons.cancel;
      case "completed":
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }

  Future<void> _deleteRequest(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "تأكيد الحذف",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("هل تريد حذف هذا الطلب نهائياً؟"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("إلغاء"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("حذف"),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('requests').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("تم حذف الطلب ✅"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // دالة لإظهار نافذة التقييم
  Future<void> _showRatingDialog(DocumentSnapshot request) async {
    final data = request.data() as Map<String, dynamic>;
    final providerId = data['provider_id'];
    final providerName = data['provider_name'] ?? 'مزود الخدمة';
    final requestId = request.id;
    
    int selectedRating = 0;
    String reviewText = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              "تقييم الخدمة",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "كيف كانت تجربتك مع $providerName؟",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  
                  // النجوم
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedRating == 0 ? 'اختر التقييم' : '$selectedRating من 5 نجوم',
                    style: TextStyle(
                      color: selectedRating == 0 ? Colors.grey : Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // نص التقييم
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "تعليقك (اختياري)",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      reviewText = value;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("تخطي"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedRating > 0
                          ? () async {
                              await _submitRating(
                                requestId,
                                providerId,
                                selectedRating,
                                reviewText,
                                providerName,
                              );
                              if (!mounted) return;
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("تقييم"),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // دالة لإرسال التقييم
  Future<void> _submitRating(
    String requestId,
    String providerId,
    int rating,
    String review,
    String providerName,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // حفظ التقييم في collection منفصل
      await FirebaseFirestore.instance.collection('ratings').add({
        'request_id': requestId,
        'provider_id': providerId,
        'provider_name': providerName,
        'user_id': user.uid,
        'rating': rating,
        'review': review,
        'created_at': FieldValue.serverTimestamp(),
      });

      // تحديث الطلب لإضافة حقل أن المستخدم قام بالتقييم
      await FirebaseFirestore.instance.collection('requests').doc(requestId).update({
        'is_rated': true,
        'user_rating': rating,
      });

      // تحديث متوسط تقييم المزود
      await _updateProviderRating(providerId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("شكراً لك! تم إرسال تقييمك بنجاح 🌟"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("خطأ في إرسال التقييم: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // دالة لتحديث متوسط تقييم المزود
  Future<void> _updateProviderRating(String providerId) async {
    try {
      // جمع كل تقييمات المزود
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('provider_id', isEqualTo: providerId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) return;

      double totalRating = 0;
      int ratingsCount = ratingsSnapshot.docs.length;

      for (final doc in ratingsSnapshot.docs) {
        final data = doc.data();
        totalRating += (data['rating'] as int).toDouble();
      }

      double averageRating = totalRating / ratingsCount;

      // تحديث متوسط التقييم في بيانات المزود
      await FirebaseFirestore.instance.collection('providers').doc(providerId).update({
        'rating': double.parse(averageRating.toStringAsFixed(1)),
        'ratings_count': ratingsCount,
        'last_rating_update': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('خطأ في تحديث تقييم المزود: $e');
    }
  }

  Widget _buildRequestCard(DocumentSnapshot request, int index) {
    final data = request.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final statusIcon = _getStatusIcon(status);
    
    final createdAt = data['created_at'] != null 
        ? DateFormat('yyyy/MM/dd - HH:mm').format(data['created_at'].toDate())
        : 'غير محدد';

    final isCompleted = status == 'completed';
    final isRated = data['is_rated'] ?? false;
    final userRating = data['user_rating'] ?? 0;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                // رأس البطاقة
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['service_type'] ?? 'خدمة غير محددة',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // عرض النجوم إذا كان مكتملاً وتم التقييم
                      if (isCompleted && isRated)
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              userRating.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteRequest(request.id),
                        tooltip: 'حذف الطلب',
                      ),
                    ],
                  ),
                ),
                
                // محتوى البطاقة
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // معلومات المزود
                      if (data['provider_name'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  "مزود الخدمة:",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['provider_name'] ?? '-',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      
                      // الملاحظات
                      if (data['notes'] != null && data['notes'].toString().isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "الملاحظات:",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['notes'] ?? '-',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      
                      // الموقع
                      if (data['location'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "الموقع:",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${data['location']['latitude']?.toStringAsFixed(4) ?? '0'}, ${data['location']['longitude']?.toStringAsFixed(4) ?? '0'}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      
                      // التاريخ
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            createdAt,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // زر التقييم للطلبات المكتملة
                if (isCompleted && !isRated)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "كيف كانت تجربتك مع مزود الخدمة؟",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showRatingDialog(request),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.star, size: 18),
                          label: const Text("تقييم الخدمة"),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0: // الرئيسية
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeMapScreen()),
        );
        break;
      case 1: // طلباتي (الصفحة الحالية)
        // نحن بالفعل في هذه الصفحة
        break;
      case 2: // السجل
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (_) => HistoryPage()),
        // );
        break;
      case 3: // الإعدادات
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (_) => SettingsPage()),
        // );
        break;
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'طلباتي',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'السجل',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                "يجب تسجيل الدخول لرؤية الطلبات",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    }

    Query query = FirebaseFirestore.instance
        .collection('requests')
        .where('user_id', isEqualTo: user.uid);

    if (_filterStatus != null) {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    query = query.orderBy(_sortBy, descending: _descending);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "طلباتي",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // زر الفلترة
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.blue),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "فلترة الطلبات",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...['all', 'pending', 'accepted', 'rejected', 'completed'].map((status) {
                        return ListTile(
                          leading: Icon(
                            _getStatusIcon(status),
                            color: status == 'all' ? Colors.blue : _getStatusColor(status),
                          ),
                          title: Text(
                            status == 'all' ? 'كل الطلبات' : _getStatusText(status),
                            style: TextStyle(
                              fontWeight: _filterStatus == status || 
                                        (status == 'all' && _filterStatus == null) 
                                  ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: _filterStatus == status || 
                                  (status == 'all' && _filterStatus == null) 
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () {
                            setState(() {
                              _filterStatus = status == 'all' ? null : status;
                            });
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
            tooltip: 'فلترة الطلبات',
          ),
          
          // زر الترتيب
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.blue),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "ترتيب الطلبات",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...[
                        {'value': 'date_desc', 'text': 'الأحدث أولاً'},
                        {'value': 'date_asc', 'text': 'الأقدم أولاً'},
                        {'value': 'status', 'text': 'حسب الحالة'},
                      ].map((option) {
                        return ListTile(
                          leading: const Icon(Icons.sort_by_alpha, color: Colors.blue),
                          title: Text(option['text']!),
                          trailing: (_sortBy == 'created_at' && 
                                   ((option['value'] == 'date_desc' && _descending) ||
                                    (option['value'] == 'date_asc' && !_descending))) ||
                                  (_sortBy == 'status' && option['value'] == 'status')
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () {
                            setState(() {
                              if (option['value'] == 'date_desc') {
                                _sortBy = "created_at";
                                _descending = true;
                              } else if (option['value'] == 'date_asc') {
                                _sortBy = "created_at";
                                _descending = false;
                              } else if (option['value'] == 'status') {
                                _sortBy = "status";
                                _descending = false;
                              }
                            });
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
            tooltip: 'ترتيب الطلبات',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    "لا توجد لديك طلبات بعد",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _filterStatus != null ? "جرب تغيير الفلتر" : "ابدأ بإنشاء طلب جديد",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) => _buildRequestCard(requests[index], index),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}