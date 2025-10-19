import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TrackingScreen extends StatefulWidget {
  final String requestId;
  final String? userRole;
  const TrackingScreen({
    super.key, 
    required this.requestId,
    this.userRole
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  LatLng? _userLocation;
  LatLng? _requestLocation;
  Map<String, dynamic>? _requestData;
  Map<String, dynamic>? _providerData;
  bool _isLoading = true;
  String _userType = 'provider';
  String _userName = '';
  int _selectedMapProvider = 0;
  bool _isFullScreen = false;
  bool _showMapOptions = false; // لعرض/إخفاء خيارات الخرائط
  
  final MapController _mapController = MapController();

  // قائمة موسعة بمزودي الخرائط
  final List<MapProvider> _mapProviders = [
    MapProvider(
      name: 'OpenStreetMap',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors',
      subdomains: ['a', 'b', 'c'],
      icon: Icons.map,
      color: Colors.blue,
    ),
    MapProvider(
      name: 'خرائط جوجل',
      urlTemplate: 'http://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
      attribution: '© Google Maps',
      subdomains: [],
      icon: Icons.map_outlined,
      color: Colors.green,
    ),
    MapProvider(
      name: 'جوجل ساتلايت',
      urlTemplate: 'http://mt0.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
      attribution: '© Google Satellite',
      subdomains: [],
      icon: Icons.satellite,
      color: Colors.teal,
    ),
    MapProvider(
      name: 'خرائط طبوغرافية',
      urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      attribution: '© OpenTopoMap',
      subdomains: ['a', 'b', 'c'],
      icon: Icons.terrain,
      color: Colors.brown,
    ),
    MapProvider(
      name: 'خرائط التضاريس',
      urlTemplate: 'https://tile.memomaps.de/tilegen/{z}/{x}/{y}.png',
      attribution: '© MemoMaps',
      subdomains: [],
      icon: Icons.landscape,
      color: Colors.orange,
    ),
    MapProvider(
      name: 'خرائط الدراجات',
      urlTemplate: 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
      attribution: '© CyclOSM',
      subdomains: ['a', 'b', 'c'],
      icon: Icons.directions_bike,
      color: Colors.purple,
    ),
    MapProvider(
      name: 'الوضع الفاتح',
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
      attribution: '© CartoDB',
      subdomains: ['a', 'b', 'c'],
      icon: Icons.light_mode,
      color: Colors.grey,
    ),
    MapProvider(
      name: 'الوضع الداكن',
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      attribution: '© CartoDB',
      subdomains: ['a', 'b', 'c'],
      icon: Icons.dark_mode,
      color: Colors.grey[800]!,
    ),
    MapProvider(
      name: 'خرائط النقل',
      urlTemplate: 'https://{s}.tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=',
      attribution: '© Thunderforest',
      subdomains: ['a', 'b', 'c'],
      icon: Icons.directions_bus,
      color: Colors.deepOrange,
    ),
    MapProvider(
      name: 'الخريطة الملونة',
      urlTemplate: 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png',
      attribution: '© Stadia Maps',
      subdomains: [],
      icon: Icons.color_lens,
      color: Colors.pink,
    ),
    MapProvider(
      name: 'الخريطة البسيطة',
      urlTemplate: 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png',
      attribution: '© Stadia Maps',
      subdomains: [],
      icon: Icons.trip_origin,
      color: Colors.blueGrey,
    ),
    MapProvider(
      name: 'الخريطة المائية',
      urlTemplate: 'https://tile.openstreetmap.bzh/br/{z}/{x}/{y}.png',
      attribution: '© OSM Brittany',
      subdomains: [],
      icon: Icons.water,
      color: Colors.lightBlue,
    ),
  ];

  Future<void> _getLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists && (userDoc.data()?['role'] == 'admin')) {
          _userType = 'admin';
          _userName = 'المشرف';
        } else {
          _userType = 'provider';
          final providerDoc = await FirebaseFirestore.instance
              .collection('providers')
              .doc(user.uid)
              .get();
              
          if (providerDoc.exists) {
            _providerData = providerDoc.data();
            _userName = _providerData?['company_name'] ?? 'مزود الخدمة';
          }
        }
      }

      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId)
          .get();
          
      final requestData = requestDoc.data();

      if (requestData == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _requestData = requestData;
      });

      final loc = requestData['location'];
      if (loc != null) {
        if (loc is GeoPoint) {
          _requestLocation = LatLng(loc.latitude, loc.longitude);
        } else if (loc is Map) {
          _requestLocation = LatLng(
            (loc['latitude'] as num).toDouble(), 
            (loc['longitude'] as num).toDouble()
          );
        }
      }

      if (_userType == 'admin') {
        Position position = await Geolocator.getCurrentPosition();
        _userLocation = LatLng(position.latitude, position.longitude);
      } else {
        if (_providerData?['location'] != null && _providerData?['location'] is GeoPoint) {
          final providerLoc = _providerData!['location'] as GeoPoint;
          _userLocation = LatLng(providerLoc.latitude, providerLoc.longitude);
        } else {
          Position position = await Geolocator.getCurrentPosition();
          _userLocation = LatLng(position.latitude, position.longitude);
        }
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print('خطأ في جلب البيانات: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, _mapController.zoom);
    }
  }

  void _centerOnRequest() {
    if (_requestLocation != null) {
      _mapController.move(_requestLocation!, _mapController.zoom);
    }
  }

  void _centerOnBoth() {
    if (_userLocation != null && _requestLocation != null) {
      final bounds = LatLngBounds(_userLocation!, _requestLocation!);
      _mapController.fitBounds(
        bounds,
        options: FitBoundsOptions(
          padding: const EdgeInsets.all(50.0),
        ),
      );
    } else if (_userLocation != null) {
      _centerOnUser();
    } else if (_requestLocation != null) {
      _centerOnRequest();
    }
  }

  void _zoomIn() {
    _mapController.move(_mapController.center, _mapController.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.center, _mapController.zoom - 1);
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  void _toggleMapOptions() {
    setState(() {
      _showMapOptions = !_showMapOptions;
    });
  }

  // بناء واجهة اختيار الخرائط
  Widget _buildMapOptionsPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      right: _showMapOptions ? 0 : -300,
      top: 0,
      bottom: 0,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // رأس لوحة الخيارات
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'أنواع الخرائط',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _toggleMapOptions,
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
            ),
            
            // قائمة الخرائط
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _mapProviders.length,
                itemBuilder: (context, index) {
                  final provider = _mapProviders[index];
                  final isSelected = index == _selectedMapProvider;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isSelected ? provider.color.withOpacity(0.1) : Colors.white,
                    elevation: isSelected ? 4 : 1,
                    child: ListTile(
                      leading: Icon(
                        provider.icon,
                        color: provider.color,
                      ),
                      title: Text(
                        provider.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? provider.color : Colors.black,
                        ),
                      ),
                      trailing: isSelected 
                          ? Icon(Icons.check_circle, color: provider.color)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedMapProvider = index;
                        });
                        _toggleMapOptions();
                      },
                    ),
                  );
                },
              ),
            ),
            
            // معلومات الخريطة الحالية
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الخريطة الحالية:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _mapProviders[_selectedMapProvider].icon,
                        color: _mapProviders[_selectedMapProvider].color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mapProviders[_selectedMapProvider].name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _mapProviders[_selectedMapProvider].color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء واجهة ملء الشاشة
  Widget _buildFullScreenMap() {
    return Stack(
      children: [
        _buildMapContent(),
        
        // زر الخروج من وضع ملء الشاشة
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: FloatingActionButton.small(
            heroTag: 'exit_fullscreen',
            onPressed: _toggleFullScreen,
            tooltip: 'الخروج من وضع ملء الشاشة',
            backgroundColor: Colors.red,
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ),

        // زر تغيير الخريطة
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'change_map_full',
            onPressed: _toggleMapOptions,
            tooltip: 'تغيير نوع الخريطة',
            backgroundColor: Colors.blue,
            child: const Icon(Icons.layers, color: Colors.white),
          ),
        ),

        // أزرار التحكم في الخريطة
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              // زر التمركز على كلا الموقعين
              FloatingActionButton.small(
                heroTag: 'center_both_full',
                onPressed: _centerOnBoth,
                tooltip: 'التمركز على كلا الموقعين',
                child: const Icon(Icons.center_focus_strong),
              ),
              const SizedBox(height: 8),
              
              // زر الزوم داخل
              FloatingActionButton.small(
                heroTag: 'zoom_in_full',
                onPressed: _zoomIn,
                tooltip: 'تكبير',
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              
              // زر الزوم خارج
              FloatingActionButton.small(
                heroTag: 'zoom_out_full',
                onPressed: _zoomOut,
                tooltip: 'تصغير',
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),

        // أزرار التمركز
        if (_userLocation != null && _requestLocation != null)
          Positioned(
            left: 16,
            bottom: 16,
            child: Column(
              children: [
                // زر التمركز على المستخدم
                FloatingActionButton.small(
                  heroTag: 'center_user_full',
                  onPressed: _centerOnUser,
                  tooltip: 'التمركز على موقعك',
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.person_pin_circle),
                ),
                const SizedBox(height: 8),
                
                // زر التمركز على الطلب
                FloatingActionButton.small(
                  heroTag: 'center_request_full',
                  onPressed: _centerOnRequest,
                  tooltip: 'التمركز على موقع الطلب',
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.location_on),
                ),
              ],
            ),
          ),

        // معلومات مختصرة في الأعلى
        if (_requestData != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(_requestData?['status']),
                      color: _getStatusColor(_requestData?['status']),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _requestData?['service_type'] ?? 'خدمة غير محددة',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _getStatusText(_requestData?['status']),
                            style: TextStyle(
                              color: _getStatusColor(_requestData?['status']),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // عرض نوع الخريطة الحالية
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _mapProviders[_selectedMapProvider].color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _mapProviders[_selectedMapProvider].color,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _mapProviders[_selectedMapProvider].icon,
                            size: 16,
                            color: _mapProviders[_selectedMapProvider].color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _mapProviders[_selectedMapProvider].name,
                            style: TextStyle(
                              fontSize: 12,
                              color: _mapProviders[_selectedMapProvider].color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // لوحة خيارات الخرائط
        _buildMapOptionsPanel(),
      ],
    );
  }

  // بناء محتوى الخريطة الأساسي
  Widget _buildMapContent() {
    final centerPoint = _userLocation ?? _requestLocation ??  LatLng(24.7136, 46.6753);
    final currentProvider = _mapProviders[_selectedMapProvider];
    
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: centerPoint,
        zoom: 13,
        minZoom: 3,
        maxZoom: 18,
        interactiveFlags: InteractiveFlag.all,
      ),
      children: [
        TileLayer(
          urlTemplate: currentProvider.urlTemplate,
          userAgentPackageName: 'com.example.app',
          subdomains: currentProvider.subdomains,
        ),
        
        if (_requestLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _requestLocation!,
                width: 100,
                height: 100,
                builder: (_) => Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'موقع الطلب',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 100,
                height: 100,
                builder: (_) => Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _userType == 'admin' ? Colors.purple : Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        _userType == 'admin' ? Icons.admin_panel_settings : Icons.directions_car,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _userType == 'admin' ? 'أنت (المشرف)' : 'موقعك',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _userType == 'admin' ? Colors.purple : Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        
        if (_userType == 'provider' && _userLocation != null && _requestLocation != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [_userLocation!, _requestLocation!],
                color: Colors.blue,
                strokeWidth: 4,
              ),
            ],
          ),

        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              currentProvider.attribution,
              onTap: () => _showMapProviderInfo(currentProvider),
            ),
          ],
        ),
      ],
    );
  }

  // بناء واجهة الأدمن العادية
  Widget _buildAdminView() {
    return Stack(
      children: [
        Column(
          children: [
            // معلومات الطلب للمشرف
            Card(
              margin: const EdgeInsets.all(12),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.purple[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'معلومات الطلب - لوحة التحكم',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.purple,
                          ),
                        ),
                        const Spacer(),
                        // زر تغيير الخريطة
                        IconButton(
                          icon: const Icon(Icons.layers),
                          onPressed: _toggleMapOptions,
                          tooltip: 'تغيير نوع الخريطة',
                        ),
                        // زر وضع ملء الشاشة
                        IconButton(
                          icon: const Icon(Icons.fullscreen),
                          onPressed: _toggleFullScreen,
                          tooltip: 'وضع ملء الشاشة',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('الخدمة', _requestData?['service_type'] ?? 'غير محدد', Icons.build),
                    _buildInfoRow('الحالة', _getStatusText(_requestData?['status']), _getStatusIcon(_requestData?['status'])),
                    _buildInfoRow('ملاحظات', _requestData?['notes'] ?? 'لا توجد', Icons.note),
                    if (_requestData?['provider_name'] != null)
                      _buildInfoRow('مزود الخدمة', _requestData?['provider_name'], Icons.person),
                    if (_requestData?['user_id'] != null)
                      _buildInfoRow('معرف المستخدم', _requestData?['user_id'], Icons.code),
                    if (_requestData?['created_at'] != null)
                      _buildInfoRow(
                        'وقت الإنشاء', 
                        DateFormat('yyyy/MM/dd - HH:mm').format(_requestData!['created_at'].toDate()), 
                        Icons.access_time
                      ),
                  ],
                ),
              ),
            ),
            
            // الخريطة
            Expanded(
              child: Stack(
                children: [
                  _buildMapContent(),
                  
                  // أزرار التحكم في الخريطة
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      children: [
                        // زر تغيير الخريطة
                        FloatingActionButton.small(
                          heroTag: 'change_map_admin',
                          onPressed: _toggleMapOptions,
                          tooltip: 'تغيير نوع الخريطة',
                          child: const Icon(Icons.layers),
                        ),
                        const SizedBox(height: 8),
                        
                        // زر وضع ملء الشاشة
                        FloatingActionButton.small(
                          heroTag: 'fullscreen_admin',
                          onPressed: _toggleFullScreen,
                          tooltip: 'وضع ملء الشاشة',
                          child: const Icon(Icons.fullscreen),
                        ),
                        const SizedBox(height: 8),
                        
                        // زر التمركز على كلا الموقعين
                        FloatingActionButton.small(
                          heroTag: 'center_both_admin',
                          onPressed: _centerOnBoth,
                          tooltip: 'التمركز على كلا الموقعين',
                          child: const Icon(Icons.center_focus_strong),
                        ),
                        const SizedBox(height: 8),
                        
                        // زر الزوم داخل
                        FloatingActionButton.small(
                          heroTag: 'zoom_in_admin',
                          onPressed: _zoomIn,
                          tooltip: 'تكبير',
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        
                        // زر الزوم خارج
                        FloatingActionButton.small(
                          heroTag: 'zoom_out_admin',
                          onPressed: _zoomOut,
                          tooltip: 'تصغير',
                          child: const Icon(Icons.remove),
                        ),
                      ],
                    ),
                  ),

                  // أزرار التمركز
                  if (_userLocation != null && _requestLocation != null)
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Column(
                        children: [
                          // زر التمركز على المستخدم
                          FloatingActionButton.small(
                            heroTag: 'center_user_admin',
                            onPressed: _centerOnUser,
                            tooltip: 'التمركز على موقعك',
                            backgroundColor: Colors.green,
                            child: const Icon(Icons.person_pin_circle),
                          ),
                          const SizedBox(height: 8),
                          
                          // زر التمركز على الطلب
                          FloatingActionButton.small(
                            heroTag: 'center_request_admin',
                            onPressed: _centerOnRequest,
                            tooltip: 'التمركز على موقع الطلب',
                            backgroundColor: Colors.red,
                            child: const Icon(Icons.location_on),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        // لوحة خيارات الخرائط
        _buildMapOptionsPanel(),
      ],
    );
  }

  // بناء واجهة المزود العادية
  Widget _buildProviderView() {
    return Stack(
      children: [
        Column(
          children: [
            // معلومات الطلب للمزود
            Card(
              margin: const EdgeInsets.all(12),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_car, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'تفاصيل الطلب - $_userName',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue,
                          ),
                        ),
                        const Spacer(),
                        // زر تغيير الخريطة
                        IconButton(
                          icon: const Icon(Icons.layers),
                          onPressed: _toggleMapOptions,
                          tooltip: 'تغيير نوع الخريطة',
                        ),
                        // زر وضع ملء الشاشة
                        IconButton(
                          icon: const Icon(Icons.fullscreen),
                          onPressed: _toggleFullScreen,
                          tooltip: 'وضع ملء الشاشة',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('الخدمة', _requestData?['service_type'] ?? 'غير محدد', Icons.build),
                    _buildInfoRow('الحالة', _getStatusText(_requestData?['status']), _getStatusIcon(_requestData?['status'])),
                    _buildInfoRow('ملاحظات', _requestData?['notes'] ?? 'لا توجد', Icons.note),
                    if (_requestData?['created_at'] != null)
                      _buildInfoRow(
                        'وقت الإنشاء', 
                        DateFormat('yyyy/MM/dd - HH:mm').format(_requestData!['created_at'].toDate()), 
                        Icons.access_time
                      ),
                    if (_providerData != null) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const Text(
                        'معلومات المزود:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      _buildInfoRow('اسم الشركة', _providerData?['company_name'] ?? 'غير محدد', Icons.business),
                      _buildInfoRow('الهاتف', _providerData?['phone']?.toString() ?? 'غير محدد', Icons.phone),
                    ],
                  ],
                ),
              ),
            ),

            // الخريطة
            Expanded(
              child: Stack(
                children: [
                  _buildMapContent(),
                  
                  // أزرار التحكم في الخريطة
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      children: [
                        // زر تغيير الخريطة
                        FloatingActionButton.small(
                          heroTag: 'change_map_provider',
                          onPressed: _toggleMapOptions,
                          tooltip: 'تغيير نوع الخريطة',
                          child: const Icon(Icons.layers),
                        ),
                        const SizedBox(height: 8),
                        
                        // زر وضع ملء الشاشة
                        FloatingActionButton.small(
                          heroTag: 'fullscreen_provider',
                          onPressed: _toggleFullScreen,
                          tooltip: 'وضع ملء الشاشة',
                          child: const Icon(Icons.fullscreen),
                        ),
                        const SizedBox(height: 8),
                        
                        // زر التمركز على كلا الموقعين
                        FloatingActionButton.small(
                          heroTag: 'center_both_provider',
                          onPressed: _centerOnBoth,
                          tooltip: 'التمركز على كلا الموقعين',
                          child: const Icon(Icons.center_focus_strong),
                        ),
                        const SizedBox(height: 8),
                        
                        // زر الزوم داخل
                        FloatingActionButton.small(
                          heroTag: 'zoom_in_provider',
                          onPressed: _zoomIn,
                          tooltip: 'تكبير',
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        
                        // زر الزوم خارج
                        FloatingActionButton.small(
                          heroTag: 'zoom_out_provider',
                          onPressed: _zoomOut,
                          tooltip: 'تصغير',
                          child: const Icon(Icons.remove),
                        ),
                      ],
                    ),
                  ),

                  // أزرار التمركز
                  if (_userLocation != null && _requestLocation != null)
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Column(
                        children: [
                          // زر التمركز على المستخدم
                          FloatingActionButton.small(
                            heroTag: 'center_user_provider',
                            onPressed: _centerOnUser,
                            tooltip: 'التمركز على موقعك',
                            backgroundColor: Colors.green,
                            child: const Icon(Icons.person_pin_circle),
                          ),
                          const SizedBox(height: 8),
                          
                          // زر التمركز على الطلب
                          FloatingActionButton.small(
                            heroTag: 'center_request_provider',
                            onPressed: _centerOnRequest,
                            tooltip: 'التمركز على موقع الطلب',
                            backgroundColor: Colors.red,
                            child: const Icon(Icons.location_on),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        // لوحة خيارات الخرائط
        _buildMapOptionsPanel(),
      ],
    );
  }

  Widget _buildInfoRow(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'accepted': return 'مقبول';
      case 'rejected': return 'مرفوض';
      case 'completed': return 'مكتمل';
      default: return 'غير معروف';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'pending': return Icons.access_time;
      case 'accepted': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      case 'completed': return Icons.done_all;
      default: return Icons.help;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.red;
      case 'completed': return Colors.blue;
      default: return Colors.grey;
    }
  }

  void _showMapProviderInfo(MapProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('معلومات الخريطة - ${provider.name}'),
        content: Text('مزود الخرائط: ${provider.name}\nالترخيص: ${provider.attribution}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _getLocations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen 
          ? null
          : AppBar(
              title: Text(_userType == 'admin' ? "تتبع الطلب - الإدارة" : "تتبع الطلب"),
              backgroundColor: _userType == 'admin' ? Colors.purple : Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                // زر تغيير الخريطة في AppBar
                IconButton(
                  icon: const Icon(Icons.layers),
                  onPressed: _toggleMapOptions,
                  tooltip: 'تغيير نوع الخريطة',
                ),
                if (_userType == 'admin')
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _getLocations,
                    tooltip: 'تحديث البيانات',
                  ),
              ],
            ),
      body: _isLoading 
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري تحميل بيانات التتبع...'),
                ],
              ),
            )
          : _isFullScreen 
              ? _buildFullScreenMap() 
              : _userType == 'admin' 
                  ? _buildAdminView() 
                  : _buildProviderView(),
    );
  }
}

class MapProvider {
  final String name;
  final String urlTemplate;
  final String attribution;
  final List<String> subdomains;
  final IconData icon;
  final Color color;

  MapProvider({
    required this.name,
    required this.urlTemplate,
    required this.attribution,
    required this.icon,
    required this.color,
    List<String>? subdomains,
  }) : subdomains = subdomains ?? [];
}