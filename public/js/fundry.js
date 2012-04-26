/* fundry */

(function($) {
  var DepositValidator = function(sel, opts) {
    var el       = $(sel);
    var instance = this;
    var options  = opts || {};
    var gateway  = options.gateway || 'paypal';
    var fee      = parseFloat($('#' + gateway + '_fee').val());
    var cut      = parseFloat($('#' + gateway + '_cut').val()) / 100.0;
    var balloon  = $(options.balloon || ('#' + gateway + '_charges'));
    var type     = options.type || 'deposit';
    var cap      = parseFloat(options.cap) || 0;
    var method   = options.method || 'difference';

    var fees_container  = options.fees_container;
    var total_container = options.total_container;

    this.validate = function() {
      var amount;
      if (el.val().length) {
        amount = parseFloat(el.val());
        if (!isNaN(amount))
          return amount;
      }

      return 0;
    };

    this.gateway_charges = function(amount) {
      var charges = parseFloat(fee + cut * amount + (method == 'difference' ? 0 : (fee+cut*amount)*cut)).toFixed(2);
      return cap > 0 && charges > cap ? cap : charges;
    };

    this.money = function(amount) {
      var whole    = parseInt(amount);
      var fraction = ((parseFloat(amount) - whole)*100).toFixed(0);
      return (
        '<abbr class="money">' +
        '  <span class=symbol>$</span>' +
        '  <span class=whole>'    + whole    + '</span>' +
        '  <span class=fraction>.' + fraction + '</span>' +
        '  <span class=currency>USD</span>' +
        '</abbr>'
      );
    };

    this.watch = function() {
      el.keyup(function() {
        var amount  = parseFloat(instance.validate());
        var charges = parseFloat(instance.gateway_charges(amount));
        var gross   = method == 'difference' ? (amount-charges) : (amount+charges);

        if (amount <= 0) return;

        if (method == 'difference') {
          balloon.html(
            (options.who || gateway) + ' will charge a fee of upto $' + charges + ' on this transaction, ' +
            'which will reduce your ' + type + ' to $' + gross.toFixed(2) + '.'
          );
        }
        else {
          balloon.html(
            (options.who || gateway) + ' will charge a fee of upto $' + charges + ' on this transaction, ' +
            'which will increase your total ' + type + ' to $' + gross.toFixed(2) + '.'
          );
        }

        if (fees_container)  $(fees_container).html(instance.money(charges));
        if (total_container) $(total_container).html(instance.money(gross));
      });

      el.focusout(function(){
        var amount = parseFloat(instance.validate());
        el.val(amount.toFixed(2));
      });
    };
  };

  $.fn.validate_deposit = function(opts) {
    if (validator = $(this).data('validator'))
      return validator;
    else {
      var validator = new DepositValidator(this, opts);
      $(this).data('validator', validator);
      validator.watch();
      if (!$(this).val() || $(this).val().length == 0) {
        amount = parseFloat(opts.recommended) || 0.0;
        $(this).val(amount.toFixed(2));
      }
      $(this).keyup();
      return validator;
    }
  };
})(jQuery);


function flash(type, msg) {
  $('#content').prepend("<div class='" + type + "'><div class='flash-close'>X</div>" + msg + "</div>");
}


$(document).ready(function () {
  $('abbr.timeago').timeago();

  $('form#project').ready(function () {
    $('#project_name').NobleCount('#project_name_remaining',       {max_chars: 64,  on_negative: 'climit'});
    $('#project_summary').NobleCount('#project_summary_remaining', {max_chars: 128, on_negative: 'climit'});
  });

  $('form#feature').ready(function () {
    $('#feature_name').NobleCount('#feature_name_remaining', {max_chars: 64, on_negative: 'climit'});
  });

  $('#deposit_amount').ready(function() {
    $('#deposit_amount').validate_deposit({who: 'Paypal', gateway: 'paypal', recommended: 0});
  });

  // Toolbar.
  $('li.gridViewBtn a').click(function () {
    $('li.gridViewBtn').addClass('selected');
    $('li.listViewBtn').removeClass('selected');
    $('.outerPanel ul.listView').removeClass('listView').addClass('gridView');
    $.cookie('layout', 'grid', { path: '/' });
  });

  $('li.listViewBtn a').click(function () {
    $('li.listViewBtn').addClass('selected');
    $('li.gridViewBtn').removeClass('selected');
    $('.outerPanel ul.gridView').removeClass('gridView').addClass('listView');
    $.cookie('layout', 'list', { path: '/' });
  });

  var layout = $.cookie('layout');
  if (layout) $('li.' + layout + 'ViewBtn a').click();


  /*-----------------------------------------------------------------------------------------------
    Twitter - TODO make this into proper lazyload plugin.
  /----------------------------------------------------------------------------------------------*/

  function load_twitter() {
    var div_y = $("#twitter").offset().top;
    var win_y = $(window).scrollTop() + $(window).height();
    if (win_y >= div_y) {
      $(window).unbind('scroll');
      $("#twitter").getTwitter({
        userName:        "fundrydotcom",
        numTweets:       3,
        loaderText:      "Loading tweets...",
        slideIn:         false,
        slideDuration:   0,
        showHeading:     true,
        headingText:     "Latest Tweets",
        showProfileLink: true,
        showTimestamp:   true,
        ssl: document.location.toString().match(/^https:/)
      });
    }
  }

  $(window).scroll(load_twitter);
  $(window).scroll();

  $('textarea.resizable:not(.processed)').TextAreaResizer();

  $('.flash-close, .simplemodal-close').live('click', function() {
    $(this).closest('.success, .info, .error, .simplemodal-overlay').animate({
	    opacity: 'toggle',
	    height: 'toggle'
	  }, 500, function() {
	    // Animation complete.
	  });
  });

  $('#closeNote').click(function() {
    $('#note').animate({
	    opacity: 'toggle',
	    height: 'toggle'
	  }, 500, function() {
	    // Animation complete.
	  });
  });

  $('.basic').click(function (e) {
    $('#basic-modal-content').modal({minHeight: 375, overlayClose: true});
    return false;
  });

  $('#fundry-widget-modal').click(function (e) {
    load_widget();
    $('#basic-modal-content').modal({minHeight: 300, overlayClose: true});
    return false;
  });

  $('body .terms').click(function (e) {
    var el = $('#terms-modal');
    if (el.html().length > 0) {
      el.modal({overlayClose: true});
    }
    else {
      el.load('/terms-modal', function() { el.modal({overlayClose: true}); });
    }
    return false;
  });

  $('.markdownReference').live('click', function (e) {
    var el = $('#markdownReference-modal');
    if (el.html().length > 0) {
      el.modal({overlayClose: true});
    }
    else {
      el.load('/markdown-modal', function() { el.modal({overlayClose: true}); });
    }
    return false;
  });

  $('a.fundit, button, .userButton, .grnBtn, .grnBtn4, .button, .btn1, .btn2, .widgetButton')
    .css({backgroundPosition: "0 0"})
    .mouseover(function() { $(this).stop().animate({backgroundPosition:"(0 -110px)"}, {duration:250}) })
    .mouseout(function() { $(this).stop().animate({backgroundPosition:"(0 0)"}, {duration:250}) });

  $('#tweet-button a').click(function() {
    var url = $('#tweet-button a').attr('title');
    win = window.open(url, 'Twitter', 'menubar=0,width=' + 600 + ',height=' + 400);
    win.focus();
  });

  var showdown = new Showdown.converter();

  $('.markdown-input').live('keyup', function(e) {
    if($('.markdown-input').val().length > 0)
      $('.markdown-preview-container').show();
    $('.markdown-preview').html(showdown.makeHtml($(this).val()));
    // filter out img tags.
    $('.markdown-preview img').remove();
  });

  if($('.markdown-input').length > 0) {
    if($('.markdown-input').val().length > 0)
      $('.markdown-preview-container').show();
    $('.markdown-preview').html(showdown.makeHtml($('.markdown-input').val()));
    // filter out img tags.
    $('.markdown-preview img').remove();
    $('.markdown-input').bind('paste', function(e) {
      var el = $(this);
      setTimeout(function() {
        $('.markdown-preview').html(showdown.makeHtml(el.val()));
        // filter out img tags.
        $('.markdown-preview img').remove();
      }, 100);
    });
  }

  $('form.confirmsubmit').ready(function() {
    $('form.confirmsubmit button').click(function() {
      if(confirm('Submit changes ?')) {
        $(this).closest('form').submit();
      }
      return false;
    });
  });

  $('#similar .pledge-feature').click(function() {
    if (confirm('Are you sure ?')) {
      $('#similar form').submit();
    }
  });

  /*-----------------------------------------------------------------------------------------------
    User inbox UI
  /----------------------------------------------------------------------------------------------*/

  if($('#admin .toolbar').length > 0) {
    $('#admin .toolbar li').removeClass('selected');
    if (period.length > 0)
      $('#admin .toolbar li#' + period).addClass('selected');
    else
      $('#admin .toolbar li#all').addClass('selected');
  }


  $('.view-email').click(function(e) {
    var url = $(this).attr('href');
    $.ajax({
      url: url,
      success: function(data) {
        $.modal(data, {minHeight: 400, overlayClose: true});
      },
      error: function() {
        alert('Error loading data. Please try again later.');
      }
    });
    return false;
  });

  $('#inbox-list th input').click(function(e) {
    if ($('#inbox-list th input:checked').length) {
      $('#inbox-list input[name="email[]"]').attr('checked', true);
    }
    else {
      $('#inbox-list input[name="email[]"]').removeAttr('checked');
    }
  });

  $('.delete-email').click(function() {
    if ($('#inbox-list input[name="email[]"]:checked').length > 0) {
      if(confirm('Delete selected emails ?')) {
        $('#inbox-list').submit();
      }
    }
    return false;
  });

  $('.flag-abuse a').click(function() {
    return confirm('Flag this project ?') ? true : false;
  });

  /*-----------------------------------------------------------------------------------------------
    Hero slider.
  /----------------------------------------------------------------------------------------------*/

  var hero = $('#hero').scrollable({circular: true,  vertical: true})
                       .autoscroll({interval: 15000, autopause: false, autoplay: false})
                       .navigator().data('scrollable');

  if (hero) {
    $('.navi a').click(function(){ hero.pause(); });
    hero.play();
  }

  /*-----------------------------------------------------------------------------------------------
    Tipsy
  /----------------------------------------------------------------------------------------------*/

  $('.tipsie').each(function()   { $(this).tipsy({gravity: 'w'}); });
  $('.tipsie-e').each(function() { $(this).tipsy({gravity: 'e'}); });
  $('.tipsie-w').each(function() { $(this).tipsy({gravity: 'w'}); });
  $('.tipsie-n').each(function() { $(this).tipsy({gravity: 'n'}); });
  $('.tipsie-s').each(function() { $(this).tipsy({gravity: 's'}); });

  $('abbr.money').tipsy({gravity: 'e', html: true});

  /*-----------------------------------------------------------------------------------------------
    Formsy
  /----------------------------------------------------------------------------------------------*/

  $('.formsy').each(function() {
    if ($(this).attr('title').length > 0) $(this).formsy({gravity: 'w'});
  });

  $('#pledge_amount, #path_signup #user_username, #project_name, #feedback').focus();

  /*-----------------------------------------------------------------------------------------------
    Verification Admin UI
  /----------------------------------------------------------------------------------------------*/

  $('#verification #projects a.web').click(function() {
    var href = document.location.href;
    window.onbeforeunload = function() {
      return 'The page loaded is trying to rewrite document location and unload admin page';
    };
    $('#verification iframe').attr('src', $(this).attr('href'));
    return false;
  });

  $('#verification #projects a.approve').click(function() {
    var project = $(this).closest('li');
    var href = $(this).attr('href');
    if (confirm('Approve project as verified ?')) {
      $.ajax({
        url:  href,
        type: 'post',
        success: function() {
          $('.info, .error, .success').remove();
          flash('success', 'Approved ' + project.find('a:first').text());
          $.modal.close();
          project.remove();
        },
        error: function() {
          $('.info, .error, .success').remove();
          flash('error', 'Failed to update ' + project.find('a:first').text());
          $.modal.close();
        }
      });
      return false;
    }
    return false;
  });

  $('#verification #projects a.reject').click(function() {
    var project = $(this).closest('li');
    var form = $('#rejection form');
    form.attr('action', $(this).attr('href'));
    $.modal($('#rejection').html(), {minHeight: 250});
    $('#simplemodal-container form button').click(function() {
      var form = $('#simplemodal-container form');
      $.ajax({
        url:  form.attr('action'),
        data: form.serialize(),
        type: 'post',
        success: function() {
          $('.info, .error, .success').remove();
          flash('info', 'Updated ' + project.find('a:first').text());
          $.modal.close();
          project.remove();
        },
        error: function() {
          $('.info, .error, .success').remove();
          flash('error', 'Failed to update ' + project.find('a:first').text());
          $.modal.close();
        }
      });
      return false;
    });
    return false;
  });


  $('#retract_pledge button').click(function() {
    return confirm('Are you sure you wish to remove your support for this feature ?') ? true : false;
  });

  $('#alter_pledge button').click(function() {
    return confirm('Are you sure you wish to alter your pledge to this feature ?') ? true : false;
  });

  $('.verify-project a').click(function() {
    $(this).next().submit();
    return false;
  });

  /*-----------------------------------------------------------------------------------------------
    Combine signup and pledge/donate.
  /----------------------------------------------------------------------------------------------*/

  /* disabled temporarily
  var signup_focus = function() {
    $('#combined .signin:visible').animate({width: 0}, 200, 'linear', function() {
      $('#combined .signin').attr('style', 'border:0;display:none');
      $('#combined .signup').addClass('full');
      $('#combined .signup .hidden').slideDown(200);
    });
    $('#combined .signup').animate({width: '100%'}, 200, 'linear');
  };

  $('#combined .signup input').click(signup_focus);
  $('#combined .signup input').focus(signup_focus);
  */

  $('#combined .signin button').click(function() {
    var action = '/signin-' + $(this).closest('form').attr('action');
    $(this).closest('form').attr('action', action);
    return true;
  });

  $('#combined .signup button').click(function() {
    var action = '/signup-' + $(this).closest('form').attr('action');
    $(this).closest('form').attr('action', action);
    return true;
  });

  $('#anonymous-donation').click(function() {
    if (confirm('This will make your donation anonymous, proceed ?')) {
      $(this).closest('form').attr('action', '/anonymous-donation');
      return true;
    }
    return false;
  });

  $('input[name="donation[amount]"]').validate_deposit({
    who: 'Paypal',
    gateway: 'paypal',
    type: 'donation without signup',
    balloon: '#donation_charges',
    method: 'addition',
    fees_container: '#fees_container',
    total_container: '#total_container',
    recommended: 0
  });

  $('input[name="pledge[amount]"]').validate_deposit({
    who: 'Paypal',
    gateway: 'paypal',
    type: 'pledge',
    balloon: '#pledge_charges',
    method: 'addition',
    fees_container: '#fees_container',
    total_container: '#total_container',
    recommended: 0
  });

  $('#withdraw_amount').validate_deposit({
    who: 'Paypal',
    gateway: 'paypal',
    type: 'withdrawal',
    balloon: '#withdraw_charges',
    recommended: 0,
    cap: 50
  });
});

