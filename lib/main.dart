import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Connect to local Firebase Emulators in debug mode only.
  // ADB reverse forwards these ports from the Android phone
  // to the Mac running the Firebase Emulator Suite.
  if (kDebugMode) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);

    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);

    FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
  }

  runApp(const CloudQuestApp());
}

class CloudQuestApp extends StatelessWidget {
  const CloudQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Cloud Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Text('Authentication is unavailable. Restart the app.'),
              ),
            );
          }

          if (snapshot.data == null) {
            return const AuthScreen();
          }

          return HomeScreen(user: snapshot.data!);
        },
      ),
    );
  }
}

// --------------------------------------------------
// AUTHENTICATION
// --------------------------------------------------

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _hidePassword = true;

  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      String message;

      switch (error.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Your password is too weak.';
          break;
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message = 'Invalid email or password.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your connection.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = 'Authentication failed. Please try again.';
      }

      setState(() => _errorMessage = message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _switchMode() {
    if (_isLoading) return;

    setState(() {
      _isSignUp = !_isSignUp;
      _errorMessage = null;
      _passwordController.clear();
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.cloud, size: 72, color: Colors.deepPurple),
                    const SizedBox(height: 16),
                    Text(
                      'Firebase Cloud Quest',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSignUp
                          ? 'Create an account to begin your quest.'
                          : 'Sign in to continue your quest.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Please enter your email.';
                        }

                        if (!email.contains('@') ||
                            !email.split('@').last.contains('.')) {
                          return 'Please enter a valid email.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _authenticate();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _hidePassword = !_hidePassword;
                            });
                          },
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password.';
                        }

                        if (_isSignUp && value.length < 6) {
                          return 'Use at least 6 characters.';
                        }

                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _authenticate,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _isLoading
                              ? 'Please wait...'
                              : _isSignUp
                              ? 'Create Account'
                              : 'Sign In',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading ? null : _switchMode,
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign In'
                            : 'No account? Create one',
                      ),
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
}

// --------------------------------------------------
// PROTECTED HOME SCREEN
// --------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCompleting = false;
  bool _isSigningOut = false;
  String? _message;

  Future<void> _completeChallenge() async {
    if (_isCompleting) return;

    setState(() {
      _isCompleting = true;
      _message = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'completeToday',
      );

      final result = await callable.call<Map<String, dynamic>>();
      final data = result.data;

      if (!mounted) return;

      final alreadyCompleted = data['alreadyCompleted'] == true;

      setState(() {
        _message = alreadyCompleted
            ? 'You already completed this challenge!'
            : 'Challenge completed! You earned 10 points '
                  'and the first-quest badge!';
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      setState(() {
        _message = 'Could not complete challenge: ${error.message}';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _message = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _message = 'Could not sign out. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final challengeStream = FirebaseFirestore.instance
        .collection('challenges')
        .doc('today')
        .snapshots();

    final progressStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .collection('progress')
        .doc('today')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Quest'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _isSigningOut ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to Cloud Quest!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Signed in as: ${widget.user.email ?? widget.user.uid}'),
              const SizedBox(height: 24),
              Text(
                "Today's Challenge",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: challengeStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Could not load the challenge. '
                      'Check the Firestore emulator and its rules.',
                      style: TextStyle(color: Colors.red),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.data!.exists) {
                    return const Text(
                      'No challenge is available in the emulator yet.',
                    );
                  }

                  final data = snapshot.data!.data();

                  final title = data?['title'];
                  final prompt = data?['prompt'];

                  if (title is! String || prompt is! String) {
                    return const Text(
                      'Challenge fields are missing or invalid.',
                    );
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(prompt),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              Text(
                'Your Progress',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: progressStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Could not load progress. Check Firestore permissions.',
                      style: TextStyle(color: Colors.red),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data?.data();
                  final completed = data?['completed'] == true;
                  final points = data?['points'] ?? 0;
                  final badgeId = data?['badgeId'];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                completed
                                    ? 'Status: Completed'
                                    : 'Status: Not completed',
                              ),
                              const SizedBox(height: 8),
                              Text('Points: $points'),
                              const SizedBox(height: 8),
                              Text('Badge: ${badgeId ?? "None"}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: completed || _isCompleting
                            ? null
                            : _completeChallenge,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isCompleting
                              ? 'Completing...'
                              : completed
                              ? 'Challenge Completed'
                              : 'Complete Challenge',
                        ),
                      ),
                    ],
                  );
                },
              ),

              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!, textAlign: TextAlign.center),
              ],

              const SizedBox(height: 32),

              OutlinedButton.icon(
                onPressed: _isSigningOut ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: Text(_isSigningOut ? 'Signing out...' : 'Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
