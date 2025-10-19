// home.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'request_screen.dart';
import 'login_screen.dart';
import 'notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'requests_list.dart';
import 'setting.dart';

class HomeMapScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  final Function(double)? onFontSizeChanged;
  final Function(Locale)? onLocaleChanged;

  const HomeMapScreen({
    super.key,
    this.onThemeChanged,
    this.onFontSizeChanged,
    this.onLocaleChanged,
  });

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

bool isDarkMode = false;

class _HomeMapScreenState extends State<HomeMapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _currentDeviceLocation;
  bool _isLoadingLocation = true;
  String? _locationError;
  bool _showMap = false;

  bool _localIsDark = false;
  double _localTextScale = 1.0;
  bool _isDisposed = false;

  StreamSubscription<QuerySnapshot>? _requestsListener;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> services = [
    {'name': 'صيانة ميدانية', 'icon': '🛠️', 'color': Colors.orange},
    {'name': 'تزويد الوقود', 'icon': '⛽', 'color': Colors.green},
    {'name': 'سطحة', 'icon': '🚚', 'color': Colors.blue},
    {'name': 'غسيل السيارات', 'icon': '🧽', 'color': Colors.purple},
    {'name': 'خدمات متعددة', 'icon': '🔧', 'color': Colors.red},
    {'name': 'قطع غيار', 'icon': '🚗', 'color': Colors.teal}
  ];

  User? _currentUser;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    print("🆔 UID المستخدم الحالي: ${_currentUser?.uid}");

    // تهيئة الأنيميشن
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

    _fetchCurrentUserLocation();

    // ✅ تأخير بدء المستمع 1 ثانية
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_isDisposed) {
        _startListeningToRequests();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        setState(() {
          _localIsDark = Theme.of(context).brightness == Brightness.dark;
          _localTextScale =
              MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5);
        });
      }
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted || _isDisposed) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(onLoginSuccess: () {}),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mapController.dispose();
    _animationController.dispose();
    _requestsListener?.cancel();
    super.dispose();
  }

  // ✅ دالة جلب الموقع — مُحسّنة لتجنب setState بعد dispose بأي ثمن
  Future<void> _fetchCurrentUserLocation() async {
    if (!mounted || _isDisposed) return;

    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted || _isDisposed) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted || _isDisposed) return;
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = "تم رفض إذن الوصول للموقع.";
            _currentDeviceLocation = LatLng(24.7136, 46.6753); // الرياض
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted || _isDisposed) return;
        setState(() {
          _locationError =
              "تم رفض إذن الوصول للموقع بشكل دائم. يرجى التفعيل من الإعدادات.";
          _currentDeviceLocation = LatLng(24.7136, 46.6753);
          _isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted || _isDisposed) return;

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentDeviceLocation = newLocation;
        _isLoadingLocation = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed && _currentDeviceLocation != null) {
          try {
            _mapController.move(_currentDeviceLocation!, 15.0);
          } catch (e) {
            print("تجاهل خطأ أثناء تحريك الخريطة: $e");
          }
        }
      });
    } catch (e) {
      if (!mounted || _isDisposed) return;

      setState(() {
        _locationError = "حدث خطأ أثناء جلب الموقع: ${e.toString()}";
        _currentDeviceLocation = LatLng(24.7136, 46.6753);
        _isLoadingLocation = false;
      });
      print("خطأ في جلب الموقع: $e");
    }
  }

  void _startListeningToRequests() {
    if (_currentUser == null) {
      print("❌ لا يوجد مستخدم مسجل دخوله — لن يتم الاستماع للطلبات.");
      return;
    }

    print("✅ بدء الاستماع لطلبات المستخدم: ${_currentUser!.uid}");

    final requestsQuery = FirebaseFirestore.instance
        .collection('requests')
        .where('user_id', isEqualTo: _currentUser!.uid);

    _requestsListener = requestsQuery.snapshots().listen((snapshot) {
      print(
          "📡 تم استقبال تحديث في الطلبات — عدد التغييرات: ${snapshot.docChanges.length}");

      for (final docChange in snapshot.docChanges) {
        print(
            "📄 نوع التغيير: ${docChange.type} — المستند ID: ${docChange.doc.id}");

        // ✅ التعامل مع 'added' و 'modified'
        if (docChange.type == DocumentChangeType.added ||
            docChange.type == DocumentChangeType.modified) {
          final data = docChange.doc.data();
          if (data == null) continue;

          final newStatus = data['status'] as String?;
          print("🔄 الحالة الجديدة: $newStatus");

          if (newStatus == 'accepted') {
            print("🎉 تم قبول الطلب! سيتم عرض إشعار...");

            NotificationService.showRequestAcceptedNotification(
              serviceName: data['service_type'] as String? ?? 'خدمة غير معروفة',
            );
          }
        }
      }
    }, onError: (error) {
      print("❌ خطأ في الاستماع للطلبات: $error");
    });
  }

  Widget _buildServiceCard(Map<String, dynamic> service, int index) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: () {
            if (_currentDeviceLocation != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestScreen(
                    location: _currentDeviceLocation!,
                    serviceName: service['name']!,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_locationError ?? "جاري تحديد الموقع، يرجى الانتظار..."),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    service['color'].withOpacity(0.3),
                    service['color'].withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      service['icon'] ?? '',
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.withOpacity(0.3),
                Colors.purple.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue,
                child: Text(
                  _currentUser?.email?.substring(0, 1).toUpperCase() ?? "U",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUser?.displayName ?? "مستخدم فزع",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentUser?.email ?? "البريد الإلكتروني",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
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

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // رأس الدرور
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade700,
                    Colors.purple.shade500,
                  ],
                ),
              ),
              accountName: Text(
                _currentUser?.displayName ?? "مستخدم فزع",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                _currentUser?.email ?? "البريد الإلكتروني",
                style: const TextStyle(fontSize: 14),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _currentUser?.email?.substring(0, 1).toUpperCase() ?? "U",
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),

            // عناصر القائمة الرئيسية
            _buildDrawerItem(
              icon: Icons.person_outline,
              title: "الملف الشخصي",
              onTap: () {
                Navigator.pop(context);
                // الانتقال لصفحة الملف الشخصي
              },
            ),

            _buildDrawerItem(
              icon: Icons.list_alt_outlined,
              title: "طلباتي",
              onTap: () {
                Navigator.pop(context);
                // الانتقال لصفحة الطلبات
              },
            ),

            _buildDrawerItem(
              icon: Icons.history,
              title: "سجل الطلبات",
              onTap: () {
                Navigator.pop(context);
                // الانتقال لسجل الطلبات
              },
            ),

            _buildDrawerItem(
              icon: Icons.notifications_active_outlined,
              title: "الإشعارات",
              onTap: () {
                Navigator.pop(context);
                // الانتقال لصفحة الإشعارات
              },
            ),

            const Divider(),

            // قسم الإعدادات
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "الإعدادات",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),

            _buildDrawerItem(
              icon: Icons.dark_mode_outlined,
              title: "الوضع الليلي",
              trailing: Switch(
                value: isDarkMode,
                onChanged: (value) {
                  setState(() {
                    isDarkMode = value;
                  });
                  Navigator.pop(context);
                },
              ),
            ),

            _buildDrawerItem(
              icon: Icons.language,
              title: "اللغة",
              onTap: () {
                Navigator.pop(context);
                // تغيير اللغة
              },
            ),

            _buildDrawerItem(
              icon: Icons.help_outline,
              title: "المساعدة والدعم",
              onTap: () {
                Navigator.pop(context);
                // الانتقال لصفحة المساعدة
              },
            ),

            _buildDrawerItem(
              icon: Icons.info_outline,
              title: "عن التطبيق",
              onTap: () {
                Navigator.pop(context);
                // الانتقال لصفحة عن التطبيق
              },
            ),

            const Divider(),

            // تسجيل الخروج
            _buildDrawerItem(
              icon: Icons.logout,
              title: "تسجيل الخروج",
              color: Colors.red,
              onTap: _logout,
            ),

            // مساحة في الأسفل
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? Colors.blue,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: color ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        key: _scaffoldKey, // إضافة المفتاح هنا
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhysicalModel(
                color: Colors.transparent,
                elevation: 4.0,
                shadowColor: Colors.blue.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      "assets/logo.png",
                      height: 40,
                      width: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.car_repair, color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'فزع',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.my_location, color: Colors.blue),
              onPressed: _fetchCurrentUserLocation,
              tooltip: 'تحديث الموقع',
            ),
          ],
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.blue),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
        ),
        drawer: _buildDrawer(),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // قسم البروفايل
              _buildProfileSection(),

              // زر إظهار/إخفاء الخريطة
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showMap = !_showMap;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_showMap ? Icons.map_outlined : Icons.map),
                          const SizedBox(width: 8),
                          Text(_showMap ? 'إخفاء الخريطة' : 'إظهار الخريطة'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // الخريطة (تظهر فقط عند الضغط على الزر)
              if (_showMap)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: size.height * 0.4,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _isLoadingLocation
                        ? const Center(child: CircularProgressIndicator())
                        : FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              center: _currentDeviceLocation ??
                                   LatLng(24.7136, 46.6753),
                              zoom: 13.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                subdomains: const ['a', 'b', 'c'],
                              ),
                              if (_currentDeviceLocation != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _currentDeviceLocation!,
                                      builder: (ctx) => const Icon(
                                        Icons.location_on,
                                        size: 40,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                  ),
                ),

              if (_showMap && _locationError != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _locationError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 20),

              // عنوان الخدمات
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "الخدمات المتاحة",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // شبكة الخدمات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: size.height * 0.4,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: services.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemBuilder: (context, index) => _buildServiceCard(services[index], index),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOut,
          )),
         child: Container(
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
    onTap: (index) {
      setState(() {
        _currentIndex = index;
      });
      
      // التنقل بين الصفحات
      switch (index) {
        case 0: // الرئيسية
          // نحن بالفعل في الصفحة الرئيسية
          break;
        case 1: // طلباتي
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserRequestsPage()),
          );
          break;
        case 2: // السجل
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserRequestsPage()),
          );
          break;
        case 3: // الإعدادات
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SettingsPage()),
          );
          break;
      }
    },
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
),        ),
      ),
    );
  }
}