import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:untitled8/reqestiaton.dart';
import 'home.dart';
import 'admin/admin_screen.dart';
import 'provider/provider_dashboard.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final Function(bool)? onThemeChanged;
  final Function(double)? onFontSizeChanged;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.onThemeChanged,
    this.onFontSizeChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // البحث في جميع collections
      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      final providerQuerySnapshot = await FirebaseFirestore.instance
          .collection('providers')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      // تسجيل الدخول في Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      // تحديد نوع المستخدم والتوجيه المناسب
      if (userQuerySnapshot.docs.isNotEmpty) {
        // مستخدم عادي أو أدمن
        await _handleUserLogin(userQuerySnapshot.docs.first);
      } 
      else if (providerQuerySnapshot.docs.isNotEmpty) {
        // مزود خدمة
        await _handleProviderLogin(providerQuerySnapshot.docs.first);
      }
      else {
        // المستخدم غير موجود في أي collection
        _handleUserNotFound();
        await FirebaseAuth.instance.signOut(); // إضافة await هنا
      }

      widget.onLoginSuccess?.call();

    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUserLogin(DocumentSnapshot userDoc) async {
    final userData = userDoc.data() as Map<String, dynamic>;
    final role = userData['role'] ?? 'user';
    
    print('✅ تم التعرف على مستخدم عادي - الدور: $role');
    
    _redirectBasedOnRole(role, userData);
  }

  Future<void> _handleProviderLogin(DocumentSnapshot providerDoc) async {
    final providerData = providerDoc.data() as Map<String, dynamic>;
    final status = providerData['status'] ?? 'pending';
    final role = providerData['role'] ?? 'provider';
    
    print('✅ تم التعرف على مزود خدمة - الحالة: $status');
    
    if (status == 'approved') {
      _redirectBasedOnRole(role, providerData);
    } else {
      _handlePendingProvider(status);
      // تسجيل الخروج إذا كان الحساب غير مفعل
      await FirebaseAuth.instance.signOut(); // إضافة await هنا
    }
  }

  void _handleUserNotFound() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لا يوجد حساب بهذا البريد الإلكتروني.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handlePendingProvider(String status) {
    String message = status == 'pending' 
        ? 'حسابك قيد المراجعة من قبل الإدارة'
        : 'حسابك مرفوض من قبل الإدارة';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message = '';
    if (e.code == 'wrong-password') {
      message = 'كلمة المرور غير صحيحة.';
    } else if (e.code == 'user-not-found') {
      message = 'لا يوجد حساب بهذا البريد الإلكتروني.';
    } else if (e.code == 'invalid-email') {
      message = 'البريد الإلكتروني غير صالح.';
    } else if (e.code == 'network-request-failed') {
      message = 'خطأ في الاتصال بالإنترنت.';
    } else {
      message = 'حدث خطأ: ${e.message}';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _redirectBasedOnRole(String role, Map<String, dynamic> userData) {
    switch (role) {
      case 'admin':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
        break;
      
      case 'provider':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProviderDashboard()),
        );
        break;
      
      case 'user':
      default:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeMapScreen(
              onThemeChanged: widget.onThemeChanged,
              onFontSizeChanged: widget.onFontSizeChanged,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // الشعار مع الظل والأنيميشن
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: PhysicalModel(
                      color: Colors.transparent,
                      elevation: 8.0,
                      shadowColor: colorScheme.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            "assets/logo.png",
                            height: 140,
                            width: 140,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 140,
                                width: 140,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.car_repair,
                                  size: 60,
                                  color: colorScheme.primary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // العنوان مع الأنيميشن
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          "مرحباً بك في تطبيق فزع",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            shadows: [
                              Shadow(
                                blurRadius: 2,
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "سجل دخولك للمتابعة",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // حقل البريد الإلكتروني مع الأنيميشن
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      child: TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "البريد الإلكتروني",
                          prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.primary, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'الرجاء إدخال البريد الإلكتروني';
                          }
                          if (!v.contains('@')) {
                            return 'البريد الإلكتروني غير صالح';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // حقل كلمة المرور مع الأنيميشن
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      child: TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: "كلمة المرور",
                          prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: colorScheme.primary,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.primary, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'الرجاء إدخال كلمة المرور';
                          }
                          if (v.length < 6) {
                            return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // زر تسجيل الدخول مع الأنيميشن
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "تسجيل الدخول",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // رابط التسجيل الجديد مع الأنيميشن
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 700),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("ليس لديك حساب؟"),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                            ),
                            child: Text(
                              "إنشاء حساب جديد",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // رابط تسجيل مزود الخدمة
                const SizedBox(height: 20),
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: TextButton(
                      onPressed: () {
                        // هنا يمكنك إضافة التنقل لصفحة تسجيل مزود الخدمة
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(builder: (_) => const ProviderRegistrationScreen()),
                        // );
                      },
                      child: Text(
                        "تسجيل كمزود خدمة",
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}