import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/medicine_schedule_monitor.dart';

class MyInfoScreen extends StatefulWidget {
  final VoidCallback? onBackTap;

  const MyInfoScreen({super.key, this.onBackTap});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _diseaseCtrl;
  late TextEditingController _roomNumberCtrl;
  late String _gender;
  bool _saved = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize controllers immediately with empty values
    _nameCtrl = TextEditingController();
    _ageCtrl = TextEditingController();
    _diseaseCtrl = TextEditingController();
    _roomNumberCtrl = TextEditingController();
    _gender = 'Male';
    // Load saved data when screen opens
    _loadSavedInfo();
  }

  void _loadSavedInfo() async {
    // Ensure we have the latest saved data
    await ApiService.loadSavedUserInfo();
    
    if (mounted) {
      setState(() {
        _nameCtrl.text = ApiService.userName ?? '';
        _ageCtrl.text = ApiService.userAge ?? '';
        _diseaseCtrl.text = ApiService.userDisease ?? '';
        _roomNumberCtrl.text = ApiService.userRoomNumber ?? '';
        _gender = ApiService.userGender?.isNotEmpty == true ? ApiService.userGender! : 'Male';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _diseaseCtrl.dispose();
    _roomNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveInfo() async {
    if (_formKey.currentState?.validate() ?? false) {
      final previousName = ApiService.userName?.trim() ?? '';
      final newName = _nameCtrl.text.trim();
      ApiService.updateUserInfo(
        name: _nameCtrl.text,
        gender: _gender,
        age: _ageCtrl.text,
        disease: _diseaseCtrl.text,
        roomNumber: _roomNumberCtrl.text,
      );
      if (previousName != newName) {
        MedicineScheduleMonitor.instance.onUserIdentityChanged();
      }
      await ApiService.syncElderProfileToServer();
      if (!mounted) return;
      setState(() {
        _saved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Info saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          // Form content
          Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.orange)
                : SizedBox(
                    width: 320,
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'My Info',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _nameCtrl,
                              label: 'Name',
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 8),
                            _buildDropdown(),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _ageCtrl,
                              label: 'Age',
                              keyboardType: TextInputType.number,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _roomNumberCtrl,
                              label: 'Room Number',
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _diseaseCtrl,
                              label: 'Disease (optional)',
                              validator: (_) => null,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _saveInfo(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: Text(
                                  _saved ? 'Saved' : 'Save',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          // Back button (keep LAST so it stays on top)
          Positioned(
            top: 28,
            left: 28,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onBackTap,
                borderRadius: BorderRadius.circular(25),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.2),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.6),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white38),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        value: _gender,
        dropdownColor: Colors.black87,
        decoration: const InputDecoration(
          border: InputBorder.none,
        ),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        iconEnabledColor: Colors.white,
        items: const [
          DropdownMenuItem(value: 'Male', child: Text('Male')),
          DropdownMenuItem(value: 'Female', child: Text('Female')),
          DropdownMenuItem(value: 'Other', child: Text('Other')),
        ],
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _gender = val;
            });
          }
        },
      ),
    );
  }
}
