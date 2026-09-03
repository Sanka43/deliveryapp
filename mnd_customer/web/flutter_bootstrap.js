{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      // Chromium CanvasKit is smaller than the full variant.
      canvasKitVariant: 'chromium',
    });
    await appRunner.runApp();
  },
});
