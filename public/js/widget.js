/* fundry widget */

(function  () {
  if (typeof(Fundry) == 'undefined') Fundry = {};

  Fundry.Widget = function (content_url, options) {
    var defaults = {width: 300, height: 200};
    if (!options) options = {};
    for (i in defaults) {
      if (typeof(options[i]) == 'undefined') options[i] = defaults[i];
    }

    var position = false;
    var scripts  = document.getElementsByTagName('script');
    for (var i = 0; i < scripts.length; i++) {
      if (scripts[i].src.match(/widget.js/)) {
        position = scripts[i].parentNode;
        break;
      }
    }

    var container         = document.createElement('iframe');
    container.id          = options.id || 'fundry_widget';
    container.scrolling   = 'no';
    container.width       = options.width;
    container.height      = options.height;
    container.border      = 0;
    container.frameBorder = 0;
    container.src         = content_url;

    if (position && !document.getElementById(container.id)) position.appendChild(container);
  }
})();

