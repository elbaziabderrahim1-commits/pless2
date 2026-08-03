import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:fl_chart/fl_chart.dart'; // استيراد مكتبة المبيانات

void main() {
  runApp(EmployeeApp());
}

// ---------------------------------------------------------
// Database Helper
// ---------------------------------------------------------
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('employees.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        adminId TEXT NOT NULL,
        task TEXT NOT NULL,
        center TEXT NOT NULL,
        status TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertEmployee(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('employees', row);
  }

  Future<List<Map<String, dynamic>>> getEmployees() async {
    final db = await instance.database;
    return await db.query('employees', orderBy: 'id DESC');
  }

  Future<int> updateEmployee(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update(
      'employees',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteEmployee(int id) async {
    final db = await instance.database;
    return await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }
}

// ---------------------------------------------------------
// App Root
// ---------------------------------------------------------
class EmployeeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة الموظفين',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: LoginPage(),
      ),
    );
  }
}

// ---------------------------------------------------------
// شاشة تسجيل الدخول
// ---------------------------------------------------------
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _controller = TextEditingController();
  final String accessCode = "12345";

  void _checkCode() {
    if (_controller.text == accessCode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: EmployeeHomePage(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("الكود غير صحيح")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("تسجيل الدخول")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("أدخل الكود لفتح التطبيق", style: TextStyle(fontSize: 18)),
              SizedBox(height: 10),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "الكود",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkCode,
                child: Text("دخول"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// الصفحة الرئيسية (مع البحث والفلترة السريعة)
// ---------------------------------------------------------
class EmployeeHomePage extends StatefulWidget {
  @override
  _EmployeeHomePageState createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHomePage> {
  List<Map<String, dynamic>> employees = [];
  String searchQuery = "";
  String selectedFilterStatus = "الكل";

  @override
  void initState() {
    super.initState();
    _refreshEmployees();
  }

  Future<void> _refreshEmployees() async {
    final data = await DatabaseHelper.instance.getEmployees();
    setState(() {
      employees = data;
    });
  }

  Future<void> _deleteEmployee(int id) async {
    await DatabaseHelper.instance.deleteEmployee(id);
    _refreshEmployees();
  }

  void _confirmDelete(BuildContext context, int id, String name) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('تأكيد الحذف'),
              ],
            ),
            content: Text('هل أنت متاكد من حذف الموظف "$name"؟'),
            actions: [
              TextButton(
                child: Text('إلغاء'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('حذف', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _deleteEmployee(id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم حذف الموظف بنجاح')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEmployeeFormDialog({Map<String, dynamic>? employee}) {
    final bool isEditing = employee != null;

    final nameController = TextEditingController(text: isEditing ? employee['name'] : '');
    final adminIdController = TextEditingController(text: isEditing ? employee['adminId'] : '');
    final taskController = TextEditingController(text: isEditing ? employee['task'] : '');
    final centerController = TextEditingController(text: isEditing ? employee['center'] : '');
    String selectedStatus = isEditing ? employee['status'] : 'نشط';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Text(isEditing ? 'تعديل بيانات الموظف' : 'إضافة موظف جديد'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nameController, decoration: InputDecoration(labelText: 'الاسم الكامل')),
                      TextField(controller: adminIdController, decoration: InputDecoration(labelText: 'الرقم الإداري')),
                      TextField(controller: taskController, decoration: InputDecoration(labelText: 'المهمة')),
                      TextField(controller: centerController, decoration: InputDecoration(labelText: 'مركز العمل')),
                      SizedBox(height: 10),
                      DropdownButton<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: ['نشط', 'إجازة', 'رخصة مرضية']
                            .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedStatus = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty) {
                        final employeeData = {
                          'name': nameController.text,
                          'adminId': adminIdController.text,
                          'task': taskController.text,
                          'center': centerController.text,
                          'status': selectedStatus,
                          'date': isEditing ? employee['date'] : DateTime.now().toString().split(' ')[0],
                        };

                        if (isEditing) {
                          employeeData['id'] = employee['id'];
                          await DatabaseHelper.instance.updateEmployee(employeeData);
                        } else {
                          await DatabaseHelper.instance.insertEmployee(employeeData);
                        }

                        _refreshEmployees();
                        Navigator.pop(context);
                      }
                    },
                    child: Text(isEditing ? 'تحديث' : 'حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = employees.where((emp) {
      final query = searchQuery.toLowerCase();
      final nameMatches = emp['name'].toString().toLowerCase().contains(query) ||
          emp['adminId'].toString().toLowerCase().contains(query) ||
          emp['task'].toString().toLowerCase().contains(query) ||
          emp['center'].toString().toLowerCase().contains(query);

      bool statusMatches = selectedFilterStatus == "الكل" || emp['status'] == selectedFilterStatus;

      return nameMatches && statusMatches;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة الموظفين'),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: ReportsPage(employees: employees),
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'بحث عن موظف',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: ['الكل', 'نشط', 'إجازة', 'رخصة مرضية'].map((status) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: selectedFilterStatus == status,
                    selectedColor: Colors.blue.shade100,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedFilterStatus = status;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 8),

          Expanded(
            child: filteredEmployees.isEmpty
                ? Center(child: Text('لا توجد نتائج مطابقة'))
                : ListView.builder(
                    itemCount: filteredEmployees.length,
                    itemBuilder: (context, index) {
                      final emp = filteredEmployees[index];
                      return ListTile(
                        title: Text(emp['name'] ?? 'بدون اسم'),
                        subtitle: Text("مركز: ${emp['center']} - حالة: ${emp['status']}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEmployeeFormDialog(employee: emp),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(context, emp['id'], emp['name'] ?? 'بدون اسم'),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Directionality(
                                textDirection: TextDirection.rtl,
                                child: EmployeeCard(emp: emp),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmployeeFormDialog(),
        child: Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------
// بطاقة الموظف
// ---------------------------------------------------------
class EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> emp;

  EmployeeCard({required this.emp});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(emp['name'] ?? 'بطاقة الموظف')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("الاسم الكامل: ${emp['name']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Divider(),
                Text("الرقم الإداري: ${emp['adminId']}"),
                SizedBox(height: 8),
                Text("المهمة: ${emp['task']}"),
                SizedBox(height: 8),
                Text("مركز العمل: ${emp['center']}"),
                SizedBox(height: 8),
                Text("الحالة: ${emp['status']}"),
                SizedBox(height: 8),
                Text("تاريخ الإضافة: ${emp['date']}"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// صفحة التقارير الإحصائية (مع المبيان Pie Chart)
// ---------------------------------------------------------
class ReportsPage extends StatelessWidget {
  final List<Map<String, dynamic>> employees;

  ReportsPage({required this.employees});

  @override
  Widget build(BuildContext context) {
    int active = employees.where((e) => e['status'] == 'نشط').length;
    int vacation = employees.where((e) => e['status'] == 'إجازة').length;
    int sick = employees.where((e) => e['status'] == 'رخصة مرضية').length;
    int total = employees.length;

    return Scaffold(
      appBar: AppBar(title: Text("التقارير والمبيانات")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📊 المبيان الإحصائي للموظفين", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),

              total == 0
                  ? Center(child: Text("لا توجد بيانات لعرض المبيان"))
                  : SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            if (active > 0)
                              PieChartSectionData(
                                color: Colors.green,
                                value: active.toDouble(),
                                title: '${((active / total) * 100).toStringAsFixed(0)}%',
                                radius: 50,
                                titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            if (vacation > 0)
                              PieChartSectionData(
                                color: Colors.orange,
                                value: vacation.toDouble(),
                                title: '${((vacation / total) * 100).toStringAsFixed(0)}%',
                                radius: 50,
                                titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            if (sick > 0)
                              PieChartSectionData(
                                color: Colors.red,
                                value: sick.toDouble(),
                                title: '${((sick / total) * 100).toStringAsFixed(0)}%',
                                radius: 50,
                                titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),

              SizedBox(height: 20),
              Divider(),

              ListTile(
                leading: CircleAvatar(backgroundColor: Colors.green, radius: 8),
                title: Text("الموظفون النشطون"),
                trailing: Text("$active", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: CircleAvatar(backgroundColor: Colors.orange, radius: 8),
                title: Text("في إجازة"),
                trailing: Text("$vacation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: CircleAvatar(backgroundColor: Colors.red, radius: 8),
                title: Text("رخصة مرضية"),
                trailing: Text("$sick", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("📈 الإجمالي الكلي: $total موظف", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
