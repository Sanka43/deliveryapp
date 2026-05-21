import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/widgets/logout_action_button.dart';

class VendorHomePage extends StatelessWidget {
  const VendorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor'),
        actions: const <Widget>[
          LogoutActionButton(),
        ],
      ),
      body: const Center(child: Text('Vendor module home')),
    );
  }
}
