// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' hide Colors, IconButton, ButtonStyle;

class CntlmConf extends StatefulWidget {
  const CntlmConf({super.key});

  @override
  State<CntlmConf> createState() => _CntlmConfState();
}

bool checked = false;

class _CntlmConfState extends State<CntlmConf> {
  @override
  Widget build(BuildContext context) {
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
                  Expanded(
                      child: SizedBox(
                    child: TextField(
                      minLines: 4,
                      maxLines: 20,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Exclusiones',
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
