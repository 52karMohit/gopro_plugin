#import "GoProPlugin.h"
#import <Flutter/Flutter.h>

@implementation GoProPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                      methodChannelWithName:@"gopro_plugin/wifi"
                                      binaryMessenger:[registrar messenger]];
    
    GoProPlugin* instance = [[GoProPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"connectToWifi" isEqualToString:call.method]) {
        NSString* ssid = call.arguments[@"ssid"];
        NSString* password = call.arguments[@"password"];
        
        Class wifiManagerClass = NSClassFromString(@"GoProWifiManager");
        if (wifiManagerClass) {
            [wifiManagerClass connectToWifi:ssid password:password completion:^(BOOL success) {
                result(@(success));
            }];
        } else {
            result([FlutterError errorWithCode:@"UNAVAILABLE"
                                       message:@"GoProWifiManager not available"
                                       details:nil]);
        }
    } else if ([@"disconnectFromWifi" isEqualToString:call.method]) {
        NSString* ssid = call.arguments[@"ssid"];
        
        Class wifiManagerClass = NSClassFromString(@"GoProWifiManager");
        if (wifiManagerClass) {
            [wifiManagerClass disconnectFromWifi:ssid completion:^(BOOL success) {
                result(@(success));
            }];
        } else {
            result([FlutterError errorWithCode:@"UNAVAILABLE"
                                       message:@"GoProWifiManager not available"
                                       details:nil]);
        }
    } else if ([@"getCurrentSSID" isEqualToString:call.method]) {
        Class wifiManagerClass = NSClassFromString(@"GoProWifiManager");
        if (wifiManagerClass) {
            NSString* ssid = [wifiManagerClass getCurrentSSID];
            result(ssid ?: [NSNull null]);
        } else {
            result([FlutterError errorWithCode:@"UNAVAILABLE"
                                       message:@"GoProWifiManager not available"
                                       details:nil]);
        }
    } else if ([@"isWifiEnabled" isEqualToString:call.method]) {
        Class wifiManagerClass = NSClassFromString(@"GoProWifiManager");
        if (wifiManagerClass) {
            BOOL enabled = [wifiManagerClass isWifiEnabled];
            result(@(enabled));
        } else {
            result([FlutterError errorWithCode:@"UNAVAILABLE"
                                       message:@"GoProWifiManager not available"
                                       details:nil]);
        }
    } else {
        result(FlutterMethodNotImplemented);
    }
}
@end
