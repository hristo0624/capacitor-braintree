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
    var merchantName: String!
    var payAmount: NSDecimalNumber!
    var showCallID: String?

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

        BTUIKAppearance.sharedInstance().primaryTextColor = UIColor(red: 17.0 / 255.0, green: 182.0 / 255.0, blue: 131.0 / 255.0, alpha: 1.0);


        call.resolve()
    }
    
    func updateToken (token: String) {
        guard let callID = self.showCallID, let call = bridge?.savedCall(withID: callID) else {
            return
        }
        if token.isEmpty {
            call.reject("A token is required.")
            return
        }
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
        self.token = token

        if let apiClient = BTAPIClient(authorization: self.token) {
            self.dataCollector = BTDataCollector(apiClient: apiClient)
        }
    }
    
    @objc func getRecentMethods(_ call: CAPPluginCall) {
        let token = call.getString("token")
        if token == nil, token == "" {
            call.reject("A token is required.")
            return
        }
        updateToken(token: token!)
        
        BTDropInResult.fetch(forAuthorization: token ?? "") { (result, error) in
            guard let result = result, error == nil else {
                let response: [String: Any] = ["previousPayment": false]
                call.resolve(response);
                return
            }
            
            if result.paymentOptionType == .applePay {
                let response: [String: Any] = ["previousPayment": false]
                call.resolve(response);
            } else {
                if (result.paymentMethod != nil) {
                    var response: [String: Any] = ["previousPayment": true]
                    let nonce = self.getPaymentMethodNonce(paymentMethodNonce:result.paymentMethod!)
                    response["data"] = nonce;
                    call.resolve(response);
                } else {
                    let response: [String: Any] = ["previousPayment": false]
                    call.resolve(response);
                }
                
            }
        }
    }

    /**
     * Show DropIn UI
     */
    @objc func showDropIn(_ call: CAPPluginCall) {
        guard let amount = call.getString("amount") else {
            call.reject("An amount is required.")
            return;
        }
        
        guard let mName = call.getString("appleMerchantName") else {
            call.reject("Apple Pay Merchant Name is required.")
            return;
        }
        
        showCallID = call.callbackId;
        bridge?.saveCall(call);
        payAmount = NSDecimalNumber(string: amount)
        merchantName = mName
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
//        threeDSecureRequest.billingAddress = address

        let dropInRequest = BTDropInRequest()
        dropInRequest.threeDSecureVerification = true
        dropInRequest.cardholderNameSetting = .required
        dropInRequest.threeDSecureRequest = threeDSecureRequest
        dropInRequest.vaultManager = true
        
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

        if (call.hasOption("deleteMethods")) {
            dropInRequest.paypalDisabled = true;
            dropInRequest.venmoDisabled = true;
            dropInRequest.applePayDisabled = true;
            dropInRequest.cardDisabled = true;
        }

        /**
         * Initialize DropIn UI
         */
        let dropIn = BTDropInController(authorization: self.token, request: dropInRequest)
        { [self] (controller, result, error) in
            if (error != nil) {
                call.reject(error)
            } else if (result?.isCancelled == true) {
                call.resolve(["cancelled": true])
            } else if let result = result {
                if (result.paymentMethod === nil && result.paymentOptionType == BTUIKPaymentOptionType.applePay) {
                    let paymentRequest = PKPaymentRequest()
                    paymentRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: self.merchantName, amount: payAmount)]
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
                    let paymentMethodNonce = result.paymentMethod
                    if (paymentMethodNonce as? BTCardNonce)?.threeDSecureInfo.wasVerified == false {
                        self.performThreeDSecureVerification(threeDSecureRequest: threeDSecureRequest, paymentMethodNonce: paymentMethodNonce!, call: call);
                    } else {
                        call.resolve(self.getPaymentMethodNonce(paymentMethodNonce: result.paymentMethod!))
                    }
                    
                }
            }
            controller.dismiss(animated: true, completion: nil)
        }
        DispatchQueue.main.async {
            self.bridge?.viewController?.present(dropIn!, animated: true, completion: nil)
        }
    }
    
    @objc func showApplePay(_ call: CAPPluginCall) {
        let token = call.getString("token")
        if token == nil, token == "" {
            call.reject("A token is required.")
            return
        }
        guard let amount = call.getString("amount") else {
            call.reject("An amount is required.")
            return;
        }
        
        guard let mName = call.getString("appleMerchantName") else {
            call.reject("Apple Pay Merchant Name is required.")
            return;
        }
        
        showCallID = call.callbackId;
        bridge?.saveCall(call);
        payAmount = NSDecimalNumber(string: amount)
        merchantName = mName
        updateToken(token: token!)
        
        let paymentRequest = PKPaymentRequest()
        paymentRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: merchantName, amount: payAmount)]
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
    }

    @objc func getPaymentMethodNonce(paymentMethodNonce: BTPaymentMethodNonce) -> [String:Any] {
        var payPalAccountNonce: BTPayPalAccountNonce
        var cardNonce: BTCardNonce
        var venmoAccountNonce: BTVenmoAccountNonce

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
            if cardNonce.threeDSecureInfo.wasVerified == false {
               print("ThreeD Secure was not verified")
            } else {
                print("ThreeD Secure was verified")
            }
            response["deviceData"] = PPDataCollector.collectPayPalDeviceData()
            response["card"] = [
                "lastTwo": cardNonce.lastTwo!,
                "cardHolderName": cardNonce.cardholderName,
                //"network": cardNonce.cardNetwork // <---------------@@@ this cause error in IOS
                "threeDSecureCard": [
                    "threeDSecureVerified": cardNonce.threeDSecureInfo.wasVerified,
                    "liabilityShifted": cardNonce.threeDSecureInfo.liabilityShifted,
                    "liabilityShiftPossible": cardNonce.threeDSecureInfo.liabilityShiftPossible
                ]
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
    
    func performThreeDSecureVerification(threeDSecureRequest: BTThreeDSecureRequest, paymentMethodNonce: BTPaymentMethodNonce, call: CAPPluginCall) {
        guard let apiClient = BTAPIClient(authorization: self.token) else { return }
//        guard let nonce = paymentMethodNonce.nonce else { return }
        
        threeDSecureRequest.nonce = paymentMethodNonce.nonce

        let paymentFlowDriver = BTPaymentFlowDriver(apiClient: apiClient)
        paymentFlowDriver.viewControllerPresentingDelegate = self
        
        paymentFlowDriver.startPaymentFlow(threeDSecureRequest) { (result, error) in
//            self.selectedNonce = nil
            
            if let error = error {
                if (error as NSError).code == BTPaymentFlowDriverErrorType.canceled.rawValue {
                    // User cancelled 3DS flow and nonce was consumed
                } else {
                    // An error occurred and nonce was consumed
                }
                call.resolve(self.getPaymentMethodNonce(paymentMethodNonce: paymentMethodNonce));
                return
            }
        
            if let threeDSecureResult = result as? BTThreeDSecureResult {
                call.resolve(self.getPaymentMethodNonce(paymentMethodNonce: threeDSecureResult.tokenizedCard));
            }
        }
    }
    
    func resolveApplePayFail(message: String?) {
        if let callID = self.showCallID, let call = self.bridge?.savedCall(withID: callID) {
            var response: [String: Any] = ["cancelled": true]
            response["reason"] = message
            call.resolve(response);
            self.bridge?.releaseCall(call)
        }
    }
    
    func resolveApplePaySuccess(paymentMethodNonce: BTPaymentMethodNonce) {
        var response: [String: Any] = ["cancelled": false]
        response["nonce"] = paymentMethodNonce.nonce
        response["type"] = paymentMethodNonce.type
        response["deviceData"] = PPDataCollector.collectPayPalDeviceData()
        response["localizedDescription"] = paymentMethodNonce.localizedDescription
//        var applePayNonce: BTApplePayCardNonce = paymentMethodNonce as! BTApplePayCardNonce;
        response["applePay"] = [
//            "username": venmoAccountNonce.username
//            applePayNonce
        ]
        if let callID = self.showCallID, let call = self.bridge?.savedCall(withID: callID) {
            call.resolve(response);
            self.bridge?.releaseCall(call)
        }
    }
}



// MARK: - PKPaymentAuthorizationControllerDelegate

extension BraintreePlugin: PKPaymentAuthorizationViewControllerDelegate {
    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
                                            didSelect shippingMethod: PKShippingMethod,
                                            completion: @escaping (PKPaymentAuthorizationStatus, [PKPaymentSummaryItem]) -> Void) {
        let testItem = PKPaymentSummaryItem(label: merchantName, amount: payAmount)
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
        print("Apple Pay Did Authorize Payment1" + token)
        guard let apiClient = BTAPIClient(authorization: token) else { return }
        let applePayClient = BTApplePayClient(apiClient: apiClient)
        
        applePayClient.tokenizeApplePay(payment) { (tokenizedPaymentMethod, error) in
            guard let paymentMethod = tokenizedPaymentMethod, error == nil else {
                print(error!.localizedDescription)
                self.resolveApplePayFail(message: error?.localizedDescription);
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }
            
//            self.completionBlock?(paymentMethod)
            self.resolveApplePaySuccess(paymentMethodNonce: paymentMethod)
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
                self.resolveApplePayFail(message: error?.localizedDescription);
                completion(.failure)
                return
            }
            
//            self.completionBlock?(paymentMethod)
            self.resolveApplePaySuccess(paymentMethodNonce: paymentMethod)
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

// MARK: - BTViewControllerPresentingDelegate

extension BraintreePlugin: BTViewControllerPresentingDelegate {
    public func paymentDriver(_ driver: Any, requestsPresentationOf viewController: UIViewController) {
        DispatchQueue.main.async { [weak self] in
            self?.bridge?.viewController?.present(viewController, animated: true);
        }
    }
    
    public func paymentDriver(_ driver: Any, requestsDismissalOf viewController: UIViewController) {
        DispatchQueue.main.async { [weak self] in
            viewController.dismiss(animated: true, completion: nil);
        }
    }
}

