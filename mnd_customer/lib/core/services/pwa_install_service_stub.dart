/// Non-web stub — PWA install APIs are unavailable.
bool isPwaStandalone() => false;

bool canPromptPwaInstall() => false;

Future<bool> promptPwaInstall() async => false;
