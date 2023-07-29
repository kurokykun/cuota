// ignore_for_file: prefer_const_constructors

import 'package:cuota/cntlm_confview.dart';
import 'package:cuota/controller.dart';
import 'package:cuota/user_entity.dart';
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
  TextEditingController usuario_controller = TextEditingController();
  TextEditingController actual_controller = TextEditingController();
  TextEditingController nueva_controller = TextEditingController();
  TextEditingController confirmar_controller = TextEditingController();
  final profileFormKey = GlobalKey<FormState>();
  final changePassFormKey = GlobalKey<FormState>();
  var index = 0;
  refresh() {
    setState(() {});
  }

  void showChangePass(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => ContentDialog(
        actions: [
          Button(
            child: const Text('Cancelar'),
            onPressed: () {
              Navigator.pop(context);
              usuario_controller.text = "";
              actual_controller.text = "";
              nueva_controller.text = "";
              confirmar_controller.text = "";
            },
          ),
          FilledButton(
            onPressed: () async {
              if (changePassFormKey.currentState!.validate()) {
                var state = await controller.change_pass(User(
                    usuario_controller.text,
                    actual_controller.text,
                    nueva_controller.text,
                    confirmar_controller.text));
                Navigator.pop(context);
                setState(() {});
                usuario_controller.text = "";
                actual_controller.text = "";
                nueva_controller.text = "";
                confirmar_controller.text = "";
                if (state.statusCode == 200) {
                  displayInfoBar(context, builder: (context, close) {
                    return InfoBar(
                      title:
                          const Text('Contraseña cambiada satisfactoriamente'),
                      action: IconButton(
                        icon: const Icon(
                          FluentIcons.clear,
                          size: 8,
                        ),
                        onPressed: close,
                      ),
                      severity: InfoBarSeverity.success,
                    );
                  });
                } else {
                  displayInfoBar(context, builder: (context, close) {
                    return InfoBar(
                      title: const Text(
                          'Ha ocurrido un error durante el cambio de contraseña'),
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
              }
            },
            child: Text('Aceptar'),
          )
        ],
        constraints: const BoxConstraints(maxHeight: 340, maxWidth: 300),
        title: Text("Cambiar contraseña"),
        content: Scaffold(
          body: Form(
              key: changePassFormKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: SizedBox(
                        height: 40,
                        child: TextFormField(
                          enabled: true,
                          controller: usuario_controller,
                          decoration: InputDecoration(
                            errorStyle: TextStyle(height: 0),
                            prefixIcon: Icon(
                              FluentIcons.people,
                              size: 18,
                            ),
                            border: OutlineInputBorder(),
                            labelText: 'Usuario',
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value!.isEmpty) {
                              return '';
                            }
                            return null;
                          },
                        ),
                      )),
                    ],
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: SizedBox(
                        height: 40,
                        child: TextFormField(
                          controller: actual_controller,
                          enabled: true,
                          decoration: InputDecoration(
                            errorStyle: TextStyle(height: 0),
                            prefixIcon: Icon(
                              FluentIcons.lock,
                              size: 18,
                            ),
                            border: OutlineInputBorder(),
                            labelText: 'Actual',
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value!.isEmpty) {
                              return '';
                            }
                            return null;
                          },
                          obscureText: true,
                        ),
                      )),
                    ],
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: SizedBox(
                        height: 40,
                        child: TextFormField(
                          controller: nueva_controller,
                          enabled: true,
                          obscureText: true,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            var val_exp = RegExp(
                                r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
                            if (!val_exp.hasMatch(value!)) {
                              return '';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            errorStyle: TextStyle(height: 0),
                            prefixIcon: Icon(
                              FluentIcons.password_field,
                              size: 18,
                            ),
                            border: OutlineInputBorder(),
                            labelText: 'Nueva',
                          ),
                        ),
                      )),
                    ],
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: SizedBox(
                        height: 40,
                        child: TextFormField(
                          enabled: true,
                          controller: confirmar_controller,
                          decoration: InputDecoration(
                            errorStyle: TextStyle(height: 0),
                            prefixIcon: Icon(
                              FluentIcons.password_field,
                              size: 18,
                            ),
                            border: OutlineInputBorder(),
                            labelText: 'Confirmar',
                          ),
                          obscureText: true,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            var val_exp = RegExp(
                                r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
                            if (!val_exp.hasMatch(value!)) {
                              return '';
                            }
                            if (value != nueva_controller.text) {
                              return '';
                            }
                            return null;
                          },
                        ),
                      )),
                    ],
                  )
                ],
              )),
        ),
      ),
    );
  }

  void showCreate(BuildContext context) async {
    new_profile.text = "Perfil nuevo";
    await showDialog(
        barrierDismissible: true,
        context: context,
        builder: (context) => ContentDialog(
              actions: [
                Button(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                FilledButton(
                  onPressed: () async {
                    if (profileFormKey.currentState!.validate()) {
                      await controller.create_profile(new_profile.text);
                      Navigator.pop(context);
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
                    key: profileFormKey,
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
    await showDialog(
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
                    setState(() {
                      if (index > 0) index--;
                    });
                    Navigator.pop(context);
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
              icon: Icon(FluentIcons.globe,
                  color:
                      controller.getIconColor(controller.profile_list[index])),
              body: CntlmConf(index: index, refresh: refresh));
        });
        return NavigationView(
          key: GlobalKey(),
          pane: NavigationPane(
            displayMode: PaneDisplayMode.compact,
            selected: controller.file_list.length == 0 ? null : index,
            items: items,
            footerItems: [
              PaneItem(
                enabled: !controller.is_empty.value,
                icon: Icon(FluentIcons.delete),
                title: Text("Eliminar Perfil"),
                body: Container(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.globe,
                          size: 35,
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        Text(
                          textAlign: TextAlign.center,
                          "Ningún perfil proxy creado actualmente,cree uno nuevo haciendo clic en el boton agregar",
                          style: TextStyle(
                            fontWeight: FontWeight.w300,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                onTap: controller.is_empty.value
                    ? null
                    : () {
                        if (!controller.is_running) {
                          showDelete(context);
                        } else {
                          displayInfoBar(context, builder: (context, close) {
                            return InfoBar(
                              title:
                                  const Text('Primero debe detener el proxy'),
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
              PaneItem(
                icon: Icon(FluentIcons.lock),
                title: Text("Cambiar contraseña"),
                body: Container(),
                onTap: () {
                  if (!controller.is_running) {
                    showChangePass(context);
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
              ),
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
              if (value < items.length && !controller.is_running) {
                controller.cuota_actual.value = 0;
                controller.cuota_utilizada.value = 0;
                controller.percent.value = 0;
                setState(() {
                  index = value;
                });
              } else if (value < items.length) {
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
