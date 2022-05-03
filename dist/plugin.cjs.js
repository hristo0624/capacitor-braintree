'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@capacitor/core');

const Braintree = core.registerPlugin('Braintree', {
    web: () => Promise.resolve().then(function () { return web; }).then(m => new m.BraintreeWeb()),
});

class BraintreeWeb extends core.WebPlugin {
    setToken(options) {
        return this.setToken(options);
    }
    showDropIn(options) {
        return this.showDropIn(options);
    }
    getDeviceData(options) {
        return this.getDeviceData(options);
    }
    getRecentMethods(options) {
        return this.getRecentMethods(options);
    }
    showAppleGooglePay(options) {
        return this.showAppleGooglePay(options);
    }
}

var web = /*#__PURE__*/Object.freeze({
    __proto__: null,
    BraintreeWeb: BraintreeWeb
});

exports.Braintree = Braintree;
//# sourceMappingURL=plugin.cjs.js.map
