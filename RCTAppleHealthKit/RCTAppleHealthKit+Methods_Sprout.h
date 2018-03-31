#import "RCTAppleHealthKit.h"

@interface RCTAppleHealthKit (Methods_Sprout)

- (void)sprout_clearSproutBackgroundTask:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback;
- (void)sprout_initializeSproutBackgroundTask:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback;
- (void)sprout_postData:(NSDictionary *)data;
@end

