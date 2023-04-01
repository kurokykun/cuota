// ignore_for_file: prefer_const_constructors

import 'package:cuota/cntlm_confview.dart';
import 'package:cuota/controller.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Card;
import 'package:get/get.dart';
import 'package:flutter/material.dart'
    hide Colors, IconButton, showDialog, FilledButton;

class Profiless extends StatefulWidget {
  const Profiless({super.key});

  @override
  State<Profiless> createState() => _ProfilessState();
}

class _ProfilessState extends State<Profiless> {
  Controller controller = Get.find();
  TextEditingController new_profile = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int index = 0;

  refresh() {
    setState(() {});
  }

  void showCreate(BuildContext context) async {
    new_profile.text = "Perfil nuevo";
    final result = await showDialog(
        barrierDismissible: true,
        context: context,
        builder: (context) => ContentDialog(
              actions: [
                Button(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.pop(context, 'User canceled dialog');
                  },
                ),
                FilledButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await controller.create_profile(new_profile.text);
                      Navigator.pop(context, 'User canceled dialog');
                      setState(() {});
                    }
                  },
                  child: Text('Aceptar'),
                )
              ],
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
              title: Text("Crear nuevo perfil"),
              content: Card(
                child: Form(
                    key: _formKey,
                    child: TextFormField(
                      autovalidateMode: AutovalidateMode.always,
                      validator: (value) {
                        if ((value == null || value.isEmpty)) {
                          return '';
                        } else {
                          return null;
                        }
                      },
                      controller: new_profile,
                      decoration: InputDecoration(
                        errorStyle: TextStyle(height: 0),
                        border: OutlineInputBorder(),
                        labelText: 'Nombre',
                      ),
                    )),
              ),
            ));
  }

  void showDelete(BuildContext context) async {
    final result = await showDialog(
        barrierDismissible: true,
        context: context,
        builder: (context) => ContentDialog(
              actions: [
                Button(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.pop(context, 'User canceled dialog');
                  },
                ),
                FilledButton(
                  onPressed: () async {
                    await controller.delete_profile(index);
                    setState(() {});
                    Navigator.pop(context, 'User canceled dialog');
                  },
                  child: Text('Aceptar'),
                )
              ],
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
              title: Text("Eliminar Perfil"),
              content: Text("Desea eliminar este perfil proxy?"),
            ));
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
              trailing: IconButton(
                icon: Icon(FluentIcons.delete),
                onPressed: () async {
                  showDelete(context);
                },
              ),
              icon: Icon(FluentIcons.globe,
                  color:
                      controller.getIconColor(controller.profile_list[index])),
              body: CntlmConf(index: index, refresh: refresh));
        });
        return NavigationView(
          key: GlobalKey(),
          pane: NavigationPane(
            displayMode: PaneDisplayMode.compact,
            selected: index,
            items: items,
            footerItems: [
              PaneItem(
                title: Text("Agregar perfil"),
                icon: Icon(FluentIcons.add),
                body: Container(),
                onTap: () {
                  if (!controller.is_running) {
                    showCreate(context);
                  } else {
                    displayInfoBar(context, builder: (context, close) {
                      return InfoBar(
                        title: const Text('Primero debe detener el proxy'),
                        action: IconButton(
                          icon: const Icon(
                            FluentIcons.clear,
                            size: 8,
                          ),
                          onPressed: close,
                        ),
                        severity: InfoBarSeverity.error,
                      );
                    });
                  }
                },
              )
            ],
            onChanged: (value) {
              if (value != items.length && !controller.is_running) {
                controller.cuota_actual.value = 0;
                controller.cuota_utilizada.value = 0;
                controller.percent.value = 0;
                setState(() {
                  index = value;
                });
              } else if (value != items.length) {
                displayInfoBar(context, builder: (context, close) {
                  return InfoBar(
                    title: const Text('Primero debe detener el proxy'),
                    action: IconButton(
                      icon: const Icon(
                        FluentIcons.clear,
                        size: 8,
                      ),
                      onPressed: close,
                    ),
                    severity: InfoBarSeverity.error,
                  );
                });
              }
            },
          ),
        );
      },
    );
  }
}
