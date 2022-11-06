export interface DropInToken {
    token: string;
}
export interface DropInOptions {
    amount: string;
    deleteMethods?: boolean;
    disabled?: string[];
    givenName?: string | undefined;
    surname?: string | undefined;
    email?: string | undefined;
    phoneNumber?: string | undefined;
    streetAddress?: string | undefined;
    postalCode?: string | undefined;
    locality?: string | undefined;
    countryCodeAlpha2?: string | undefined;
    appleMerchantId?: string;
    googleMerchantId?: string;
    appleMerchantName?: string;
    currencyCode?: string;
}
export interface AppleGoogleOptions {
    token: string;
    amount: string | number;
    appleMerchantName?: string;
    appleMerchantId?: string;
    currencyCode?: string;
    countryCodeAlpha2?: string;
}
export interface DataCollectorOptions {
    merchantId: string;
}
export interface PostalAddress {
    name: string;
    address1: string;
    address2: string;
    locality: string;
    administrativeArea: string;
    postalCode: string;
    countryCode: string;
}
export interface ThreeDSecureCard {
    threeDSecureVerified: boolean;
    liabilityShifted: boolean;
    liabilityShiftPossible: boolean;
}
export interface CardResult {
    lastTwo: string;
    network: string;
    cardHolderName: string;
    threeDSecureCard: ThreeDSecureCard;
}
export interface RecentMethod {
    previousPayment: boolean;
    data?: CardResult;
}
export interface DropInResult {
    cancelled: boolean;
    nonce: string;
    type: string;
    localizedDescription: string;
    deviceData: string;
    card: CardResult;
    payPalAccount: {
        email: string;
        firstName: string;
        lastName: string;
        phone: string;
        billingAddress: string;
        shippingAddress: string;
        clientMetadataId: string;
        payerId: string;
    };
    applePay: any;
    googlePay: {
        email: string;
        billingAddress: PostalAddress;
        shippingAddress: PostalAddress;
        type?: string;
        token?: string;
        lastTwo?: string;
        network?: string;
        cardHolderName?: string;
        threeDSecureCard?: ThreeDSecureCard;
    };
    threeDSecureCard: {
        liabilityShifted: boolean;
        liabilityShiftPossible: boolean;
    };
    venmoAccount: {
        username: string;
    };
}
export interface TicketOptions {
    download: string;
}
export interface BraintreePlugin {
    setToken(options: DropInToken): Promise<any>;
    showDropIn(options: DropInOptions): Promise<DropInResult>;
    getDeviceData(options: DataCollectorOptions): Promise<any>;
    getRecentMethods(options: DropInToken): Promise<RecentMethod>;
    showApplePay(options: AppleGoogleOptions): Promise<DropInResult>;
    getTickets(options: TicketOptions): Promise<any>;
}
