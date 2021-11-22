import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownPage extends StatefulWidget {
  final Future data;
  final String title;

  const MarkdownPage({Key? key, required this.data, required this.title})
      : super(key: key);

  @override
  State<MarkdownPage> createState() => _MarkdownPageState();
}

class _MarkdownPageState extends State<MarkdownPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).backgroundColor,
          title: Text(widget.title,
              style: const TextStyle(
                color: Colors.black,
              )),
        ),
        body: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
          child: FutureBuilder(
              future: widget.data,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return SingleChildScrollView(
                    child: Container(
                      constraints: BoxConstraints(
                          maxHeight: double.parse(MediaQuery.of(context)
                                  .size
                                  .height
                                  .toString()) /
                              1.1),
                      child: buildMarkdown(snapshot.data.toString()),
                    ),
                  );
                } else {
                  return const CircularProgressIndicator();
                }
              }),
        ));
  }

  _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Widget buildMarkdown(data) => MarkdownWidget(
        data: data,
        styleConfig: StyleConfig(pConfig: PConfig(onLinkTap: (url) {
          _launchUrl(url!);
        })),
      );
}
