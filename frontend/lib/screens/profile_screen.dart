import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/user/update-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'currentPassword': _passwordController.text,
          'newPassword': _newPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully'), backgroundColor: Colors.green),
        );
        _passwordController.clear();
        _newPasswordController.clear();
      } else {
        throw Exception('Failed to update password');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Account Security', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              Card(
                color: Colors.white.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Current Password', labelStyle: TextStyle(color: Colors.white70), border: OutlineInputBorder()),
                          obscureText: true,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'New Password', labelStyle: TextStyle(color: Colors.white70), border: OutlineInputBorder()),
                          obscureText: true,
                          validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updatePassword,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EE)),
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Update Password', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text('Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              SwitchListTile(
                title: const Text('Enable Notifications', style: TextStyle(color: Colors.white)),
                value: _notificationsEnabled,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedLanguage,
                dropdownColor: const Color(0xFF16213E),
                decoration: const InputDecoration(labelText: 'Language', labelStyle: TextStyle(color: Colors.white70)),
                items: ['English', 'Tiếng Việt'].map((lang) => DropdownMenuItem(value: lang, child: Text(lang, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (val) => setState(() => _selectedLanguage = val!),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
