import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/widgets/logout_action_button.dart';

class RiderHomePage extends StatelessWidget {
  const RiderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider'),
        actions: const <Widget>[
          LogoutActionButton(),
        ],
      ),
      body: const Center(child: Text('Rider module home')),
    );
  }
}
