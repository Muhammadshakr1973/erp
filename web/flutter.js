// Flutter Web Loader Safe Bootstrap Stub
window._flutter = window._flutter || {
  loader: {
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
