import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../admin/admin_tracking_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../login_screen.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String _selectedService = 'جميع الخدمات';
  List<String> _services = ['جميع الخدمات', 'صيانة ميدانية', 'تزويد الوقود', 'سطحة', 'غسيل السيارات', 'خدمات متعددة', 'قطع غيار'];
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  GeoPoint? _providerLocation;
  bool _isLoadingLocation = true;
  double _selectedDistance = 10.0;
  final List<double> _distanceOptions = [5.0, 10.0, 20.0, 50.0, 100.0];
  
  // بيانات المزود
  Map<String, dynamic> _providerData = {};
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _loadProviderData();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // طلب إذن الموقع
  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (e) {
      print('خطأ في طلب إذن الموقع: $e');
    }
  }

  // جلب بيانات المزود كاملة
  Future<void> _loadProviderData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(user.uid)
          .get();

      if (providerDoc.exists) {
        final data = providerDoc.data() as Map<String, dynamic>;
        setState(() {
          _providerData = data;
          _providerLocation = data['location'] is GeoPoint ? data['location'] as GeoPoint : const GeoPoint(24.7136, 46.6753);
          _isLoadingLocation = false;
          _isLoadingProfile = false;
        });
      } else {
        // إذا لم يكن المزود موجوداً في collection providers، أنشئ بيانات افتراضية
        setState(() {
          _providerData = {
            'email': user.email,
            'company_name': 'مزود جديد',
            'phone': 'غير محدد',
            'services': 'خدمات متعددة',
            'status': 'approved',
            'completed_requests': 0,
            'rating': 0.0,
          };
          _providerLocation = const GeoPoint(24.7136, 46.6753);
          _isLoadingLocation = false;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('خطأ في جلب بيانات المزود: $e');
      setState(() {
        _providerLocation = const GeoPoint(24.7136, 46.6753);
        _isLoadingLocation = false;
        _isLoadingProfile = false;
      });
    }
  }

  // حساب المسافة بين نقطتين (بالكيلومتر)
  double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    const double earthRadius = 6371;

    double lat1 = point1.latitude * (pi / 180);
    double lon1 = point1.longitude * (pi / 180);
    double lat2 = point2.latitude * (pi / 180);
    double lon2 = point2.longitude * (pi / 180);

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // تصفية الطلبات القريبة فقط
  List<DocumentSnapshot> _filterNearbyRequests(List<DocumentSnapshot> requests, double maxDistanceKm) {
    if (_providerLocation == null) return [];

    return requests.where((request) {
      final data = request.data() as Map<String, dynamic>;
      
      // إذا كان الطلب مرفوضاً أو مكتملاً، لا نعرضه إلا إذا كان مقبولاً من قبل المزود الحالي
      final status = data['status'] ?? 'pending';
      final providerId = data['provider_id'];
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      // إذا كان الطلب مرفوضاً أو مكتملاً ولم يكن مقبولاً من قبل المزود الحالي، لا نعرضه
      if ((status == 'rejected' || status == 'completed') && providerId != currentUserId) {
        return false;
      }
      
      if (data['location'] == null) return false;

      GeoPoint requestLocation;
      if (data['location'] is GeoPoint) {
        requestLocation = data['location'] as GeoPoint;
      } else if (data['location'] is Map) {
        final locationMap = data['location'] as Map<String, dynamic>;
        final lat = locationMap['latitude'];
        final lng = locationMap['longitude'];
        if (lat == null || lng == null) return false;
        requestLocation = GeoPoint((lat as num).toDouble(), (lng as num).toDouble());
      } else {
        return false;
      }

      final distance = _calculateDistance(_providerLocation!, requestLocation);
      return distance <= maxDistanceKm;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "pending": return Colors.orange;
      case "accepted": return Colors.green;
      case "rejected": return Colors.red;
      case "completed": return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case "pending": return "قيد الانتظار";
      case "accepted": return "مقبول";
      case "rejected": return "مرفوض";
      case "completed": return "مكتمل";
      default: return "غير معروف";
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case "pending": return Icons.access_time;
      case "accepted": return Icons.check_circle;
      case "rejected": return Icons.cancel;
      case "completed": return Icons.done_all;
      default: return Icons.help;
    }
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .update({
            'status': newStatus,
            'provider_id': user?.uid,
            'provider_email': _providerData['email'],
            'provider_name': _providerData['company_name'],
            'updated_at': FieldValue.serverTimestamp(),
          });

      // إذا كان القبول، زيادة عدد الطلبات المكتملة
      if (newStatus == 'accepted' || newStatus == 'completed') {
        await _incrementCompletedRequests();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم ${_getStatusText(newStatus)} الطلب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحديث الطلب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // زيادة عدد الطلبات المكتملة
  Future<void> _incrementCompletedRequests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('providers')
          .doc(user.uid)
          .set({
            'completed_requests': FieldValue.increment(1),
          }, SetOptions(merge: true));

      // تحديث البيانات المحلية
      setState(() {
        _providerData['completed_requests'] = (_providerData['completed_requests'] ?? 0) + 1;
      });
    } catch (e) {
      print('خطأ في تحديث عدد الطلبات المكتملة: $e');
    }
  }

  Widget _buildStatsCard(String title, String value, Color color, IconData icon) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLocation(dynamic location) {
    if (location == null) return 'غير محدد';
    
    try {
      if (location is GeoPoint) {
        return '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
      } else if (location is Map) {
        final locationMap = location as Map<String, dynamic>;
        final lat = locationMap['latitude'];
        final lng = locationMap['longitude'];
        return '${lat?.toStringAsFixed(4) ?? '0'}, ${lng?.toStringAsFixed(4) ?? '0'}';
      } else {
        return 'تنسيق غير معروف';
      }
    } catch (e) {
      return 'خطأ في الموقع';
    }
  }

  Widget _buildRequestItem(DocumentSnapshot request, double distance) {
    final data = request.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final createdAt = data['created_at'] != null 
        ? DateFormat('MM/dd HH:mm').format(data['created_at'].toDate())
        : 'غير محدد';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMyRequest = data['provider_id'] == currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Icon(
          _getStatusIcon(status),
          color: statusColor,
        ),
        title: Row(
          children: [
            Text(data['service_type'] ?? 'خدمة غير محددة'),
            if (isMyRequest)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text(
                  'طلبي',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الملاحظات: ${data['notes'] ?? '-'}'),
            Text('التاريخ: $createdAt'),
            Text('المسافة: ${distance.toStringAsFixed(1)} كم'),
            if (_providerLocation != null)
              Text(
                'الموقع: ${_formatLocation(data['location'])}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (isMyRequest && status != 'pending')
              Text(
                'مقبول من قبلك',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'pending')
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => _updateRequestStatus(request.id, 'accepted'),
                tooltip: 'قبول الطلب',
              ),
            if (status == 'pending')
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _updateRequestStatus(request.id, 'rejected'),
                tooltip: 'رفض الطلب',
              ),
            if (status == 'accepted' && isMyRequest)
              IconButton(
                icon: const Icon(Icons.map, color: Colors.blue),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrackingScreen(requestId: request.id),
                    ),
                  );
                },
                tooltip: 'تتبع على الخريطة',
              ),
            if (status == 'accepted' && isMyRequest)
              IconButton(
                icon: const Icon(Icons.done_all, color: Colors.blue),
                onPressed: () => _updateRequestStatus(request.id, 'completed'),
                tooltip: 'إكمال الطلب',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProviderLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // جلب الموقع الحالي
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _providerLocation = GeoPoint(position.latitude, position.longitude);
      });

      // تحديث أو إنشاء بيانات المزود
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(user.uid)
          .set({
            'email': user.email,
            'company_name': _providerData['company_name'] ?? 'مزود الخدمة',
            'phone': _providerData['phone'] ?? 'غير محدد',
            'services': _providerData['services'] ?? 'خدمات متعددة',
            'status': 'approved',
            'location': _providerLocation,
            'location_updated_at': FieldValue.serverTimestamp(),
            'completed_requests': _providerData['completed_requests'] ?? 0,
            'rating': _providerData['rating'] ?? 0.0,
            'created_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // تحديث البيانات المحلية
      setState(() {
        _providerData['location'] = _providerLocation;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الموقع بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('خطأ في تحديث الموقع: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحديث الموقع: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // استعلام للطلبات المعلقة والمقبولة من قبل المزود الحالي
    final user = FirebaseAuth.instance.currentUser;
    Query requestsQuery = FirebaseFirestore.instance
        .collection('requests')
        .where('status', whereIn: ['pending', 'accepted', 'completed'])
        .limit(20);

    if (_selectedService != 'جميع الخدمات') {
      requestsQuery = requestsQuery.where('service_type', isEqualTo: _selectedService);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم مزود الخدمة'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<double>(
            onSelected: (distance) {
              setState(() {
                _selectedDistance = distance;
              });
            },
            itemBuilder: (context) => _distanceOptions.map((distance) {
              return PopupMenuItem<double>(
                value: distance,
                child: Text('${distance.toInt()} كم'),
              );
            }).toList(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 20, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_selectedDistance.toInt()} كم',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          
          PopupMenuButton<String>(
            onSelected: (service) {
              setState(() {
                _selectedService = service;
              });
            },
            itemBuilder: (context) => _services.map((service) {
              return PopupMenuItem<String>(
                value: service,
                child: Text(service),
              );
            }).toList(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 20, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _selectedService.length > 10 
                        ? '${_selectedService.substring(0, 10)}...' 
                        : _selectedService,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildDashboardTab(requestsQuery) : _buildProfileTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'الطلبات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'الملف الشخصي',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(Query requestsQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: requestsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_isLoadingLocation) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تحميل الموقع...'),
              ],
            ),
          );
        }

        final allRequests = snapshot.data?.docs ?? [];
        final nearbyRequests = _filterNearbyRequests(allRequests, _selectedDistance);

        // إحصائيات
        final pendingCount = nearbyRequests.where((req) {
          final data = req.data() as Map<String, dynamic>;
          return data['status'] == 'pending';
        }).length;

        final myAcceptedCount = nearbyRequests.where((req) {
          final data = req.data() as Map<String, dynamic>;
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          return data['status'] == 'accepted' && data['provider_id'] == currentUserId;
        }).length;

        final totalCount = allRequests.length;

        return Column(
          children: [
            // معلومات المسافة والطلبات
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الطلبات القريبة',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                'ضمن ${_selectedDistance.toInt()} كم',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${nearbyRequests.length} / $totalCount',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'قريب / إجمالي',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$pendingCount',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const Text(
                                'معلقة',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '$myAcceptedCount',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                'طلباتي',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // قائمة الطلبات القريبة
            if (nearbyRequests.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "لا توجد طلبات قريبة",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "ضمن ${_selectedDistance.toInt()} كم من موقعك",
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _updateProviderLocation,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تحديث الموقع'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: nearbyRequests.length,
                  itemBuilder: (context, index) {
                    final request = nearbyRequests[index];
                    final data = request.data() as Map<String, dynamic>;
                    
                    double distance = 0;
                    if (_providerLocation != null && data['location'] != null) {
                      GeoPoint requestLocation;
                      if (data['location'] is GeoPoint) {
                        requestLocation = data['location'] as GeoPoint;
                      } else {
                        final locationMap = data['location'] as Map<String, dynamic>;
                        final lat = locationMap['latitude'];
                        final lng = locationMap['longitude'];
                        requestLocation = GeoPoint(
                          (lat as num).toDouble(), 
                          (lng as num).toDouble()
                        );
                      }
                      distance = _calculateDistance(_providerLocation!, requestLocation);
                    }

                    return _buildRequestItem(request, distance);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProfileTab() {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الملف الشخصي',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileItem('اسم الشركة', _providerData['company_name'] ?? 'غير محدد'),
                  _buildProfileItem('البريد الإلكتروني', _providerData['email'] ?? 'غير محدد'),
                  _buildProfileItem('رقم الهاتف', _providerData['phone']?.toString() ?? 'غير محدد'),
                  _buildProfileItem('العنوان', _providerData['address'] ?? 'غير محدد'),
                  _buildProfileItem('الخدمات', _providerData['services']?.toString() ?? 'غير محدد'),
                  _buildProfileItem('التقييم', '${_providerData['rating']?.toString() ?? '0'} ⭐'),
                  _buildProfileItem('الطلبات المكتملة', '${_providerData['completed_requests']?.toString() ?? '0'} طلب'),
                  if (_providerLocation != null)
                    _buildProfileItem(
                      'الموقع الحالي', 
                      '${_providerLocation!.latitude.toStringAsFixed(4)}, ${_providerLocation!.longitude.toStringAsFixed(4)}'
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: _updateProviderLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('تحديث موقعي'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$title:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}