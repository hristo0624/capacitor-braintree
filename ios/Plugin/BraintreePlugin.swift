import Foundation
import Capacitor
import Braintree
import BraintreeDropIn

@objc(BraintreePlugin)
public class BraintreePlugin: CAPPlugin {
    var token: String!
    var dataCollector: BTDataCollector!
    var braintreeClient: BTAPIClient!
    var applePayController: PKPaymentAuthorizationViewController!

    /**
     * Get device date
     */
    @objc func getDeviceData(_ call: CAPPluginCall) {
        let metchantId = call.getString("merchantId") ?? ""

        if metchantId.isEmpty {
            call.reject("A Merchant ID is required.")
            return
        }

        self.dataCollector.setFraudMerchantId(metchantId)
        self.dataCollector.collectCardFraudData() { deviceData in
            call.resolve([deviceData: deviceData])
        }
    }

    /**
     * Set Braintree API token
     * Set Braintree Switch URL
     */
    @objc func setToken(_ call: CAPPluginCall) {
        /**
         * Set App Switch
         */
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            call.reject("iOS internal error - failed to get bundle identifier via Bundle.main.bundleIdentifier");
            return
        }

        if bundleIdentifier.count == 0 {
            call.reject("iOS internal error - bundle identifier via Bundle.main.bundleIdentifier was zero length");
            return
        }

        BTAppSwitch.setReturnURLScheme(bundleIdentifier + ".payments")

        /**
         * Assign API token
         */
        self.token = call.hasOption("token") ? call.getString("token") : ""
        if self.token.isEmpty {
            call.reject("A token is required.")
            return
        }

        if let apiClient = BTAPIClient(authorization: self.token) {
            self.dataCollector = BTDataCollector(apiClient: apiClient)
        }

        call.resolve()
    }

    /**
     * Show DropIn UI
     */
    @objc func showDropIn(_ call: CAPPluginCall) {
        guard let amount = call.getString("amount") else {
            call.reject("An amount is required.")
            return;
        }

        /**
         * DropIn UI Request
         */
        let threeDSecureRequest = BTThreeDSecureRequest()
        threeDSecureRequest.versionRequested = .version2
        threeDSecureRequest.amount = NSDecimalNumber(string: amount)
        threeDSecureRequest.email = call.getString("email") ?? ""

        let address = BTThreeDSecurePostalAddress()
        address.givenName = call.getString("givenName") ?? "" // ASCII-printable characters required, else will throw a validation error
        address.surname = call.getString("surname") ?? "" // ASCII-printable characters required, else will throw a validation error
        address.phoneNumber = call.getString("phoneNumber") ?? ""
        address.streetAddress = call.getString("streetAddress") ?? ""
        address.locality =  call.getString("locality") ?? ""
        address.postalCode =  call.getString("postalCode") ?? ""
        address.countryCodeAlpha2 = call.getString("countryCodeAlpha2") ?? ""
        threeDSecureRequest.billingAddress = address

        let dropInRequest = BTDropInRequest()
        dropInRequest.threeDSecureVerification = true
        dropInRequest.cardholderNameSetting = .required
        dropInRequest.threeDSecureRequest = threeDSecureRequest

        /**
         * Disabble Payment Methods
         */
        if call.hasOption("disabled") {
            let disabled = call.getArray("disabled", String.self)
            if disabled!.contains("paypal") {
                dropInRequest.paypalDisabled = true;
            }
            if disabled!.contains("venmo") {
                dropInRequest.venmoDisabled = true;
            }
            if disabled!.contains("applePay") {
                dropInRequest.applePayDisabled = true;
            }
            if disabled!.contains("card") {
                dropInRequest.cardDisabled = true;
            }
        }

        /**
         * Initialize DropIn UI
         */
        let dropIn = BTDropInController(authorization: self.token, request: dropInRequest)
        { (controller, result, error) in
            if (error != nil) {
                call.reject("Something went wrong.")
            } else if (result?.isCancelled == true) {
                call.resolve(["cancelled": true])
            } else if let result = result {
                if (result.paymentMethod === nil && result.paymentOptionType == BTUIKPaymentOptionType.applePay) {
                    let paymentRequest = PKPaymentRequest()
                    paymentRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: call.getString("appleMerchantName") ?? "", amount: NSDecimalNumber(string: amount))]
                    paymentRequest.supportedNetworks = [.visa, .masterCard, .amex, .discover]
                    paymentRequest.merchantCapabilities = .capability3DS
                    paymentRequest.currencyCode = call.getString("currencyCode") ?? "GBP"
                    paymentRequest.countryCode = call.getString("countryCodeAlpha2") ?? "GB"
                    paymentRequest.merchantIdentifier = call.getString("appleMerchantId") ?? ""
                    
                    guard let applePayController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest) else {
                        print("Unable to initialize PKPaymentAuthorizationViewController for Apple Pay")
                        return
                    }
                    applePayController.delegate = self
                    
                    print("Presenting Apple Pay Sheet")
                    DispatchQueue.main.async { [weak self] in
                        self?.bridge?.viewController?.present(applePayController, animated: true)
                    }
                } else {
                    call.resolve(self.getPaymentMethodNonce(paymentMethodNonce: result.paymentMethod!))
                }
            }
            controller.dismiss(animated: true, completion: nil)
        }
        DispatchQueue.main.async {
            self.bridge?.viewController?.present(dropIn!, animated: true, completion: nil)
        }
    }

    @objc func getPaymentMethodNonce(paymentMethodNonce: BTPaymentMethodNonce) -> [String:Any] {
        var payPalAccountNonce: BTPayPalAccountNonce
        var cardNonce: BTCardNonce
        var venmoAccountNonce: BTVenmoAccountNonce
        var appleAccountNonce: BTApplePayCardNonce

        var response: [String: Any] = ["cancelled": false]
        response["nonce"] = paymentMethodNonce.nonce
        response["type"] = paymentMethodNonce.type
        response["localizedDescription"] = paymentMethodNonce.localizedDescription

        /**
         * Handle Paypal Response
         */
        if(paymentMethodNonce is BTPayPalAccountNonce){
            payPalAccountNonce = paymentMethodNonce as! BTPayPalAccountNonce
            response["deviceData"] = PPDataCollector.collectPayPalDeviceData()
            response["paypal"] = [
                "email": payPalAccountNonce.email,
                "firstName": payPalAccountNonce.firstName,
                "lastName": payPalAccountNonce.lastName,
                "phone": payPalAccountNonce.phone,
                "clientMetadataId": payPalAccountNonce.clientMetadataId,
                "payerId": payPalAccountNonce.payerId
            ]
        }

        /**
         * Handle Card Response
         */
        if(paymentMethodNonce is BTCardNonce){
            cardNonce = paymentMethodNonce as! BTCardNonce
            response["deviceData"] = PPDataCollector.collectPayPalDeviceData()
            response["card"] = [
                "lastTwo": cardNonce.lastTwo!,
                //"network": cardNonce.cardNetwork // <---------------@@@ this cause error in IOS
            ]
        }

        /**
         * Handle Card Response
         */
        if(paymentMethodNonce is BTVenmoAccountNonce){
            venmoAccountNonce = paymentMethodNonce as! BTVenmoAccountNonce
            response["venmo"] = [
                "username": venmoAccountNonce.username
            ]
        }

        return response;

    }
}

// MARK: - PKPaymentAuthorizationControllerDelegate

extension BraintreePlugin: PKPaymentAuthorizationViewControllerDelegate {
    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
                                            didSelect shippingMethod: PKShippingMethod,
                                            completion: @escaping (PKPaymentAuthorizationStatus, [PKPaymentSummaryItem]) -> Void) {
        let testItem = PKPaymentSummaryItem(label: "SOME ITEM", amount: 10.00)
        if shippingMethod.identifier == "fast" {
            completion(.success, [testItem,
                                  PKPaymentSummaryItem(label: "SHIPPING", amount: shippingMethod.amount),
                                  PKPaymentSummaryItem(label: "BRAINTREE", amount: testItem.amount.adding(shippingMethod.amount))])
        } else if shippingMethod.identifier == "fail" {
            completion(.failure, [testItem])
        } else {
            completion(.success, [testItem])
        }
    }
    
    @available(iOS 11.0, *)
    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
                                            didAuthorizePayment payment: PKPayment,
                                            handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        print("Apple Pay Did Authorize Payment1")
        guard let apiClient = BTAPIClient(authorization: token) else { return }
        let applePayClient = BTApplePayClient(apiClient: apiClient)
        
        applePayClient.tokenizeApplePay(payment) { (tokenizedPaymentMethod, error) in
            guard let paymentMethod = tokenizedPaymentMethod, error == nil else {
                print(error!.localizedDescription)
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }
            
//            self.completionBlock?(paymentMethod)
            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        }
    }
    
    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
                                            didAuthorizePayment payment: PKPayment,
                                            completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        print("Apple Pay Did Authorize Payment2")
        guard let apiClient = BTAPIClient(authorization: token) else { return }
        let applePayClient = BTApplePayClient(apiClient: apiClient)
        
        applePayClient.tokenizeApplePay(payment) { (tokenizedPaymentMethod, error) in
            guard let paymentMethod = tokenizedPaymentMethod, error == nil else {
                print(error!.localizedDescription)
                completion(.failure)
                return
            }
            
//            self.completionBlock?(paymentMethod)
            completion(.success)
        }
    }
    
    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        DispatchQueue.main.async { [weak self] in
            controller.dismiss(animated: true, completion: nil)
        }
    }
    
    public func paymentAuthorizationViewControllerWillAuthorizePayment(_ controller: PKPaymentAuthorizationViewController) {
        print("Apple Pay will Authorize Payment")
    }
}
