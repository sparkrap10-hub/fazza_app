 /** return AnimatedSplashScreen(
        splash: Center(child: Image.asset('assets/fazza.json')),
        nextScreen: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return InitialScreen(key: ValueKey(snapshot.data!.uid));
          }
          return LoginScreen(onLoginSuccess: () {
            setState(() {});
          });
        },
      ),); **/