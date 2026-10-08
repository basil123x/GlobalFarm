import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  
  Future<User?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      // 2. جيب الـ credentials
      final GoogleSignInAuthentication googleAuth = 
          googleUser.authentication;

      // 3. ربط مع Firebase
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 4. تسجيل في Firebase
      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);
      
      final User? user = userCredential.user;
      
      // 5. اطبع البيانات
      print('✅ Name: ${user?.displayName}');
      print('✅ Email: ${user?.email}');
      print('✅ Photo: ${user?.photoURL}');
      print('✅ UID: ${user?.uid}');
      
      return user;
      
    } catch (e) {
      print('❌ Google Sign In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}