import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/project_repository.dart';
import '../../../projects/data/project_model.dart';

class ProjectSetupScreen extends StatefulWidget {
  final String? editSchoolName;

  const ProjectSetupScreen({
    super.key,
    this.editSchoolName,
  });

  @override
  State<ProjectSetupScreen> createState() => _ProjectSetupScreenState();
}

class _ProjectSetupScreenState extends State<ProjectSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _schoolController;
  final _repository = ProjectRepository();
  final List<ClassConfigModel> _classes = [];

  bool _byClass = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _schoolController = TextEditingController(text: widget.editSchoolName ?? '');
  }

  @override
  void dispose() {
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _addClass() async {
    final controller = TextEditingController();
    final key = GlobalKey<FormState>();

    final className = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Class', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: key,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. 1, 2, 10, BCA',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Enter a class or batch name.';
              if (_classes.any((c) => c.className.toLowerCase() == text.toLowerCase())) {
                return 'This class already exists.';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (key.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (className != null && className.isNotEmpty && mounted) {
      setState(() {
        _classes.add(
          ClassConfigModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            className: className,
            sections: [
              SectionConfigModel(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: 'A',
                startRoll: 1,
                totalStudents: 45,
              ),
            ],
          ),
        );
      });
    }
  }

  Future<void> _addSection(ClassConfigModel classConfig) async {
    final nameController = TextEditingController(text: _nextSectionName(classConfig));
    final key = GlobalKey<FormState>();

    final section = await showDialog<SectionConfigModel>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add New Section',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF202020), fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 18, color: Color(0xFF202020)),
                  decoration: InputDecoration(
                    labelText: 'Section Name',
                    hintText: 'e.g. A, B, C',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return 'Enter a section name.';
                    if (classConfig.sections.any((item) => item.name.toLowerCase() == name.toLowerCase())) {
                      return 'This section already exists.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: () {
                          if (key.currentState!.validate()) {
                            Navigator.pop(
                              dialogContext,
                              SectionConfigModel(
                                id: DateTime.now().microsecondsSinceEpoch.toString(),
                                name: nameController.text.trim().toUpperCase(),
                                startRoll: 1,
                                totalStudents: 45,
                              ),
                            );
                          }
                        },
                        child: const Text('Save Section'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (section != null && mounted) {
      setState(() => classConfig.sections.add(section));
    }
  }

  String _nextSectionName(ClassConfigModel classConfig) {
    final existing = classConfig.sections.map((item) => item.name).toSet();
    for (var i = 0; i < 26; i++) {
      final candidate = String.fromCharCode(65 + i);
      if (!existing.contains(candidate)) return candidate;
    }
    return 'Section ${classConfig.sections.length + 1}';
  }

  Future<void> _deleteSection(ClassConfigModel classConfig, SectionConfigModel section) async {
    setState(() => classConfig.sections.remove(section));
  }

  Future<void> _deleteClass(ClassConfigModel classConfig) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Class?'),
        content: Text('Delete "${classConfig.className}" and its sections?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _classes.remove(classConfig));
    }
  }

  Future<void> _saveConfiguration() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_classes.isEmpty) {
      _showMessage('Add at least one class before saving.');
      return;
    }
    if (_classes.any((item) => item.sections.isEmpty)) {
      _showMessage('Add at least one section to every class before saving.');
      return;
    }

    setState(() => _saving = true);
    try {
      final schoolName = _schoolController.text.trim();

      await _repository.createProject(
        name: schoolName,
        schoolName: schoolName,
        classes: _classes,
      );

      if (!mounted) return;
      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project configuration saved successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('Could not save configuration. Please try again.');
      }
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSecondary,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              // Header Stack
              SizedBox(
                height: 260,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 24, 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primaryDark, AppColors.primaryDeep],
                        ),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create New Project',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Configure layout matrix wizard',
                                  style: TextStyle(
                                    color: AppColors.textOnPrimaryMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 110,
                      left: 20,
                      right: 20,
                      child: _buildSchoolNameCard(),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  children: [
                    _buildModeSelector(),
                    const SizedBox(height: 18),
                    if (_classes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 34),
                        child: Text(
                          'No classes added yet. Click below to add.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                        ),
                      )
                    else if (_byClass)
                      ..._classes.map(_buildClassCard)
                    else
                      ..._buildSectionList(),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _addClass,
                      icon: const Icon(Icons.add, size: 24),
                      label: const Text(
                        'Add New Class',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : _saveConfiguration,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 58),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _saving
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text(
                        'Proceed & Save Config',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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

  Widget _buildSchoolNameCard() {
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text.rich(
                TextSpan(
                  text: 'School Name ',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                  children: [
                    TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _schoolController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. ABC Public School',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('🏫', style: TextStyle(fontSize: 20)),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the school name.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _modeButton('By Class', true),
          _modeButton('By Section List', false),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool classMode) {
    final selected = _byClass == classMode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _byClass = classMode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(ClassConfigModel classConfig) {
    final students = classConfig.sections.fold(0, (sum, s) => sum + s.totalStudents);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => classConfig.isExpanded = !classConfig.isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A6D7),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '#',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classConfig.className,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${classConfig.sections.length} Sections • $students Students',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteClass(classConfig),
                    icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                  ),
                  Icon(
                    classConfig.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (classConfig.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Expanded(flex: 2, child: _TableHeader('Section')),
                      Expanded(flex: 2, child: _TableHeader('Start Roll')),
                      Expanded(flex: 2, child: _TableHeader('Students')),
                      SizedBox(width: 34, child: _TableHeader('')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...classConfig.sections.map(
                        (section) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _valueCell(section.name, highlighted: true),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              child: TextFormField(
                                initialValue: '${section.startRoll}',
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (val) {
                                  final numVal = int.tryParse(val);
                                  if (numVal != null && numVal >= 1) {
                                    setState(() => section.startRoll = numVal);
                                  }
                                },
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              child: TextFormField(
                                initialValue: '${section.totalStudents}',
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (val) {
                                  final numVal = int.tryParse(val);
                                  if (numVal != null && numVal >= 1) {
                                    setState(() => section.totalStudents = numVal);
                                  }
                                },
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 34,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _deleteSection(classConfig, section),
                              icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _addSection(classConfig),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Section', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSectionList() {
    final list = <Widget>[];
    for (final c in _classes) {
      list.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              c.className,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
          ),
        ),
      );

      for (final s in c.sections) {
        list.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Section ${s.name}', style: const TextStyle(fontWeight: FontWeight.bold))),
                Text('Roll ${s.startRoll}'),
                const SizedBox(width: 12),
                Text('${s.totalStudents} students'),
                IconButton(
                  onPressed: () => _deleteSection(c, s),
                  icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );
      }
    }
    return list;
  }

  Widget _valueCell(String value, {bool highlighted = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border,
        ),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: highlighted ? AppColors.primary : Colors.black87,
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;
  const _TableHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    );
  }
}
