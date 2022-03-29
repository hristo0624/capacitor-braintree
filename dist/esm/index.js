import { registerPlugin } from '@capacitor/core';
const Braintree = registerPlugin('Braintree', {
    web: () => import('./web').then(m => new m.BraintreeWeb()),
});
export * from './definitions';
export { Braintree };
//# sourceMappingURL=index.js.map