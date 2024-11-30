import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'MyRecipesPage.dart';
import 'UserCollections.dart';
import 'nav_bar.dart';

class ProfilePage extends StatefulWidget {
  final String username;

  ProfilePage({required this.username});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _name = '';
  String? _email = '';
  String? _dob = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        String uid = user.uid;

        // Fetch the user's info from Firestore
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(uid).get();

        setState(() {
          _name = userDoc['username'];
          _email = userDoc['email'];
          _dob = userDoc['dob'] ?? 'Not provided';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _isUsernameUnique(String newUsername) async {
    QuerySnapshot querySnapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: newUsername)
        .get();

    return querySnapshot.docs.isEmpty;
  }

  Future<void> _updateUsername(String newUsername) async {
    User? user = _auth.currentUser;
    if (user != null) {
      String uid = user.uid;

      // Update username in Firestore
      await _firestore
          .collection('users')
          .doc(uid)
          .update({'username': newUsername});

      setState(() {
        _name = newUsername;
      });

      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          content: Text('Username updated successfully!'),
          backgroundColor: const Color.fromARGB(255, 118, 133, 118),
          actions: [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: Text(
                'DISMISS',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      Future.delayed(Duration(seconds: 3), () {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      });
    }
  }

  Future<void> _updateUserField(String field, String newValue) async {
    User? user = _auth.currentUser;
    if (user != null) {
      String uid = user.uid;

      // Update Firestore with the new value
      await _firestore.collection('users').doc(uid).update({field: newValue});

      setState(() {
        if (field == 'dob') {
          _dob = newValue;
        }
      });
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          content: Text('Date of birth updated successfully!'),
          backgroundColor: const Color.fromARGB(255, 118, 133, 118),
          actions: [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: Text(
                'DISMISS',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      Future.delayed(Duration(seconds: 9), () {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      });
    }
  }

  Future<void> _showDatePicker() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary:
                  const Color.fromRGBO(88, 126, 75, 1), // Header background
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor:
                    const Color.fromRGBO(88, 126, 75, 1), // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      String formattedDate =
          "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
      await _updateUserField('dob', formattedDate);
    }
  }

  void _showEditDialog(String field, String initialValue) {
    if (field == 'dob') {
      _showDatePicker();
      return;
    }

    final TextEditingController _controller =
        TextEditingController(text: initialValue);
    String feedbackMessage = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: const Color.fromARGB(255, 242, 243, 243),
              title: Text(
                'Edit ${field == 'username' ? 'Name' : 'Date of Birth'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(88, 126, 75, 1),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText:
                          'Enter your ${field == 'username' ? 'name' : 'date of birth'}',
                    ),
                  ),
                  if (feedbackMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        feedbackMessage,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color.fromRGBO(88, 126, 75, 1),
                  ),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String newValue = _controller.text.trim();
                    if (newValue.isEmpty) {
                      setState(() {
                        feedbackMessage = 'Field cannot be empty.';
                      });
                      return;
                    }

                    if (field == 'username') {
                      bool isUnique = await _isUsernameUnique(newValue);
                      if (!isUnique) {
                        setState(() {
                          feedbackMessage =
                              'Username already exists. Please choose another.';
                        });
                        return;
                      }
                      await _updateUsername(newValue);
                    }

                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(88, 126, 75, 1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final TextEditingController _currentPasswordController =
        TextEditingController();
    final TextEditingController _newPasswordController =
        TextEditingController();
    final TextEditingController _confirmPasswordController =
        TextEditingController();

    final FocusNode _currentPasswordFocus = FocusNode();
    final FocusNode _newPasswordFocus = FocusNode();
    final FocusNode _confirmPasswordFocus = FocusNode();

    bool isCurrentPasswordTouched = false;
    bool isNewPasswordTouched = false;
    bool isConfirmPasswordTouched = false;

    bool isLengthValid = false;
    bool hasUppercase = false;
    bool hasSpecialCharacter = false;

    bool isChangeButtonEnabled = false;

    void _validateFields() {
      isChangeButtonEnabled = !isCurrentPasswordTouched ||
          _currentPasswordController.text.isNotEmpty && !isNewPasswordTouched ||
          _newPasswordController.text.isNotEmpty && !isConfirmPasswordTouched ||
          _confirmPasswordController.text.isNotEmpty &&
              isLengthValid &&
              hasUppercase &&
              hasSpecialCharacter &&
              _newPasswordController.text.trim() ==
                  _confirmPasswordController.text.trim();
    }

    void _validatePassword(String password) {
      isLengthValid = password.length >= 8;
      hasUppercase = password.contains(RegExp(r'[A-Z]'));
      hasSpecialCharacter =
          password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(20.0),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Change Password',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: const Color.fromRGBO(88, 126, 75, 1),
                      ),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _currentPasswordController,
                      focusNode: _currentPasswordFocus,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        errorText: isNewPasswordTouched ||
                                isConfirmPasswordTouched &&
                                    _currentPasswordController.text.isEmpty
                            ? 'This field cannot be empty'
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _validateFields();
                        });
                      },
                      onTap: () {
                        if (!isCurrentPasswordTouched) {
                          setState(() {
                            isCurrentPasswordTouched = true;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _newPasswordController,
                      focusNode: _newPasswordFocus,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        errorText: isConfirmPasswordTouched &&
                                _newPasswordController.text.isEmpty
                            ? 'This field cannot be empty'
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _validatePassword(value);
                          _validateFields();
                        });
                      },
                      onTap: () {
                        if (!isNewPasswordTouched) {
                          setState(() {
                            isNewPasswordTouched = true;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isLengthValid ? Icons.check : Icons.close,
                              color: isLengthValid ? Colors.green : Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'At least 8 characters long',
                              style: TextStyle(
                                color:
                                    isLengthValid ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              hasUppercase ? Icons.check : Icons.close,
                              color: hasUppercase ? Colors.green : Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'At least one uppercase letter',
                              style: TextStyle(
                                color: hasUppercase ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              hasSpecialCharacter ? Icons.check : Icons.close,
                              color: hasSpecialCharacter
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'At least one special character',
                              style: TextStyle(
                                color: hasSpecialCharacter
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocus,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        errorText: isConfirmPasswordTouched &&
                                (_confirmPasswordController.text.isEmpty ||
                                    _newPasswordController.text.trim() !=
                                        _confirmPasswordController.text.trim())
                            ? _confirmPasswordController.text.isEmpty
                                ? 'This field cannot be empty'
                                : 'Passwords do not match'
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _validateFields();
                        });
                      },
                      onTap: () {
                        if (!isConfirmPasswordTouched) {
                          setState(() {
                            isConfirmPasswordTouched = true;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 137, 174, 124),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isChangeButtonEnabled
                      ? () async {
                          try {
                            User? user = _auth.currentUser;

                            if (user != null && user.email != null) {
                              // Reauthenticate the user
                              AuthCredential credential =
                                  EmailAuthProvider.credential(
                                email: user.email!,
                                password:
                                    _currentPasswordController.text.trim(),
                              );

                              await user
                                  .reauthenticateWithCredential(credential);

                              // Update password
                              await user.updatePassword(
                                  _newPasswordController.text.trim());

                              Navigator.of(context).pop(); // Close dialog

                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Success'),
                                  content: Text(
                                      'Password has been successfully changed!'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              isCurrentPasswordTouched = true;
                            });
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Error!'),
                                content: Text('Failed to change password.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      : null,
                  child: Text(
                    'Change',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.all(20.0),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.redAccent),
              SizedBox(width: 10),
              Text(
                'Confirm Logout',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                'Yes',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                await _auth.signOut(); // Sign out the user
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LandingPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
        elevation: 0,
        title: Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Prevents infinite height
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 20.0, horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Username',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _name ?? 'Loading...',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.grey),
                              onPressed: () {
                                _showEditDialog('username', _name ?? '');
                              },
                            ),
                          ],
                        ),
                        Divider(color: Colors.grey),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _email ?? 'Loading...',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Divider(color: Colors.grey),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date of Birth',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _dob ?? 'Loading...',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.grey),
                              onPressed: () {
                                _showEditDialog('dob', _dob ?? '');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.favorite,
                              color: Color.fromRGBO(88, 126, 75, 1)),
                          title: Text('Collections'),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => UserCollectionsPage(
                                      username: widget.username)),
                            );
                          },
                        ),
                        Divider(height: 1, color: Colors.grey),
                        ListTile(
                          leading: Icon(Icons.book,
                              color: Color.fromRGBO(88, 126, 75, 1)),
                          title: Text('My Recipes'),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MyRecipesPage(username: widget.username),
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, color: Colors.grey),
                        ListTile(
                          leading: Icon(Icons.lock,
                              color: Color.fromRGBO(88, 126, 75, 1)),
                          title: Text('Change Password'),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            _showChangePasswordDialog();
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 170),
                  Flexible(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 137, 174, 124),
                        padding:
                            EdgeInsets.symmetric(horizontal: 115, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        _showLogoutConfirmationDialog();
                      },
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: 2,
      ),
    );
  }
}
