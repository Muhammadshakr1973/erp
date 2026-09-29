// Flutter Web Loader Safe Bootstrap Stub
window._flutter = window._flutter || {};
window._flutter.buildConfig = window._flutter.buildConfig || {
  builds: [
    {
      compileTarget: 'dart2js',
      renderer: 'canvaskit',
      mainImport: 'main.dart.js'
    }
  ]
};

if (!window._flutter.loader) {
  window._flutter.loader = {
    load: function(options) {
      console.log('GARDI ERP: Modern Flutter Web loader active.');
      if (options && typeof options.onEntrypointLoaded === 'function') {
        options.onEntrypointLoaded({
          initializeEngine: function() {
            return Promise.resolve({
              runApp: function() {
                console.log('GARDI ERP running.');
              }
            });
          }
        });
      }
      return Promise.resolve();
    },
    loadEntrypoint: function(options) {
      console.log('GARDI ERP: Flutter Web loader fallback active.');
      if (options && typeof options.onEntrypointLoaded === 'function') {
        options.onEntrypointLoaded({
          initializeEngine: function() {
            return Promise.resolve({
              runApp: function() {
                console.log('GARDI ERP running.');
              }
            });
          }
        });
      }
      return Promise.resolve();
    }
  };
}
