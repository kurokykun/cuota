// ignore_for_file: prefer_const_constructors

import 'package:cuota/cntlm_confview.dart';
import 'package:cuota/controller.dart';
import 'package:cuota/profile_entity.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart' hide Colors;

class Profiless extends StatefulWidget {
  const Profiless({super.key});

  @override
  State<Profiless> createState() => _ProfilessState();
}

class _ProfilessState extends State<Profiless> {
  Controller controller = Get.find();
  int index = 0;

  refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: controller.load_profiles(),
      builder: (context, snapshot) {
        List<NavigationPaneItem> items =
            List.generate(controller.profile_list.length, (index) {
          return PaneItem(
              title: Text(controller.profile_list[index].name),
              trailing: Icon(FluentIcons.more),
              icon: Icon(FluentIcons.globe,
                  color:
                      controller.getIconColor(controller.profile_list[index])),
              body: CntlmConf(index: index, refresh: refresh));
        });
        return NavigationView(
          key: GlobalKey(),
          pane: NavigationPane(
            header: Text("data"),
            displayMode: PaneDisplayMode.compact,
            selected: index,
            items: items,
            onChanged: (value) {
              setState(() {
                index = value;
              });
            },
          ),
        );
      },
    );
  }
}
