var capacitorBraintree = (function (exports, core) {
    'use strict';

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
        showApplePay(options) {
            return this.showApplePay(options);
        }
        getTickets(options) {
            return this.getTickets(options);
        }
    }

    var web = /*#__PURE__*/Object.freeze({
        __proto__: null,
        BraintreeWeb: BraintreeWeb
    });

    exports.Braintree = Braintree;

    Object.defineProperty(exports, '__esModule', { value: true });

    return exports;

})({}, capacitorExports);
//# sourceMappingURL=plugin.js.map
