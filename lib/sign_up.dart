import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'homepage.dart';
import 'login.dart';
import 'package:intl/intl.dart';
import 'main.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _username = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String? _dob;
  bool _isLoading = false;
  bool _showPasswordRequirements = false;

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  final FocusNode _dobFocus = FocusNode();

  final _usernameFieldKey = GlobalKey<FormFieldState>();
  final _emailFieldKey = GlobalKey<FormFieldState>();
  final _passwordFieldKey = GlobalKey<FormFieldState>();
  final _confirmPasswordFieldKey = GlobalKey<FormFieldState>();
  final _dobFieldKey = GlobalKey<FormFieldState>();

  final TextEditingController _dobController = TextEditingController();

  // Password validation variables
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasSpecialChar = false;

  // Password visibility variables
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();

    _usernameFocus.addListener(() {
      if (!_usernameFocus.hasFocus) {
        _usernameFieldKey.currentState!.validate();
      }
    });

    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) {
        _emailFieldKey.currentState!.validate();
      }
    });

    _passwordFocus.addListener(() {
      if (_passwordFocus.hasFocus) {
        setState(() {
          _showPasswordRequirements = true;
        });
      } else {
        _passwordFieldKey.currentState!.validate();
      }
    });

    _confirmPasswordFocus.addListener(() {
      if (!_confirmPasswordFocus.hasFocus) {
        _confirmPasswordFieldKey.currentState!.validate();
      }
    });

    _dobFocus.addListener(() {
      if (!_dobFocus.hasFocus) {
        _dobFieldKey.currentState!.validate();
      }
    });
  }

  @override
  void dispose() {
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _dobFocus.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _validatePassword(String value) {
    setState(() {
      _hasMinLength = value.length >= 8;
      _hasUppercase = RegExp(r'^(?=.*[A-Z])').hasMatch(value);
      _hasSpecialChar = RegExp(r'^(?=.*[!@#\$&~])').hasMatch(value);
    });
  }

// Function to handle user sign-up
  void _signUp() async {
    setState(() {
      _showPasswordRequirements = true;
    });

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Check if the username already exists
      final QuerySnapshot usernameResult = await _firestore
          .collection('users')
          .where('username', isEqualTo: _username)
          .get();

      final List<DocumentSnapshot> usernameDocuments = usernameResult.docs;

      // Check if the email already exists in Firestore
      final QuerySnapshot emailResult = await _firestore
          .collection('users')
          .where('email', isEqualTo: _email)
          .get();

      final List<DocumentSnapshot> emailDocuments = emailResult.docs;

      // Collect error messages if both or either is taken
      if (usernameDocuments.isNotEmpty && emailDocuments.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Both username and email are already taken. Please choose different ones.')));
        setState(() {
          _isLoading = false;
        });
        return;
      } else if (usernameDocuments.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Username already taken. Please choose another.')));
        setState(() {
          _isLoading = false;
        });
        return;
      } else if (emailDocuments.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Email already taken. Please choose another.')));
        setState(() {
          _isLoading = false;
        });
        return;
      }

      try {
        // Try creating the user with Firebase Authentication
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // Send email verification
        User? user = userCredential.user;
        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'A verification email has been sent. Please verify your email.')));
        }

        // Save the user data in Firestore
        await _firestore.collection('users').doc(user?.uid).set({
          'username': _username,
          'email': _email,
          'dob': _dob,
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(username: _username),
          ),
        );
      } on FirebaseAuthException catch (e) {
        String message = '';
        if (e.code == 'email-already-in-use') {
          message = 'The email is already in use.';
        } else if (e.code == 'weak-password') {
          message = 'The password is too weak.';
        } else {
          message = 'Error: ${e.code} - ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Function to handle date selection
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dob = DateFormat('yyyy-MM-dd').format(picked);
        _dobController.text = _dob!;
      });
      _dobFieldKey.currentState!.validate();
    }
  }

  // Function to build password requirements validation UI
  Widget _buildPasswordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequirement(
            _hasMinLength, 'Password must be at least 8 characters long'),
        _buildRequirement(_hasUppercase,
            'Password must contain at least one uppercase letter'),
        _buildRequirement(_hasSpecialChar,
            'Password must contain at least one special character'),
      ],
    );
  }

  // Function to display individual requirement validation status
  Widget _buildRequirement(bool conditionMet, String requirementText) {
    return Row(
      children: [
        Icon(
          conditionMet ? Icons.check : Icons.close,
          color: conditionMet ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          requirementText,
          style: TextStyle(
            color: conditionMet ? Colors.green : Colors.red,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 246, 239, 219),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LandingPage(),
              ),
            );
          },
        ),
        title: const Text(
          'Sign Up',
          style: TextStyle(
            fontFamily: 'Times New Roman',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextFormField(
                    key: _usernameFieldKey,
                    focusNode: _usernameFocus,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Username *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _username = value;
                    },
                    style: const TextStyle(fontFamily: 'Times New Roman'),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: _emailFieldKey,
                    focusNode: _emailFocus,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _email = value;
                    },
                    style: const TextStyle(fontFamily: 'Times New Roman'),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: _passwordFieldKey,
                    focusNode: _passwordFocus,
                    obscureText: !_isPasswordVisible,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _password = value;
                      _validatePassword(value);
                    },
                    style: const TextStyle(fontFamily: 'Times New Roman'),
                  ),
                  if (_showPasswordRequirements) ...[
                    const SizedBox(height: 10),
                    _buildPasswordRequirements(),
                    const SizedBox(height: 20),
                  ],
                  TextFormField(
                    key: _confirmPasswordFieldKey,
                    focusNode: _confirmPasswordFocus,
                    obscureText: !_isConfirmPasswordVisible,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password *',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value != _password) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _confirmPassword = value;
                    },
                    style: const TextStyle(fontFamily: 'Times New Roman'),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: _dobFieldKey,
                    focusNode: _dobFocus,
                    controller: _dobController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date of Birth *',
                      prefixIcon: const Icon(Icons.calendar_today),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: () => _selectDate(context),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your date of birth';
                      }
                      return null;
                    },
                    style: const TextStyle(fontFamily: 'Times New Roman'),
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 137, 174, 124),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 80, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontFamily: 'Times New Roman',
                              fontSize: 16,
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(fontFamily: 'Times New Roman'),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 137, 174, 124),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
