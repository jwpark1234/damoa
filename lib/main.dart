import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';


Future main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Permission.storage.request();
  runApp(const MyApp());
}

getPermission() async{
  var status = await Permission.storage.status;
  if(status.isGranted){
    print('허락됨');
  } else if (status.isDenied){
    print('거절됨');
    Permission.storage.request(); // 허락해달라고 팝업띄우는 코드
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {

  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();

}



class _MyHomePageState extends State<MyHomePage> {

  String mDomain = "http://118.38.11.215:8000/app/";
  String mbIdParameter = "";

  WebViewController? _controller ;

  final Completer<WebViewController> _completerController = Completer<WebViewController>();

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
    getPermission();

  }

  @override
  Widget build(BuildContext context) {

    final double statusBarHeight = MediaQuery.of(context).padding.top;


    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
        body:
        Padding(
          padding: EdgeInsets.only(top: statusBarHeight),
          child:
          FutureBuilder(
            future: _fetch(),
            builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
              if(snapshot.hasData == false){
                return CircularProgressIndicator();
              }
              else if(snapshot.hasError){
                exit(1);
              }
              else{
                mbIdParameter = snapshot.data.toString();
                return WebView(
                  initialUrl: mDomain + snapshot.data.toString(),
                  javascriptMode: JavascriptMode.unrestricted,
                  gestureNavigationEnabled: true,
                  onWebViewCreated: (WebViewController wbc){
                    _controller = wbc;
                    // _completerController.future.then((value) => _controller = value);
                    // _completerController.complete(wbc);
                  },
                  javascriptChannels: <JavascriptChannel>{
                    _getJavascript(context),
                  },

                  onPageStarted: (url) => {
                    if(url.contains(".noSession")){
                      _controller!.loadUrl(mDomain + mbIdParameter)
                    }
                  },
                  onPageFinished: (url) => {

                  },

                  navigationDelegate: (request){

                    if(request.url.contains("tel:")){
                      _launchURL(request.url);
                      return NavigationDecision.prevent;
                    }
                    else if( request.url.contains("downloadFile.do") ){

                      print("request Url: " + request.url);

                      _downloadFile(request.url);

                      return NavigationDecision.prevent;
                    }
                    else {
                      print("request Url: " + request.url);
                      return NavigationDecision.navigate;
                    }
                  },

                );
              }
            },
          ) ,

        ),
      ),
    );

  }

  _launchURL(url) async {
    if (await launch(url)){
      print(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  _downloadFile(url) async {
    if (await launch(url)){
      print("browser url");
      print(url);
    }
    else{
      // can't launch url, there is some error
      throw "Could not launch $url";
    }

  }

  JavascriptChannel _getJavascript(BuildContext context) {
    return JavascriptChannel(
        name: 'damoaApp',
        onMessageReceived: (JavascriptMessage message) {
          print('javascript message: ' + message.message);
          if (message.message.contains('registered:')) {
            String mbId = message.message.replaceAll('registered:', '');
            //print('javascript mbid: ' + mbId);
            preferenceSave('mbId', mbId);
          }
          if(message.message.contains("NO_MBID")){
            _controller!.loadUrl(mDomain + mbIdParameter);
          }
        });
  }


  preferenceSave(String key, value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(key, value);
  }


  Future<String> _fetch() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String mbId = prefs.getString("mbId") ?? "";
    String fcmId = prefs.getString("fcmId") ?? "";

    print("mbId" + mbId);

    if (mbId == ""){
      return "mem.do";
    }
    return "main.do?mbId="+mbId;
  }


  Future<bool> _onWillPop(BuildContext context) async {

    if( await _controller!.canGoBack()){

      _controller!.goBack();
      return Future.value(false);

    }
    else {
      bool? exitResult = await showDialog(
        context: context,
        builder: (context) => _buildExitDialog(context),
      );
      return exitResult ?? false;
    }
  }

  Future<bool?> _showExitDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => _buildExitDialog(context),
    );
  }

  AlertDialog _buildExitDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('종료확인'),
      content: const Text('다모아앱을 나가시겠습니까?'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('아니오'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('예'),
        ),
      ],
    );
  }
}


