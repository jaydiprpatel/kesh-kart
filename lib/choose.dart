import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kesh_kart/commons.dart';
import 'package:kesh_kart/register.dart';

class Choose extends StatefulWidget {
  final String phoneNumber;
  final String userId;

  const Choose({super.key, required this.phoneNumber, required this.userId});

  @override
  State<Choose> createState() => _ChooseState();
}

class _ChooseState extends State<Choose> with SingleTickerProviderStateMixin {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        _opacity = 1.0;
      });
      // Timer(const Duration(seconds: 3), () {
      //   Navigator.of(context).push(slideUpRoute(LogInScreen()));
      // });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              opacity: _opacity,
              duration: Duration(seconds: 2),
              child: Text(
                'Who you are?',
                style: TextStyle(
                  fontFamily: 'Popins',
                  fontSize: 30,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // TODO: Navigate to Barber screen or register flow
                      debugPrint("Barber selected");
                      Navigator.of(context).push(
                        slideUpRoute(
                          RegisterScreen(
                            userId: widget.userId,
                            phoneNumber: widget.phoneNumber,
                            role: 'Barber',
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        AnimatedOpacity(
                          opacity: _opacity,
                          duration: Duration(seconds: 2),
                          child: Image.asset(
                            'assets/images/barber.png',
                            height: 200,
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedOpacity(
                          opacity: _opacity,
                          duration: Duration(seconds: 2),
                          child: Text(
                            'Barber',
                            style: TextStyle(
                              fontFamily: 'Popins',
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      // TODO: Navigate to Barber screen or register flow
                      debugPrint("Customer selected");
                      Navigator.of(context).push(
                        slideUpRoute(
                          RegisterScreen(
                            userId: widget.userId,
                            phoneNumber: widget.phoneNumber,
                            role: 'Customer',
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        AnimatedOpacity(
                          opacity: _opacity,
                          duration: Duration(seconds: 2),
                          child: Image.asset(
                            'assets/images/customer.png',
                            height: 200,
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedOpacity(
                          opacity: _opacity,
                          duration: Duration(seconds: 2),
                          child: Text(
                            'Customer',
                            style: TextStyle(
                              fontFamily: 'Popins',
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
