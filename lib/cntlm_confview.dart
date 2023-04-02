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

class _CntlmConfState extends State<CntlmConf>
    with SingleTickerProviderStateMixin {
  Controller controller = Get.find();
  TextEditingController usuario = TextEditingController();
  TextEditingController pass = TextEditingController();
  TextEditingController servidor = TextEditingController();
  TextEditingController puerto_servidor = TextEditingController();
  TextEditingController local = TextEditingController();
  TextEditingController puerto_local = TextEditingController();
  TextEditingController dominio = TextEditingController();
  TextEditingController exclusiones = TextEditingController();
  bool enabled = true;
  final _formKey = GlobalKey<FormState>();

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
        key: GlobalKey<ScaffoldMessengerState>(),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
              backgroundColor: controller
                  .getIconColor(controller.profile_list[widget.index]),
              child: !controller.is_running
                  ? Icon(FluentIcons.play)
                  : Icon(FluentIcons.stop),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  if (!controller.is_running) {
                    controller.save_profile(
                        widget.index,
                        usuario,
                        pass,
                        servidor,
                        puerto_servidor,
                        local,
                        puerto_local,
                        dominio,
                        exclusiones);
                    displayInfoBar(context, builder: (context, close) {
                      return InfoBar(
                        title: const Text('Proxy iniciado correctamente'),
                        action: IconButton(
                          icon: const Icon(
                            FluentIcons.clear,
                            size: 8,
                          ),
                          onPressed: close,
                        ),
                        severity: InfoBarSeverity.info,
                      );
                    });
                    controller.is_running = !controller.is_running;
                    controller.get_cuota(widget.index);
                    controller.check_cuota_timer(widget.index);
                    controller.run_cntlm(widget.index);
                  } else {
                    controller.stop_cuota_timer();
                    controller.process_cntlm.kill();
                    displayInfoBar(context, builder: (context, close) {
                      return InfoBar(
                        title: const Text('Proxy detenido correctamente'),
                        action: IconButton(
                          icon: const Icon(
                            FluentIcons.clear,
                            size: 8,
                          ),
                          onPressed: close,
                        ),
                        severity: InfoBarSeverity.info,
                      );
                    });
                    controller.is_running = !controller.is_running;
                  }
                  setState(() {
                    enabled = !enabled;
                  });
                } else {
                  displayInfoBar(context, builder: (context, close) {
                    return InfoBar(
                      title: const Text('Datos incorrectos'),
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
              }),
        ),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20)),
                              color: controller.getIconColor(
                                  controller.profile_list[widget.index])),
                          child: IconButton(
                              onPressed: () => controller.is_running
                                  ? null
                                  : showColorPicker(context),
                              style: ButtonStyle(
                                  shape:
                                      ButtonState.all<RoundedRectangleBorder>(
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
                              enabled: enabled,
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
                              enabled: enabled,
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
                          enabled: enabled,
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
                            enabled: enabled,
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
                          enabled: enabled,
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
                            enabled: enabled,
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
                          enabled: enabled,
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
                          enabled: enabled,
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
                        onChanged: !controller.is_running
                            ? (value) {
                                setState(() {
                                  checked = value;
                                });
                              }
                            : null,
                      )
                    ],
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: Obx(() => ProgressBar(
                                value: double.parse(controller.percent.value
                                        .toStringAsFixed(2)) *
                                    100,
                              )))
                    ],
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  Obx(() => Text(
                        "${controller.cuota_utilizada} / ${controller.cuota_actual}",
                        style:
                            TextStyle(fontFamily: "ds-digital", fontSize: 32),
                      ))
                ],
              )),
        ));
  }
}
