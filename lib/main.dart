// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:boykod/base_state.dart';
// import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return const MaterialApp(
      home: MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends BaseState<MyHomePage> {
  TextEditingController mailController = TextEditingController();
  TextEditingController messageController = TextEditingController();

  // Önbelleği temsil eden bir Map
  Map<String, String> cache = {};

  Future<void> scanBarcode(BuildContext context) async {
    String barcodeScanRes = '';

    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        "#ff6666",
        "İptal",
        true,
        ScanMode.BARCODE,
      );
    } catch (e) {
      print("Hata: $e");
    }

    if (barcodeScanRes != '-1') {
      // Önbellekte sorgu yapmadan önce kontrol et
      if (cache.containsKey(barcodeScanRes)) {
        // Önbellekte varsa, hemen sonucu kullan
        String productName = cache[barcodeScanRes]!;
        showResultDialog(context, barcodeScanRes, productName);
      } else {
        // Önbellekte yoksa, gerçek sorguyu yap
        String productName = await findProductName(context, barcodeScanRes);

        // Sonucu önbelleğe ekle
        cache[barcodeScanRes] = productName;

        showResultDialog(context, barcodeScanRes, productName);
      }
    }
  }

  Future<String> findProductName(BuildContext context, String barcode) async {
    String jsonString = await DefaultAssetBundle.of(context)
        .loadString("assets/urun_aciklamasi.json");
    Map<String, dynamic> productData = json.decode(jsonString);
    List<dynamic> brands = productData['markalar'];

    for (var brand in brands) {
      if (brand['barkod'].toString() == barcode) {
        return brand['isim'];
      }
    }

    return '';
  }

  Future<List<String>> getMarkaIsimleri(BuildContext context) async {
    String markaJsonString =
        await DefaultAssetBundle.of(context).loadString("assets/marka.json");
    Map<String, dynamic> markaData = json.decode(markaJsonString);
    List<dynamic> markaIsimleri = markaData['sahip'];

    List<String> result = [];
    for (var marka in markaIsimleri) {
      result.add(marka['isim']);
    }

    return result;
  }

  Future<void> showResultDialog(
      BuildContext context, String barcode, String productName) async {
    List<String> markaIsimleri = await getMarkaIsimleri(context);

    String firstProductNameWord = productName.split(' ').first.toLowerCase();
    bool markaBulundu = markaIsimleri.any((marka) {
      String firstMarkaWord = marka.split(' ').first.toLowerCase();
      return firstProductNameWord == firstMarkaWord;
    });

    if (markaBulundu) {
      await showCustomDialog(context, barcode, productName);
    } else {
      await showGreenConfirmationDialog(context, barcode, productName);
    }
  }

  Future<void> showCustomDialog(
    BuildContext context,
    String barcode,
    String productName,
  ) async {
    String itirazres = "assets/hom1pl.jpeg";
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              width: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Barkod: $barcode"),
                  const SizedBox(height: 10),
                  Text(
                    "Ürün Adı : $productName",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          size: 30,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Bu ürün boykot listesinde!",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall!
                              .copyWith(
                                  color: Color.fromARGB(255, 247, 28, 28),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Image.asset(
                    itirazres,
                    height: dynamicHeight(0.24),
                    width: dynamicWidth(1),
                    fit: BoxFit.fill,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 255, 12, 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 2),
                        ),
                        child: Text(
                          "Boykot!",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall!
                              .copyWith(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          sendMailitiraz(barcode, productName);
                          await Future.delayed(const Duration(seconds: 4));

                          // Navigator kullanarak showDialog'u kapat ve ana ekrana dön
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 42, 168, 65),
                        ),
                        child: Text(
                          "İtiraz Et!",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall!
                              .copyWith(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> showGreenConfirmationDialog(
    BuildContext context,
    String barcode,
    String productName,
  ) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Barkod: $barcode"),
              const SizedBox(height: 8),
              Text(
                "Ürün İsmi: $productName",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                height: 10,
              ),
              const FittedBox(
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 30,
                      color: Colors.green,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Bu ürün boykot listesinde değil.",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 26, 183, 28),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                    ),
                    child: Text(
                      "Tamam",
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall!
                          .copyWith(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      sendMailBildiri(barcode, productName);
                      await Future.delayed(const Duration(seconds: 4));

                      // Navigator kullanarak showDialog'u kapat ve ana ekrana dön
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 241, 38, 38),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                    ),
                    child: Text(
                      "Bildir!",
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall!
                          .copyWith(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void showMailBottomSheet(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: 400,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "İletişim",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.mail),
                  title: TextField(
                    controller: mailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: "Mail Adresiniz",
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.message),
                  title: TextField(
                    controller: messageController,
                    keyboardType: TextInputType.multiline,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: "Mesajınız",
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await sendMail(mailController.text, messageController.text);
                    Navigator.of(context).pop();
                  },
                  child: const Text("Gönder"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> sendMail(String recipient, String message) async {
    String username = 'ichixmokux@gmail.com';
    String password = 'nDFXIpRMP8fmUs54';

    final smtpServer = SmtpServer(
      'smtp-relay.brevo.com',
      username: username,
      password: password,
      port: 587,
    );

    final fromAddress = Address(username, 'Boykot App');

    final email = Message()
      ..from = fromAddress
      ..recipients.add(username)
      ..subject = 'İtiraz/Bildirim :: ${DateTime.now()}'
      ..text = message
      ..html = '''
         <h1>İçerik</h1>
           <p><strong>Gönderen:</strong> ${mailController.text}</p>
           <p>$message</p>
           ''';

    try {
      final sendReport = await send(email, smtpServer);
      print('Message sent: $sendReport');
    } on MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }

  Future<void> sendMailitiraz(String barcode, String productName) async {
    String username = 'ichixmokux@gmail.com';
    String password = 'nDFXIpRMP8fmUs54';

    final smtpServer = SmtpServer(
      'smtp-relay.brevo.com',
      username: username,
      password: password,
      port: 587,
    );

    final fromAddress = Address(username, 'Boykot / İTİRAZ');

    final email = Message()
      ..from = fromAddress
      ..recipients.add(username)
      ..subject = 'İtiraz :: ${DateTime.now()}'
      ..text = 'Barkod: $barcode\nÜrün Adı: $productName'
      ..html = '''
       <h1>İçerik</h1>
         <p><strong>Barkod:</strong> $barcode</p>
         <p><strong>Ürün Adı:</strong> $productName</p>
         ''';

    try {
      final sendReport = await send(email, smtpServer);
      print('Message sent: $sendReport');

      // Başarıyla gönderildiğine dair SnackBar göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'İtirazınız incelenmek üzere tarafımıza ulaşmıştır.!',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } on MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }

      // Hata durumunda SnackBar göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İtiraz gönderilirken bir hata oluştu.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> sendMailBildiri(String barcode, String productName) async {
    String username = 'ichixmokux@gmail.com';
    String password = 'nDFXIpRMP8fmUs54';

    final smtpServer = SmtpServer(
      'smtp-relay.brevo.com',
      username: username,
      password: password,
      port: 587,
    );

    final fromAddress = Address(username, 'Boykot / BİLDİRİ');

    final email = Message()
      ..from = fromAddress
      ..recipients.add(username)
      ..subject = 'Bildiri :: ${DateTime.now()}'
      ..text = 'Barkod: $barcode\nÜrün Adı: $productName'
      ..html = '''
       <h1>İçerik</h1>
         <p><strong>Barkod:</strong> $barcode</p>
         <p><strong>Ürün Adı:</strong> $productName</p>
         ''';

    try {
      final sendReport = await send(email, smtpServer);
      print('Message sent: $sendReport');

      // Başarıyla gönderildiğine dair SnackBar göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Uyarınız incelenmek üzere tarafımıza ulaşmıştır.!',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } on MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }

      // Hata durumunda SnackBar göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uyarı gönderilirken bir hata oluştu.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /*
  Future<void> _launchWebsite() async {
    const url = 'https://www.apple.com';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
  */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        actions: [
          IconButton(
            onPressed: () {
              showMailBottomSheet(context);
            },
            icon: const Icon(
              Icons.mail,
              size: 30,
              color: Colors.white,
            ),
          ),
        ],
        title: GestureDetector(
          onTap: () {
            //_launchWebsite();
          },
          child: const Text(
            "NEVER FORGET",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: const Color.fromARGB(255, 243, 243, 243),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      "Dikkat!",
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium!
                          .copyWith(
                              color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    Flexible(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text:
                              "Aradığınız ürünün boykot veya boykot olmaması gerektiğini düşünüyorsanız lütfen barkod numarasını ve ürün ismini ",
                          children: [
                            TextSpan(
                              text: "itiraz/Bildiri",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // Tıklandığında yapılacak işlemler
                                  showMailBottomSheet(context);
                                },
                            ),
                            const TextSpan(
                              text: " bölümünden bize yazın. ",
                            ),
                          ],
                          style: Theme.of(context)
                              .textTheme
                              .subtitle1!
                              .copyWith(
                                color: const Color.fromARGB(255, 23, 10, 10),
                                fontSize: 18,
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
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () => scanBarcode(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(10.0),
                    elevation: 15,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    color: const Color.fromARGB(255, 69, 162, 83),
                    height: MediaQuery.of(context).size.height * 0.15,
                    child: const Text(
                      "Barkod Tara",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.30,
              width: MediaQuery.of(context).size.width * 0.85,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/ttbo1.jpeg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(11),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () => showMailBottomSheet(context),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      elevation: 15,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 213, 28, 28),
                        borderRadius:
                            BorderRadius.circular(10), // Köşe yuvarlatma değeri
                      ),
                      child: const Text(
                        "İtiraz / Bildiri",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 34,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
