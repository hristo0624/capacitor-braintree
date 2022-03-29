import { WebPlugin } from '@capacitor/core';
import type { BraintreePlugin, DropInOptions, DropInResult, DropInToken, DataCollectorOptions } from './definitions';
export declare class BraintreeWeb extends WebPlugin implements BraintreePlugin {
    setToken(options: DropInToken): Promise<any>;
    showDropIn(options: DropInOptions): Promise<DropInResult>;
    getDeviceData(options: DataCollectorOptions): Promise<any>;
}
