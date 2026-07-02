import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../login.dart';
import '../../main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  await Permission.camera.request();
  await Permission.microphone.request();
  await Permission.manageExternalStorage.request();
  await Permission.storage.request();

  runApp(MaterialApp(
    home: MyOnlineApp(),
  ));
}

class MyOnlineApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyOnlineApp> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
    crossPlatform: InAppWebViewOptions(
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
    ),
    android: AndroidInAppWebViewOptions(
      useHybridComposition: true,
    ),
    ios: IOSInAppWebViewOptions(
      allowsInlineMediaPlayback: true,
    ),
  );

  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Check if Back Office is opened
    _checkBackOfficeOpened();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
  }

  Future<void> _checkBackOfficeOpened() async {
   // SharedPreferences prefs = await SharedPreferences.getInstance();
   // bool? backOfficeOpened = prefs.getBool('backOfficeOpened');

    /*if (backOfficeOpened == null || backOfficeOpened == false) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyApp()),
      );
    }*/
  }

  Future<void> downloadFile(String url) async {
    try {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        await FlutterDownloader.enqueue(
          url: url,
          savedDir: (await getExternalStorageDirectory())!.path,
          fileName: 'downloaded_file',
          showNotification: true,
          openFileFromNotification: true,
        );
      } else {
        throw Exception('Permission denied');
      }
    } catch (error) {
      print('Download error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    key: webViewKey,
                    initialUrlRequest: URLRequest(
                      url: WebUri("https://aphel.blueichor.org"),
                    ),
                    initialOptions: options,
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                      controller.addJavaScriptHandler(
                        handlerName: "data",
                        callback: (args) async {
                          final prefs = await SharedPreferences.getInstance();
                          if (prefs.getString('username') == null) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => LoginPag()),
                            );
                          }
                        },
                      );
                      controller.addJavaScriptHandler(
                        handlerName: "excel",
                        callback: (args) async {
                          final excelLink =
                              "https://aphel.blueichor.org/app/excelLogin.php";
                          await launch(excelLink);
                        },
                      );
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    androidOnPermissionRequest: (controller, origin, resources) async {
                      return PermissionRequestResponse(
                        resources: resources,
                        action: PermissionRequestResponseAction.GRANT,
                      );
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      var uri = navigationAction.request.url!;

                      if (![
                        "http",
                        "https",
                        "file",
                        "chrome",
                        "data",
                        "javascript",
                        "about"
                      ].contains(uri.scheme)) {
                        // Handle download here
                        downloadFile(uri.toString());

                        // Cancel the request
                        return NavigationActionPolicy.CANCEL;
                      }

                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStop: (controller, url) async {
                      pullToRefreshController.endRefreshing();
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onLoadError: (controller, url, code, message) {
                      pullToRefreshController.endRefreshing();
                    },
                    onProgressChanged: (controller, progress) {
                      if (progress == 100) {
                        pullToRefreshController.endRefreshing();
                      }
                      setState(() {
                        this.progress = progress / 100;
                        urlController.text = this.url;
                      });
                    },
                    onUpdateVisitedHistory: (controller, url, androidIsReload) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      print(consoleMessage);
                    },
                  ),
                  progress < 1.0
                      ? LinearProgressIndicator(value: progress)
                      : Container(),
                ],
              ),
            ),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  child: Icon(Icons.arrow_back),
                  onPressed: () {
                    webViewController?.goBack();
                  },
                ),
                ElevatedButton(
                  child: Icon(Icons.refresh),
                  onPressed: () {
                    webViewController?.reload();
                  },
                ),
                ElevatedButton(
                  child: const Text('Use Offline'),
                  onPressed: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('backOfficeOpened', false);

                    // Navigate to the homepage and clear the navigation stack
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => MyApp()),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
