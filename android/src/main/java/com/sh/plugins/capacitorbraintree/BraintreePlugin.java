package com.sh.plugins.capacitorbraintree;

import android.content.Intent;
import android.app.Activity;
import android.os.Parcelable;
import android.util.Log;

import androidx.activity.result.ActivityResult;

import com.braintreepayments.api.BraintreeFragment;
import com.braintreepayments.api.DataCollector;
import com.braintreepayments.api.dropin.utils.PaymentMethodType;
import com.braintreepayments.api.exceptions.InvalidArgumentException;
import com.braintreepayments.api.interfaces.BraintreeResponseListener;
import com.braintreepayments.api.models.CardNonce;
import com.braintreepayments.api.models.PayPalAccountNonce;
import com.braintreepayments.api.models.GooglePaymentRequest;
import com.braintreepayments.api.models.GooglePaymentCardNonce;
import com.braintreepayments.api.models.PostalAddress;
import com.braintreepayments.api.models.ThreeDSecureInfo;
import com.braintreepayments.api.models.ThreeDSecurePostalAddress;
import com.braintreepayments.api.models.ThreeDSecureRequest;
import com.braintreepayments.api.models.ThreeDSecureAdditionalInformation;
import com.braintreepayments.api.models.VenmoAccountNonce;
import com.braintreepayments.cardform.view.CardForm;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.BridgeFragment;
import com.getcapacitor.annotation.ActivityCallback;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.android.gms.wallet.TransactionInfo;
import com.google.android.gms.wallet.WalletConstants;

import com.braintreepayments.api.dropin.DropInActivity;
import com.braintreepayments.api.dropin.DropInRequest;
import com.braintreepayments.api.dropin.DropInResult;

import com.braintreepayments.api.models.PaymentMethodNonce;

import org.json.JSONException;

@CapacitorPlugin(
        name = "Braintree"
        //requestCodes = {
        //        BraintreePlugin.DROP_IN_REQUEST
        //}
)
public class BraintreePlugin extends Plugin {

   private String clientToken;
   private BraintreeFragment mBraintreeFragment;

    /**
     * Logger tag
     */
    private static final String PLUGIN_TAG = "Braintree";

    static final String EXTRA_PAYMENT_RESULT = "payment_result";
    static final String EXTRA_DEVICE_DATA = "device_data";
    //static final String EXTRA_COLLECT_DEVICE_DATA = "collect_device_data";
    private String deviceData = "";

    /**
     * In this version (simplified) using only "dropin" with nonce processed on server-side
     */
    static final int DROP_IN_REQUEST = 1;
    // private static final int GOOGLE_PAYMENT_REQUEST = 2;
    // private static final int CARDS_REQUEST = 3;
    // private static final int PAYPAL_REQUEST = 4;
    // private static final int VENMO_REQUEST = 5;
    // private static final int VISA_CHECKOUT_REQUEST = 6;
    // private static final int LOCAL_PAYMENTS_REQUEST = 7;
    // private static final int PREFERRED_PAYMENT_METHODS_REQUEST = 8;

    @PluginMethod()
    public void getDeviceData(PluginCall call) {
        String merchantId = call.getString("merchantId");

        if (merchantId == null) {
            call.reject("A Merchant ID is required.");
            return;
        }
        try {
           JSObject deviceDataMap = new JSObject(this.deviceData);
            call.resolve(deviceDataMap);
        } catch (JSONException e) {
            call.reject("Cannot get device data");
        }
    }

    @PluginMethod()
    public void setToken(PluginCall call) throws InvalidArgumentException {
        String token = call.getString("token");

        if (!call.getData().has("token")){
            call.reject("A token is required.");
            return;
        }
        this.clientToken = token;
        call.resolve();
    }

    @PluginMethod()
    public void getTickets(PluginCall call) {
        call.resolve();
    }

    @PluginMethod()
    public void getRecentMethods(PluginCall call) throws InvalidArgumentException {
        String token = call.getString("token");
        this.clientToken = token;

        if (!call.getData().has("token")){
            call.reject("A token is required.");
            return;
        }


        DropInResult.fetchDropInResult(getActivity(), token, new DropInResult.DropInResultListener() {
            @Override
            public void onError(Exception exception) {
                // an error occurred
                JSObject resultMap = new JSObject();
                resultMap.put("previousPayment", false);
                call.resolve(resultMap);
            }

            @Override
            public void onResult(DropInResult result) {
                if (result.getPaymentMethodType() != null) {
                    // use the icon and name to show in your UI
                    int icon = result.getPaymentMethodType().getDrawable();
                    int name = result.getPaymentMethodType().getLocalizedName();

                    PaymentMethodType paymentMethodType = result.getPaymentMethodType();
                    if (paymentMethodType == PaymentMethodType.GOOGLE_PAYMENT) {
                        // The last payment method the user used was Google Pay.
                        // The Google Pay flow will need to be performed by the
                        // user again at the time of checkout.
                        JSObject resultMap = new JSObject();
                        resultMap.put("previousPayment", false);
                        call.resolve(resultMap);
                    } else {
                        // Use the payment method show in your UI and charge the user
                        // at the time of checkout.
                        JSObject resultMap = new JSObject();
                        resultMap.put("previousPayment", true);
                        PaymentMethodNonce paymentMethod = result.getPaymentMethodNonce();
                        resultMap.put("data", handleNonce(paymentMethod, result.getDeviceData()));
                        call.resolve(resultMap);
                    }
                } else {
                    // there was no existing payment method
                    JSObject resultMap = new JSObject();
                    resultMap.put("previousPayment", false);
                    call.resolve(resultMap);
                }
            }
        });
//        call.resolve();
    }

    @PluginMethod()
    public void showDropIn(PluginCall call) {
        ThreeDSecurePostalAddress address = new ThreeDSecurePostalAddress()
            .givenName(call.getString("givenName")) // ASCII-printable characters required, else will throw a validation error
            .surname(call.getString("surname")) // ASCII-printable characters required, else will throw a validation error
            .phoneNumber(call.getString("phoneNumber"))
            .streetAddress(call.getString("streetAddress"))
            .locality(call.getString("locality"))
            .postalCode(call.getString("postalCode"))
            .countryCodeAlpha2(call.getString("countryCodeAlpha2"));
        ThreeDSecureAdditionalInformation additionalInformation = new ThreeDSecureAdditionalInformation()
           .shippingAddress(address);
        ThreeDSecureRequest threeDSecureRequest = new ThreeDSecureRequest()
            .amount(call.getString("amount"))
            .email(call.getString("email"))
            .billingAddress(address)
            .versionRequested(ThreeDSecureRequest.VERSION_2)
            .additionalInformation(additionalInformation);
        DropInRequest dropInRequest = new DropInRequest()
            .clientToken(this.clientToken)
            .cardholderNameStatus(CardForm.FIELD_REQUIRED)
            .requestThreeDSecureVerification(true)
            .collectDeviceData(true)
            .threeDSecureRequest(threeDSecureRequest)
            .vaultManager(true);

//        if (call.hasOption("disabled")) {
//            JSArray disables = call.getArray("disabled");
//            if (disables.get(0) == "googlePay") {
//                dropInRequest.disableGooglePayment();
//            }
//            if (disables.get(0) == "card") {
//                dropInRequest.disableCard();
//            }
//        }

        if (call.hasOption("deleteMethods")) {
            dropInRequest.disableGooglePayment();
            dropInRequest.disableCard();
        }

        GooglePaymentRequest googlePaymentRequest = new GooglePaymentRequest()
                .transactionInfo(TransactionInfo.newBuilder()
                        .setTotalPrice(call.getString("amount"))
                        .setTotalPriceStatus(WalletConstants.TOTAL_PRICE_STATUS_FINAL)
                        .setCurrencyCode(call.getString("currencyCode"))
                        .build())
                .billingAddressRequired(true)
                .googleMerchantId(call.getString("googleMerchantId"));
        dropInRequest.googlePaymentRequest(googlePaymentRequest);
        Intent intent = dropInRequest.getIntent(getContext());

        Log.d(PLUGIN_TAG, "showDropIn started");

        startActivityForResult(call, intent, "dropinCallback");
    }

    @ActivityCallback
    protected void dropinCallback(PluginCall call, ActivityResult activityResult) {
        Intent data = activityResult.getData();

        Log.d(PLUGIN_TAG, "dropinCallback. Result code: "+activityResult.getResultCode()+", intent: "+data);

        if (call == null) {
            return;
        }

        if (activityResult.getResultCode() == Activity.RESULT_CANCELED) {
            if (data != null) {
                DropInResult result = data.getParcelableExtra(DropInResult.EXTRA_DROP_IN_RESULT);
                call.resolve(handleCanceled(result.getDeviceData()));
            } else {
                call.resolve(handleCanceled(null));
            }

        }


        if (activityResult.getResultCode() == Activity.RESULT_OK) {
            DropInResult result = data.getParcelableExtra(DropInResult.EXTRA_DROP_IN_RESULT);
            call.resolve(handleNonce(result.getPaymentMethodNonce(), result.getDeviceData()));
        } else {
            Exception ex = (Exception) data.getSerializableExtra(DropInActivity.EXTRA_ERROR);
            String msg = ex.getMessage();
            Log.e(PLUGIN_TAG, "Error: "+msg);
            call.reject(msg, ex);
        }
    }

    /**
     *
     * @param deviceData device info (not used in context)
     */
    private JSObject handleCanceled(String deviceData) {
        Log.d(PLUGIN_TAG, "handleNonce");

        JSObject resultMap = new JSObject();
        resultMap.put("cancelled", true);
        resultMap.put("deviceData", deviceData);
        return resultMap;
    }

    private JSObject formatAddress(PostalAddress address) {
        JSObject addressMap = new JSObject();
        addressMap.put("name", address.getRecipientName());
        addressMap.put("address1", address.getStreetAddress());
        addressMap.put("address2", address.getExtendedAddress());
        addressMap.put("locality", address.getLocality());
        addressMap.put("administrativeArea", address.getRegion());
        addressMap.put("postalCode", address.getPostalCode());
        addressMap.put("countryCode", address.getCountryCodeAlpha2());
        return addressMap;
    }

    /**
     * Helper used to return a dictionary of values from the given payment method nonce.
     * Handles several different types of nonces (eg for cards, PayPal, etc).
     *
     * @param paymentMethodNonce The nonce used to build a dictionary of data from.
     * @param deviceData Device info
     */
    private JSObject handleNonce(PaymentMethodNonce paymentMethodNonce, String deviceData) {
        Log.d(PLUGIN_TAG, "handleNonce");

        JSObject resultMap = new JSObject();
        resultMap.put("cancelled", false);
        resultMap.put("nonce", paymentMethodNonce.getNonce());
        resultMap.put("type", paymentMethodNonce.getTypeLabel());
        resultMap.put("localizedDescription", paymentMethodNonce.getDescription());
        this.deviceData = deviceData;
        resultMap.put("deviceData", deviceData);

        // Card
        if (paymentMethodNonce instanceof CardNonce) {
            CardNonce cardNonce = (CardNonce)paymentMethodNonce;

            JSObject innerMap = new JSObject();
            innerMap.put("lastTwo", cardNonce.getLastTwo());
            innerMap.put("network", cardNonce.getCardType());
            innerMap.put("cardHolderName", cardNonce.getCardholderName());
            innerMap.put("type", cardNonce.getTypeLabel());
            innerMap.put("token", cardNonce.toString());


            ThreeDSecureInfo threeDSecureInfo = cardNonce.getThreeDSecureInfo();

            if (threeDSecureInfo != null) {
                JSObject threeDMap = new JSObject();
                threeDMap.put("threeDSecureVerified", threeDSecureInfo.wasVerified());
                threeDMap.put("liabilityShifted", threeDSecureInfo.isLiabilityShifted());
                threeDMap.put("liabilityShiftPossible", threeDSecureInfo.isLiabilityShiftPossible());

                innerMap.put("threeDSecureCard", threeDMap);
            }
            if (resultMap.getString("localizedDescription").equals("Android Pay")) {
                resultMap.put("googlePay", innerMap);
            } else {
                resultMap.put("card", innerMap);
            }
        }

        // PayPal
        if (paymentMethodNonce instanceof PayPalAccountNonce) {
            PayPalAccountNonce payPalAccountNonce = (PayPalAccountNonce)paymentMethodNonce;

            JSObject innerMap = new JSObject();
            resultMap.put("email", payPalAccountNonce.getEmail());
            resultMap.put("firstName", payPalAccountNonce.getFirstName());
            resultMap.put("lastName", payPalAccountNonce.getLastName());
            resultMap.put("phone", payPalAccountNonce.getPhone());
            // resultMap.put("billingAddress", payPalAccountNonce.getBillingAddress()); //TODO
            // resultMap.put("shippingAddress", payPalAccountNonce.getShippingAddress()); //TODO
            resultMap.put("clientMetadataId", payPalAccountNonce.getClientMetadataId());
            resultMap.put("payerId", payPalAccountNonce.getPayerId());

            resultMap.put("payPalAccount", innerMap);
        }

        // 3D Secure
        if (paymentMethodNonce instanceof CardNonce) {
            CardNonce cardNonce = (CardNonce) paymentMethodNonce;

        }

        // Venmo
        if (paymentMethodNonce instanceof VenmoAccountNonce) {
            VenmoAccountNonce venmoAccountNonce = (VenmoAccountNonce) paymentMethodNonce;

            JSObject innerMap = new JSObject();
            innerMap.put("username", venmoAccountNonce.getUsername());

            resultMap.put("venmoAccount", innerMap);
        }

        if (paymentMethodNonce instanceof GooglePaymentCardNonce) {
            GooglePaymentCardNonce googlePayCardNonce = (GooglePaymentCardNonce) paymentMethodNonce;

            JSObject innerMap = new JSObject();
            innerMap.put("lastTwo", googlePayCardNonce.getLastTwo());
            innerMap.put("email", googlePayCardNonce.getEmail());
            innerMap.put("network", googlePayCardNonce.getCardType());
            innerMap.put("type", googlePayCardNonce.getTypeLabel());
            innerMap.put("token", googlePayCardNonce.toString());
            innerMap.put("billingAddress", formatAddress(googlePayCardNonce.getBillingAddress()));
            innerMap.put("shippingAddress", formatAddress(googlePayCardNonce.getShippingAddress()));

            resultMap.put("googlePay", innerMap);
        }

        return resultMap;
    }
}
