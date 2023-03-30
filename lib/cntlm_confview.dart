// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:cuota/controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' hide Colors, IconButton, ButtonStyle;
import 'package:get/get.dart';

class CntlmConf extends StatefulWidget {
  int index;
  CntlmConf({super.key, required this.index});

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

    return Scaffold(
        floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blue,
            child: Icon(FluentIcons.play_solid),
            onPressed: () {}),
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
                          color: Colors.blue),
                      child: IconButton(
                          onPressed: () {},
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
                        child: TextField(
                          controller: usuario,
                          decoration: InputDecoration(
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
                    child: TextField(
                      controller: servidor,
                      decoration: InputDecoration(
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
                      child: TextField(
                        controller: puerto_servidor,
                        decoration: InputDecoration(
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
                      controller: local,
                      decoration: InputDecoration(
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
                      child: TextField(
                        controller: puerto_local,
                        decoration: InputDecoration(
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
