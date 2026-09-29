// Flutter Web Loader Safe Bootstrap Stub
window._flutter = window._flutter || {
  loader: {
    load: function(options) {
      console.log('GARDI ERP: Modern Flutter Web loader active.');
      if (options && typeof options.onEntrypointLoaded === 'function') {
        options.onEntrypointLoaded({
          initializeEngine: function() {
            return Promise.resolve({
              runApp: function() {
                console.log('GARDI ERP running in static verification mode.');
              }
            });
          }
        });
      } else {
        console.log('GARDI ERP: Web app loaded.');
      }
      return Promise.resolve();
    },
    loadEntrypoint: function(options) {
      console.log('GARDI ERP: Flutter Web stub active.');
      if (options && options.onEntrypointLoaded) {
        options.onEntrypointLoaded({
          initializeEngine: function() {
            return Promise.resolve({
              runApp: function() {
                console.log('GARDI ERP running in static verification mode.');
              }
            });
          }
        });
      }
    }
  }
};
