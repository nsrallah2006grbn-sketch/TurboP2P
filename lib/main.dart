import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const TurboP2PApp());
}

class TurboP2PApp extends StatelessWidget {
  const TurboP2PApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TurboP2P',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: Colors.redAccent,
      ),
      home: const RealZapyaScreen(),
    );
  }
}

class RealZapyaScreen extends StatefulWidget {
  const RealZapyaScreen({super.key});

  @override
  State<RealZapyaScreen> createState() => _RealZapyaScreenState();
}

class _RealZapyaScreenState extends State<RealZapyaScreen> {
  bool hasPermission = false;
  String status = "جاري فحص الجهاز والاتصال...";
  ServerSocket? serverSocket;
  final TextEditingController ipController = TextEditingController();
  double progress = 0.0;

  @override
  void initState() {
    super.initState();
    checkAndRequestPermissions();
    startReceiverServer();
  }

  // 1. طلب صلاحيات الوصول للملفات والتخزين عند فتح التطبيق
  Future<void> checkAndRequestPermissions() async {
    var statusStorage = await Permission.storage.request();
    var manageStorage = await Permission.manageExternalStorage.request();
    
    if (statusStorage.isGranted || manageStorage.isGranted || await Permission.photos.isGranted) {
      setState(() {
        hasPermission = true;
        status = "تم منح الصلاحيات - جاهز للمشاركة";
      });
    } else {
      setState(() {
        status = "يرجى منح صلاحية الوصول للملفات لعرض محتوى الهاتف";
      });
    }
  }

  // 2. سيرفر استقبال الملفات التلقائي
  Future<void> startReceiverServer() async {
    try {
      serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 4040);
      serverSocket!.listen((Socket client) {
        setState(() {
          status = "جاري استقبال ملف من: ${client.remoteAddress.address}";
        });

        List<int> bytes = [];
        client.listen(
          (data) {
            bytes.addAll(data);
          },
          onDone: () async {
            final file = File('/sdcard/Download/TurboP2P_${DateTime.now().millisecondsSinceEpoch}.dat');
            await file.writeAsBytes(bytes);
            setState(() {
              status = "تم استقبال وحفظ الملف في التحميلات بنجاح!";
            });
            client.close();
          },
        );
      });
    } catch (e) {
      print("Server error: $e");
    }
  }

  // 3. دالة الإرسال السريع
  Future<void> sendFileToDevice(String path) async {
    if (ipController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة أو اكتشاف IP الجهاز المستقبل')),
      );
      return;
    }

    try {
      File file = File(path);
      int totalBytes = await file.length();
      int sentBytes = 0;

      Socket socket = await Socket.connect(ipController.text, 4040);
      Stream<List<int>> fileStream = file.openRead();

      await for (var chunk in fileStream) {
        socket.add(chunk);
        sentBytes += chunk.length;
        setState(() {
          progress = sentBytes / totalBytes;
          status = "جاري الإرسال الخارق: ${(progress * 100).toStringAsFixed(1)}%";
        });
      }

      await socket.flush();
      await socket.close();
      setState(() {
        status = "تم إرسال الملف بنجاح تام!";
      });
    } catch (e) {
      setState(() {
        status = "خطأ في الإرسال: تأكد من اتصال الواي فاي المباشر";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'ابحث في ملفات وتطبيقات هاتفك...',
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Colors.white54),
              ),
            ),
          ),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'تطبيقات'),
              Tab(text: 'الإستوديو'),
              Tab(text: 'فيديو'),
              Tab(text: 'صوتيات'),
              Tab(text: 'اتصال وإرسال'),
            ],
          ),
        ),
        body: !hasPermission
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_shared, size: 80, color: Colors.redAccent),
                      const SizedBox(height: 20),
                      const Text(
                        'يحتاج التطبيق لصلاحية الوصول إلى ملفات الهاتف لعرض الصور والتطبيقات والفيديوهات للمشاركة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: checkAndRequestPermissions,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        child: const Text('منح الصلاحية الآن'),
                      ),
                    ],
                  ),
                ),
              )
            : TabBarView(
                children: [
                  // 1. تبويب التطبيقات الحقيقية
                  GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 15, // سيتم استبدالها بقائمة التطبيقات المثبتة الحقيقية
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                height: 55,
                                width: 55,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.android, color: Colors.green, size: 30),
                              ),
                              const Positioned(
                                top: 0,
                                right: 0,
                                child: Icon(Icons.radio_button_unchecked, size: 18, color: Colors.redAccent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('تطبيق $index', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                          const Text('15 م.ب', style: TextStyle(fontSize: 8, color: Colors.grey)),
                        ],
                      );
                    },
                  ),

                  // 2. تبويب الاستوديو (الصور)
                  GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Icon(Icons.image, color: Colors.white54)),
                      );
                    },
                  ),

                  // 3. تبويب الفيديوهات
                  ListView.builder(
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.video_file, color: Colors.redAccent, size: 40),
                        title: Text('فيديو هاتفي رقم $index.mp4'),
                        subtitle: const Text('45 ميجابايت'),
                        trailing: IconButton(
                          icon: const Icon(Icons.share, color: Colors.cyanAccent),
                          onPressed: () async {
                            FilePickerResult? result = await FilePicker.platform.pickFiles();
                            if (result != null) {
                              sendFileToDevice(result.files.single.path!);
                            }
                          },
                        ),
                      );
                    },
                  ),

                  // 4. تبويب الصوتيات
                  const Center(child: Text('مجلد الموسيقى والصوتيات في هاتفك', style: TextStyle(color: Colors.white54))),

                  // 5. تبويب الاتصال والتحكم بالشبكة المباشرة
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, size: 70, color: Colors.redAccent),
                        const SizedBox(height: 10),
                        Text(status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 15),
                        LinearProgressIndicator(value: progress, color: Colors.redAccent),
                        const SizedBox(height: 25),
                        TextField(
                          controller: ipController,
                          decoration: const InputDecoration(
                            labelText: 'عنوان IP الجهاز المستلم (تلقائي أو يدوي)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.wifi, color: Colors.redAccent),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () async {
                            FilePickerResult? result = await FilePicker.platform.pickFiles();
                            if (result != null && result.files.single.path != null) {
                              sendFileToDevice(result.files.single.path!);
                            }
                          },
                          icon: const Icon(Icons.send),
                          label: const Text('اختيار ملف وإرساله فوراً'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xFF1E293B),
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'الملفات'),
            BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'اتصال'),
            BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'إكتشاف'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'أنا'),
          ],
        ),
      ),
    );
  }
}
