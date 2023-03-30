// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:cuota/controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart'
    hide Colors, IconButton, ButtonStyle, showDialog, FilledButton;
import 'package:get/get.dart';

class CntlmConf extends StatefulWidget {
  int index;
  Function refresh;
  CntlmConf({super.key, required this.index, required this.refresh});

  @override
  State<CntlmConf> createState() => _CntlmConfState();
}

bool checked = false;

class _CntlmConfState extends State<CntlmConf> {
  Controller controller = Get.find();
  TextEditingController usuario = TextEditingController();
  TextEditingController pass = TextEditingController();
  TextEditingController servidor = TextEditingController();
  TextEditingController puerto_servidor = TextEditingController();
  TextEditingController local = TextEditingController();
  TextEditingController puerto_local = TextEditingController();
  TextEditingController dominio = TextEditingController();
  TextEditingController exclusiones = TextEditingController();
  @override
  Widget build(BuildContext context) {
    usuario.text = controller.profile_list[widget.index].usser;
    pass.text = controller.profile_list[widget.index].pass;
    servidor.text = controller.profile_list[widget.index].upstreamProxy;
    puerto_servidor.text =
        controller.profile_list[widget.index].upstreamProxyPort;
    local.text = controller.profile_list[widget.index].localProxy;
    puerto_local.text = controller.profile_list[widget.index].localPort;
    dominio.text = controller.profile_list[widget.index].domain;
    String excludeList = "";
    for (String element in controller.profile_list[widget.index].noProxy) {
      excludeList += element + "\n";
    }
    exclusiones.text = excludeList;
    void showColorPicker(BuildContext context) async {
      final result = await showDialog(
          barrierDismissible: true,
          context: context,
          builder: (context) => ContentDialog(
                constraints:
                    const BoxConstraints(maxHeight: 200, maxWidth: 300),
                title: Text("Color del perfil"),
                content: Wrap(
                  runSpacing: 10.0,
                  spacing: 8.0,
                  children: Colors.accentColors.map((color) {
                    return Button(
                      style: ButtonStyle(
                        padding: ButtonState.all(
                          EdgeInsets.all(4.0),
                        ),
                      ),
                      onPressed: () {
                        print(color);
                        controller.setIconColor(color, widget.index);
                        setState(() {});
                        widget.refresh();
                        Navigator.of(context).pop(color);
                      },
                      child: Container(
                        height: 40.0,
                        width: 40.0,
                        color: color,
                      ),
                    );
                  }).toList(),
                ),
              ));
    }

    return Scaffold(
        floatingActionButton: FloatingActionButton(
            backgroundColor:
                controller.getIconColor(controller.profile_list[widget.index]),
            child: Icon(FluentIcons.plug_disconnected),
            onPressed: () {
              controller.test();
            }),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          color: controller.getIconColor(
                              controller.profile_list[widget.index])),
                      child: IconButton(
                          onPressed: () => showColorPicker(context),
                          style: ButtonStyle(
                              shape: ButtonState.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18.0),
                            ),
                          )),
                          icon: Icon(
                            FluentIcons.globe,
                            size: 40,
                          )),
                    ),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Expanded(
                      child: Column(
                    children: [
                      SizedBox(
                        height: 40,
                        child: TextFormField(
                          controller: usuario,
                          decoration: InputDecoration(
                            errorStyle: TextStyle(height: 0),
                            prefixIcon: Icon(
                              FluentIcons.people,
                              size: 18,
                            ),
                            border: OutlineInputBorder(),
                            labelText: 'Usuario',
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: pass,
                          obscureText: true,
                          decoration: InputDecoration(
                            errorStyle: TextStyle(height: 0),
                            prefixIcon: Icon(
                              FluentIcons.password_field,
                              size: 18,
                            ),
                            border: OutlineInputBorder(),
                            labelText: 'Contraseña',
                          ),
                        ),
                      )
                    ],
                  )),
                ],
              ),
              SizedBox(
                height: 28,
              ),
              Row(
                children: [
                  Expanded(
                      child: SizedBox(
                    height: 40,
                    child: TextFormField(
                      autovalidateMode: AutovalidateMode.always,
                      validator: (value) {
                        RegExp exp = RegExp(
                            r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}');
                        if ((value == null || value.isEmpty) ||
                            !exp.hasMatch(value)) {
                          return '';
                        }
                        return null;
                      },
                      controller: servidor,
                      decoration: InputDecoration(
                        errorStyle: TextStyle(height: 0),
                        border: OutlineInputBorder(),
                        labelText: 'Servidor remoto',
                      ),
                    ),
                  )),
                  SizedBox(
                    width: 8,
                  ),
                  SizedBox(
                      height: 40,
                      width: 80,
                      child: TextFormField(
                        autovalidateMode: AutovalidateMode.always,
                        maxLength: 4,
                        validator: (value) {
                          RegExp exp = RegExp(
                              r'^((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([0-5]{0,5})|([0-9]{1,4}))$');
                          if ((value == null || value.isEmpty) ||
                              !exp.hasMatch(value)) {
                            return '';
                          }
                          return null;
                        },
                        controller: puerto_servidor,
                        decoration: InputDecoration(
                          counterText: '',
                          errorStyle: TextStyle(height: 0),
                          border: OutlineInputBorder(),
                          labelText: 'Puerto',
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
                      autovalidateMode: AutovalidateMode.always,
                      validator: (value) {
                        RegExp exp = RegExp(
                            r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');
                        if (value == null ||
                            value.isEmpty ||
                            !exp.hasMatch(value)) {
                          return '';
                        }
                        return null;
                      },
                      controller: local,
                      decoration: InputDecoration(
                        errorStyle: TextStyle(height: 0),
                        border: OutlineInputBorder(),
                        labelText: 'Servidor local',
                      ),
                    ),
                  )),
                  SizedBox(
                    width: 8,
                  ),
                  SizedBox(
                      height: 40,
                      width: 80,
                      child: TextFormField(
                        autovalidateMode: AutovalidateMode.always,
                        validator: (value) {
                          RegExp exp = RegExp(
                              r'^((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([0-5]{0,5})|([0-9]{1,4}))$');
                          if ((value == null || value.isEmpty) ||
                              !exp.hasMatch(value)) {
                            return '';
                          }
                          return null;
                        },
                        controller: puerto_local,
                        decoration: InputDecoration(
                          errorStyle: TextStyle(height: 0),
                          border: OutlineInputBorder(),
                          labelText: 'Puerto',
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
                    child: TextField(
                      controller: dominio,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Dominio',
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
                  SizedBox(
                    width: 300,
                    height: 100,
                    child: TextField(
                      controller: exclusiones,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Exclusiones',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 8,
              ),
              Row(
                children: [
                  ToggleSwitch(
                    checked: checked,
                    content: Text('Modo Gateway'),
                    onChanged: (value) {
                      setState(() {
                        checked = value;
                      });
                    },
                  )
                ],
              ),
              SizedBox(
                height: 16,
              ),
              Row(
                children: [
                  Expanded(child: ProgressBar(value: 60)),
                ],
              ),
              SizedBox(
                height: 16,
              ),
              Text(
                "60 / 100 Mb",
                style: TextStyle(fontFamily: "ds-digital", fontSize: 32),
              )
            ],
          ),
        ));
  }
}
