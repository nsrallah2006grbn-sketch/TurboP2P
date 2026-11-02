import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
      home: const ZapyaStyleScreen(),
    );
  }
}

class ZapyaStyleScreen extends StatefulWidget {
  const ZapyaStyleScreen({super.key});

  @override
  State<ZapyaStyleScreen> createState() => _ZapyaStyleScreenState();
}

class _ZapyaStyleScreenState extends State<ZapyaStyleScreen> {
  // متغيرات نظام النقل والاتصال
  String status = "جاهز للإرسال أو الاستقبال";
  double progress = 0.0;
  ServerSocket? serverSocket;
  final TextEditingController ipController = TextEditingController();

  // 1. بدء سيرفر الاستقبال (Receiver)
  Future<void> startReceiver() async {
    try {
      serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 4040);
      setState(() {
        status = "في انتظار الاتصال على المنفذ 4040...";
      });

      serverSocket!.listen((Socket client) {
        setState(() {
          status = "جاري استقبال الملف من: ${client.remoteAddress.address}";
        });

        List<int> bytes = [];
        client.listen(
          (data) {
            bytes.addAll(data);
            setState(() {
              status = "تم استقبال ${bytes.length} بايت...";
            });
          },
          onDone: () async {
            final file = File('/sdcard/Download/received_file_${DateTime.now().millisecondsSinceEpoch}.dat');
            await file.writeAsBytes(bytes);
            setState(() {
              status = "تم الحفظ بنجاح في مجلد التحميلات!";
            });
            client.close();
          },
        );
      });
    } catch (e) {
      setState(() {
        status = "خطأ في السيرفر: $e";
      });
    }
  }

  // 2. إرسال ملف بأقصى سرعة (Sender)
  Future<void> sendFile() async {
    if (ipController.text.isEmpty) {
      setState(() {
        status = "يرجى كتابة عنوان IP لجهاز المستلم أولاً";
      });
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      int totalBytes = await file.length();
      int sentBytes = 0;

      try {
        setState(() {
          status = "جاري الاتصال بـ ${ipController.text}...";
        });

        Socket socket = await Socket.connect(ipController.text, 4040);
        Stream<List<int>> fileStream = file.openRead();

        await for (var chunk in fileStream) {
          socket.add(chunk);
          sentBytes += chunk.length;
          setState(() {
            progress = sentBytes / totalBytes;
            status = "جاري النقل السريع: ${(progress * 100).toStringAsFixed(1)}%";
          });
        }

        await socket.flush();
        await socket.close();
        setState(() {
          status = "تم إرسال الملف بنجاح بأقصى سرعة!";
        });
      } catch (e) {
        setState(() {
          status = "فشل الإرسال: $e";
        });
      }
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
                hintText: 'البحث عن التطبيقات والملفات',
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
              Tab(text: 'ملفات / اتصال'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // تبويب التطبيقات (شبكة اختيار الملفات)
            GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.android, color: Colors.green),
                        ),
                        const Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(Icons.radio_button_unchecked, size: 18, color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text('تطبيق', style: TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                    const Text('20 م.ب', style: TextStyle(fontSize: 8, color: Colors.grey)),
                  ],
                );
              },
            ),
            const Center(child: Text('محتوى الإستوديو', style: TextStyle(color: Colors.white70))),
            const Center(child: Text('محتوى الفيديو', style: TextStyle(color: Colors.white70))),
            const Center(child: Text('محتوى الصوتيات', style: TextStyle(color: Colors.white70))),
            
            // تبويب التحكم والاتصال والإرسال المباشر
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, size: 70, color: Colors.redAccent),
                  const SizedBox(height: 15),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.white70),
                  ),
                  const SizedBox(height: 15),
                  LinearProgressIndicator(value: progress, color: Colors.redAccent),
                  const SizedBox(height: 30),
                  TextField(
                    controller: ipController,
                    decoration: const InputDecoration(
                      labelText: 'أدخل IP جهاز المستلم',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wifi, color: Colors.redAccent),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: sendFile,
                        icon: const Icon(Icons.send),
                        label: const Text('إرسال ملف'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: startReceiver,
                        icon: const Icon(Icons.call_received),
                        label: const Text('استقبال'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
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
