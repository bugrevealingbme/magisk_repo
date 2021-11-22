import 'dart:isolate';
import 'dart:ui';

import 'package:android_path_provider/android_path_provider.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:magisk_repo/screens/markdown.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:root/root.dart';
import 'package:flutter_archive/flutter_archive.dart';

extension E on String {
  String lastChars(int n) => substring(length - n);
}

class MyHomePage extends StatefulWidget {
  final TargetPlatform? platform;
  const MyHomePage({Key? key, required this.title, required this.platform})
      : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

Future fetchData() async {
  final response = await http.get(
    Uri.parse(
        'https://raw.githubusercontent.com/Magic-Mask-Repo/json/main/modules.json'),
  );

  if (response.statusCode == 200) {
    return (jsonDecode(response.body));
  } else {
    throw Exception('Failed to get data.');
  }
}

Future fetchProp(String url) async {
  final response = await http.get(
    Uri.parse(url),
  );

  if (response.statusCode == 200) {
    return (response.body);
  } else {
    throw Exception('Failed to get data.');
  }
}

class _MyHomePageState extends State<MyHomePage> {
  late Future futureData;
  TextEditingController editingController = TextEditingController();
  String searchString = "";
  bool viewer = false;

  late bool _permissionReady;
  late String _localPath;
  ReceivePort _port = ReceivePort();
  List<_TaskInfo> _tasks = [];
  late List<DownloadTask>? oldTasks;

  late BannerAd myBanner;
  bool rooted = false;
  BannerAd? _anchoredBanner;
  InterstitialAd? _interstitialAd;
  int _numInterstitialLoadAttempts = 0;

  @override
  void initState() {
    super.initState();

    futureData = fetchData();

    _bindBackgroundIsolate();

    FlutterDownloader.registerCallback(downloadCallback);

    _permissionReady = false;
    _prepare();

    Root.isRooted().then((value) => rooted = value!);

    //ads
    final BannerAd banner = BannerAd(
      size: AdSize.banner,
      request: const AdRequest(),
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3753684966275105/2700740489'
          : 'ca-app-pub-3753684966275105/2700740489',
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _anchoredBanner = ad as BannerAd?;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
        },
      ),
    );
    banner.load();

    _createInterstitialAd();
  }

  void _bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      String? id = data[0];
      DownloadTaskStatus? status = data[1];
      int? progress = data[2];

      if (_tasks.isNotEmpty) {
        final task = _tasks.firstWhere((task) => task.taskId == id);
        setState(() {
          task.status = status;
          task.progress = progress;
        });
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  @override
  void dispose() {
    super.dispose();
    _unbindBackgroundIsolate();

    try {
      myBanner.dispose();
    } catch (e) {}
    _interstitialAd?.dispose();
  }

  void _createInterstitialAd() {
    InterstitialAd.load(
        adUnitId: "ca-app-pub-3753684966275105/1965409168",
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
            _numInterstitialLoadAttempts = 0;
            _interstitialAd!.setImmersiveMode(true);
            _showInterstitialAd();
          },
          onAdFailedToLoad: (LoadAdError error) {
            _numInterstitialLoadAttempts += 1;
            _interstitialAd = null;
            if (_numInterstitialLoadAttempts <= 3) {
              _createInterstitialAd();
            }
          },
        ));
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) {
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _createInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        _createInterstitialAd();
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }

  Future _prepare() async {
    _permissionReady = await _checkPermission();

    if (_permissionReady) {
      await _prepareSaveDir();
    }

    await FlutterDownloader.loadTasks().then((value) {
      oldTasks = value;

      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).backgroundColor,
        elevation: 0,
        /*title: Text(widget.title,
            style: const TextStyle(
              color: Colors.black,
            )),
        toolbarHeight: 0,*/
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              onPressed: () {
                _deviceDialog();
              },
              icon: const Icon(
                Icons.phone_android_outlined,
                size: 26.0,
              ),
            ),
          )
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 60.0,
        child: Column(
          children: [
            if (_anchoredBanner != null) ...[
              Container(
                color: Colors.green,
                width: _anchoredBanner!.size.width.toDouble(),
                height: _anchoredBanner!.size.height.toDouble(),
                child: AdWidget(ad: _anchoredBanner!),
              ),
            ]
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 100),
              Text(widget.title, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Text("Root Permission:",
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 3),
                  Text(rooted == true ? "Yes" : "No",
                      style: TextStyle(
                          fontSize: 16,
                          color: rooted == true ? Colors.green : Colors.red)),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                height: 50,
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchString = value;
                    });
                  },
                  controller: editingController,
                  decoration: InputDecoration(
                    hintText: "Search Module",
                    hintStyle:
                        const TextStyle(color: Color(0xff8f8f8f), fontSize: 17),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          width: 2,
                          color: Theme.of(context).colorScheme.secondary),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xff8f8f8f),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              /*FutureBuilder(
                  future: FlutterDownloader.loadTasks(),
                  builder: (context, snaphat) {
                    return Text(snaphat.data.toString());
                  }),*/
              FutureBuilder(
                  future: futureData,
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    if (snapshot.hasData) {
                      List apiData = snapshot.data['modules'];

                      return ListView.builder(
                          padding: const EdgeInsets.all(0),
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true,
                          primary: false,
                          itemCount: apiData.length,
                          itemBuilder: (context, index) {
                            _tasks.add(_TaskInfo(
                              link: apiData[index]['zip_url'],
                            ));

                            //if (index == apiData.length - 1) {
                            for (var task in oldTasks!) {
                              for (_TaskInfo info in _tasks) {
                                if (info.link == task.url) {
                                  info.taskId = task.taskId;
                                  info.status = task.status;
                                  info.progress = task.progress;
                                  info.name = task.filename;
                                }
                              }
                            }

                            var brightness =
                                MediaQuery.of(context).platformBrightness;
                            bool darkModeOn = brightness == Brightness.dark;
                            //}
                            if (index == 0) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "Online Repo (" +
                                            apiData.length.toString() +
                                            ")",
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            viewer = viewer ? false : true;
                                            debugPrint(viewer.toString());
                                          });
                                        },
                                        icon: viewer
                                            ? const Icon(
                                                Icons.calendar_view_day_rounded)
                                            : const Icon(
                                                Icons.calendar_view_day),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 15)
                                ],
                              );
                            }
                            if (apiData[index]['prop_content']['name']
                                .toString()
                                .toLowerCase()
                                .contains(searchString.toLowerCase())) {
                              return viewer
                                  ? moduleListView(
                                      darkModeOn, context, apiData, index)
                                  : moduleCardView(
                                      darkModeOn, context, apiData, index);
                            } else {
                              return Container();
                            }
                          });
                    }
                    return const CircularProgressIndicator();
                  }),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  moduleListView(
      bool darkModeOn, BuildContext context, List<dynamic> apiData, int index) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
          // ,
          color: darkModeOn ? null : Theme.of(context).cardColor,
          border: darkModeOn
              ? Border.all(color: Theme.of(context).cardColor)
              : null,
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  apiData[index]['prop_content']['name'].toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Spacer(),
              if (_tasks[index].status == DownloadTaskStatus.running) ...[
                const CircularProgressIndicator(),
              ] else if (_tasks[index].status ==
                  DownloadTaskStatus.complete) ...[
                IconButton(
                    onPressed: () async {
                      //get root status
                      bool? result = await Root.isRooted();

                      //get downloaded file name
                      String filename = await _getFilename(_tasks[index]);

                      //if root and file zip flash
                      final ezipFile =
                          File(_localPath.toString() + "/" + filename);
                      if (ezipFile.existsSync()) {
                        if (result == true) {
                          if (filename.lastChars(3) == "zip") {
                            _flashDialog(filename);
                          } else {
                            Fluttertoast.showToast(
                              msg: "The file is not .zip",
                            );
                          }
                        } else {
                          Fluttertoast.showToast(
                            msg: "You don't have root permission.",
                          );
                        }
                      } else {
                        Fluttertoast.showToast(
                          msg: "File not found. Try downloading again.",
                        );
                        _delete(_tasks[index]);
                      }
                    },
                    icon: const Icon(
                      Icons.flash_on_outlined,
                      color: Colors.orange,
                    )),
                IconButton(
                    onPressed: () {
                      _delete(_tasks[index]);
                    },
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    )),
              ] else ...[
                IconButton(
                  onPressed: () {
                    _requestDownload(_tasks[index]);
                  },
                  icon: const Icon(
                    Icons.download,
                    color: Colors.blue,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    /*moduleInfoSheet(
                                                  apiData, index, context);*/
                    var props = fetchProp(apiData[index]['notes_url']);

                    Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (context) => MarkdownPage(
                                  title: apiData[index]['id'],
                                  data: props,
                                )));
                  },
                  icon: const Icon(
                    Icons.info,
                    color: Colors.orange,
                  ),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  moduleCardView(
      bool darkModeOn, BuildContext context, List<dynamic> apiData, int index) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
          // ,
          color: darkModeOn ? null : Theme.of(context).cardColor,
          border: darkModeOn
              ? Border.all(color: Theme.of(context).cardColor)
              : null,
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            apiData[index]['prop_content']['name'].toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Created by " + apiData[index]['prop_content']['author'].toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          if (apiData[index]['prop_content']['description']
              .toString()
              .isNotEmpty) ...[
            Text(
              apiData[index]['prop_content']['description'].toString(),
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (_tasks[index].status == DownloadTaskStatus.running) ...[
                const CircularProgressIndicator(),
              ] else if (_tasks[index].status ==
                  DownloadTaskStatus.complete) ...[
                TextButton.icon(
                    onPressed: () async {
                      //get root status
                      bool? result = await Root.isRooted();

                      //get downloaded file name
                      String filename = await _getFilename(_tasks[index]);

                      //if root and file zip flash
                      final ezipFile =
                          File(_localPath.toString() + "/" + filename);
                      if (ezipFile.existsSync()) {
                        if (result == true) {
                          if (filename.lastChars(3) == "zip") {
                            _flashDialog(filename);
                          } else {
                            Fluttertoast.showToast(
                              msg: "The file is not .zip",
                            );
                          }
                        } else {
                          Fluttertoast.showToast(
                            msg: "You don't have root permission.",
                          );
                        }
                      } else {
                        Fluttertoast.showToast(
                          msg: "File not found. Try downloading again.",
                        );
                        _delete(_tasks[index]);
                      }
                    },
                    label: const Text(
                      "Install Module",
                      style: TextStyle(color: Colors.orange),
                    ),
                    icon: const Icon(
                      Icons.flash_on_outlined,
                      color: Colors.orange,
                    )),
                TextButton.icon(
                    onPressed: () {
                      _delete(_tasks[index]);
                    },
                    label: const Text(
                      "Delete File",
                      style: TextStyle(color: Colors.red),
                    ),
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    )),
              ] else ...[
                TextButton.icon(
                    onPressed: () {
                      _requestDownload(_tasks[index]);
                    },
                    icon: const Icon(
                      Icons.download,
                      color: Colors.blue,
                    ),
                    label: const Text(
                      "Download",
                      style: TextStyle(color: Colors.blue),
                    )),
                TextButton.icon(
                    onPressed: () {
                      /*moduleInfoSheet(
                                                  apiData, index, context);*/
                      var props = fetchProp(apiData[index]['notes_url']);

                      Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (context) => MarkdownPage(
                                    title: apiData[index]['id'],
                                    data: props,
                                  )));
                    },
                    icon: const Icon(
                      Icons.info,
                      color: Colors.orange,
                    ),
                    label: const Text(
                      "Info",
                      style: TextStyle(color: Colors.orange),
                    )),
              ]
            ],
          )
        ],
      ),
    );
  }

  _getFilename(_TaskInfo task) async {
    final tasks = await FlutterDownloader.loadTasksWithRawQuery(
        query: "SELECT * FROM task WHERE `task_id`='" +
            task.taskId.toString() +
            "'");

    String filename = "";
    for (var task in tasks!) {
      filename = task.filename.toString();
    }

    return filename.toString();
  }

  void _delete(_TaskInfo task) async {
    await FlutterDownloader.remove(
        taskId: task.taskId!, shouldDeleteContent: true);

    task.progress = 0;
    task.status = DownloadTaskStatus.undefined;

    await _prepare();
    setState(() {});
  }

  Future<bool> _checkPermission() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (widget.platform == TargetPlatform.android &&
        androidInfo.version.sdkInt <= 28) {
      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        if (result == PermissionStatus.granted) {
          return true;
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  void _requestDownload(_TaskInfo task) async {
    task.taskId = await FlutterDownloader.enqueue(
      url: task.link!,
      savedDir: _localPath,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true,
    );
  }

  Future<void> _retryRequestPermission() async {
    final hasGranted = await _checkPermission();

    if (hasGranted) {
      await _prepareSaveDir();
    }

    setState(() {
      _permissionReady = hasGranted;
    });
  }

  Future<void> _prepareSaveDir() async {
    _localPath = (await _findLocalPath())!;
    final savedDir = Directory(_localPath);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) {
      savedDir.create();
    }
  }

  Future<String?> _findLocalPath() async {
    String? externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = await AndroidPathProvider.downloadsPath;
      } catch (e) {
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    }
    return externalStorageDirPath;
  }

  Future<void> _flashDialog(filename) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        String resing = "";
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(resing == ""
                ? 'Do you want to Install?'
                : "Installation Output:"),
            actionsPadding: const EdgeInsets.all(0),
            buttonPadding: const EdgeInsets.all(0),
            contentPadding: const EdgeInsets.only(
                bottom: 12, left: 24.0, right: 24.0, top: 24.0),
            content: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    resing == ""
                        ? Text("Do you want to Install " + filename + " now?")
                        : Container(
                            color: Colors.black,
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              resing,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (resing == "") ...[
                          TextButton(
                            child: const Text('No Thanks'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: const Text('Install'),
                            onPressed: () async {
                              //delete old file
                              try {
                                final oldFile = File(_localPath.toString() +
                                    "/will_be_install.zip");
                                oldFile.delete();
                              } catch (e) {}

                              setState(() {
                                resing = "Extracting file from .zip...";
                              });

                              //extract zip
                              final ezipFile =
                                  File(_localPath.toString() + "/" + filename);
                              final destinationDir =
                                  Directory(_localPath.toString() + "/");
                              try {
                                await ZipFile.extractToDirectory(
                                    zipFile: ezipFile,
                                    destinationDir: destinationDir);

                                //delete zip
                                ezipFile.delete();
                              } catch (e) {}

                              setState(() {
                                resing = "Compressing the file as .zip...";
                              });

                              //zip
                              final dataDir = Directory(_localPath.toString() +
                                  "/" +
                                  filename.toString().replaceAll(".zip", ""));
                              try {
                                final zipFile = File(_localPath.toString() +
                                    "/will_be_install.zip");
                                await ZipFile.createFromDirectory(
                                    sourceDir: dataDir,
                                    zipFile: zipFile,
                                    includeBaseDirectory: false,
                                    recurseSubDirs: true);

                                //delete folder
                                dataDir.deleteSync(recursive: true);
                              } catch (e) {}

                              setState(() {
                                resing = "Installation Started...";
                              });

                              String? res = await Root.exec(
                                  cmd: "magisk --install-module " +
                                      _localPath.toString() +
                                      "/will_be_install.zip");
                              setState(() {
                                resing = res!;
                              });
                            },
                          ),
                        ] else ...[
                          TextButton(
                            child: const Text('Close'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: const Text('Reboot Device'),
                            onPressed: () async {
                              await Root.exec(cmd: "reboot");
                            },
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Map<String, dynamic> _readAndroidBuildData(AndroidDeviceInfo build) {
    return <String, dynamic>{
      'version.securityPatch': build.version.securityPatch,
      'version.sdkInt': build.version.sdkInt,
      'version.release': build.version.release,
      'version.previewSdkInt': build.version.previewSdkInt,
      'version.incremental': build.version.incremental,
      'version.codename': build.version.codename,
      'version.baseOS': build.version.baseOS,
      'board': build.board,
      'bootloader': build.bootloader,
      'brand': build.brand,
      'device': build.device,
      'display': build.display,
      'fingerprint': build.fingerprint,
      'hardware': build.hardware,
      'host': build.host,
      'id': build.id,
      'manufacturer': build.manufacturer,
      'model': build.model,
      'product': build.product,
      'supported32BitAbis': build.supported32BitAbis,
      'supported64BitAbis': build.supported64BitAbis,
      'supportedAbis': build.supportedAbis,
      'tags': build.tags,
      'type': build.type,
      'isPhysicalDevice': build.isPhysicalDevice,
      'androidId': build.androidId,
      'systemFeatures': build.systemFeatures,
    };
  }

  Future<void> _deviceDialog() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    Map<String, dynamic> deviceData = <String, dynamic>{};

    deviceData = _readAndroidBuildData(await deviceInfo.androidInfo);

    return showDialog<void>(
        context: context,
        barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Device Info"),
            content: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text("System Version\nAndroid " +
                        deviceData['version.release'].toString()),
                    const SizedBox(height: 15),
                    Text("API Level\n" +
                        deviceData['version.sdkInt'].toString()),
                    const SizedBox(height: 15),
                    Text("Device\n" + deviceData['model'].toString()),
                    const SizedBox(height: 15),
                    Text("System ABI\n" +
                        deviceData['supportedAbis'].toString()),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }
}

class _TaskInfo {
  String? name;
  final String? link;

  String? taskId;
  int? progress = 0;
  DownloadTaskStatus? status = DownloadTaskStatus.undefined;

  _TaskInfo({this.name, this.link});
}
