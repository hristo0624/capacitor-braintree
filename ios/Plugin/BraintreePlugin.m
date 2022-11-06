#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(BraintreePlugin, "Braintree",
           CAP_PLUGIN_METHOD(getDeviceData, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(setToken, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(showDropIn, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(getRecentMethods, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(showApplePay, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(getTickets, CAPPluginReturnPromise);
)
