(function() {
  if (typeof UnicornStudio === 'undefined') {
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/gh/hiunicornstudio/unicornstudio.js@v2.2.1/dist/unicornStudio.umd.js';
    script.onload = function() {
      if (typeof UnicornStudio !== 'undefined') {
        UnicornStudio.init();
      }
    };
    document.body.appendChild(script);
  } else {
    UnicornStudio.init();
  }
})();
