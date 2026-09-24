window.openKeshKartRazorpayCheckout = function (optionsJson) {
  return new Promise(function (resolve, reject) {
    if (typeof Razorpay === 'undefined') {
      reject(new Error('Razorpay Checkout could not be loaded.'));
      return;
    }

    var options = JSON.parse(optionsJson);
    var settled = false;
    options.handler = function (response) {
      settled = true;
      resolve(JSON.stringify(response));
    };
    options.modal = Object.assign({}, options.modal || {}, {
      ondismiss: function () {
        if (!settled) {
          reject(new Error('Payment window closed.'));
        }
      },
    });

    var checkout = new Razorpay(options);
    checkout.on('payment.failed', function (response) {
      if (!settled) {
        var detail = response && response.error && (
          response.error.description || response.error.reason
        );
        reject(new Error(detail || 'Razorpay payment failed.'));
      }
    });
    checkout.open();
  });
};
