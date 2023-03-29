// ignore_for_file: prefer_const_constructors

import 'package:cuota/profiles.dart';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Colors;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
        iconNormal: Color.fromARGB(255, 71, 112, 223),
        mouseOver: const Color(0xFFF6A00C),
        mouseDown: const Color(0xFF805306),
        iconMouseOver: const Color(0xFF805306),
        iconMouseDown: const Color(0xFFFFD500));

    final closeButtonColors = WindowButtonColors(
        mouseOver: const Color(0xFFD32F2F),
        mouseDown: const Color(0xFFB71C1C),
        iconNormal: Color.fromARGB(255, 190, 124, 9),
        iconMouseOver: Colors.white);

    return Scaffold(
      body: WindowBorder(
        color: Color.fromARGB(255, 44, 44, 44),
        width: 1,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromARGB(255, 44, 44, 44),
                        Color.fromARGB(255, 44, 44, 44),
                      ],
                      stops: [
                        0.0,
                        1.0
                      ]),
                ),
                child: Column(children: [
                  WindowTitleBarBox(
                    child: Row(
                      children: [
                        Expanded(child: MoveWindow()),
                        Row(
                          children: [
                            MinimizeWindowButton(colors: buttonColors),
                            CloseWindowButton(colors: closeButtonColors),
                          ],
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Profiless(),
                  )
                ]),
              ),
            )
          ],
        ),
      ),
    );
  }
}
