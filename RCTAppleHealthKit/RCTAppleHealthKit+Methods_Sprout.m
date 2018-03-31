#import "RCTAppleHealthKit+Methods_Sprout.h"
#import "RCTAppleHealthKit+Queries.h"
#import "RCTAppleHealthKit+Utils.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>

@implementation RCTAppleHealthKit (Methods_Sprout)

- (void)sprout_clearSproutBackgroundTask:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int value = 0;
    [defaults removeObjectForKey:@"token"];
    [defaults removeObjectForKey:@"url"];
    [defaults removeObjectForKey:@"vendorId"];
    [defaults removeObjectForKey:@"vendorName"];
    [defaults removeObjectForKey:@"deviceId"];
    [defaults removeObjectForKey:@"lastHealthKitSync"];
    callback(@[[NSNull null], @(value)]);
}


- (void)sprout_initializeSproutBackgroundTask:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    NSString *sproutToken = [RCTAppleHealthKit stringFromOptions:input key:@"token" withDefault:nil];
    NSString *url = [RCTAppleHealthKit stringFromOptions:input key:@"url" withDefault:nil];
    NSString *vendorName = [RCTAppleHealthKit stringFromOptions:input key:@"vendorName" withDefault:nil];
    NSString *deviceId = [RCTAppleHealthKit stringFromOptions:input key:@"deviceId" withDefault:nil];
    
    NSUInteger vendorId = [RCTAppleHealthKit uintFromOptions:input key:@"vendorId" withDefault:0];
    
    if (!sproutToken || !url || !vendorId || !vendorName || !deviceId) {
        NSLog(@"One of required paramter not supplied: token/url/vendorId/vendorName/deviceId");
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"One of required paramter not supplied: token/url/vendorId/vendorName/deviceId" forKey:NSLocalizedDescriptionKey];
        NSError *error = [NSError errorWithDomain:@"com.sproutatwork" code:-1 userInfo:errorDetail];
        callback(@[RCTMakeError(@"One of required paramter not supplied: token/url/vendorId/vendorName/deviceId", error, nil)]);
        return;
    }
    
    // Store to defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:sproutToken forKey:@"token"];
    [defaults setValue:url forKey:@"url"];
    [defaults setValue:vendorName forKey:@"vendorName"];
    [defaults setValue:deviceId forKey:@"deviceId"];
    [defaults setValue:[NSNumber numberWithUnsignedInteger:vendorId] forKey:@"vendorId"];

    HKSampleType *stepCountSampleType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    [self.healthStore enableBackgroundDeliveryForType:stepCountSampleType frequency:HKUpdateFrequencyHourly withCompletion:^(BOOL success, NSError *error) {}];
    [self.healthStore enableBackgroundDeliveryForType:[HKWorkoutType workoutType] frequency:HKUpdateFrequencyImmediate withCompletion:^(BOOL success, NSError *error) {}];

    HKQuery *backgroundquery = [[HKObserverQuery alloc] initWithSampleType:stepCountSampleType predicate:nil updateHandler:
        ^void(HKObserverQuery *observerQuery, HKObserverQueryCompletionHandler completionHandler, NSError *error) {
            NSLog(@"HealthKit native received a background call");
            if (completionHandler) {
                completionHandler();
            }
            
            // Added to sync when app is closed.
            UIBackgroundTaskIdentifier __block taskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                if (taskID != UIBackgroundTaskInvalid) {
                    [[UIApplication sharedApplication] endBackgroundTask:taskID];
                    taskID = UIBackgroundTaskInvalid;
                }
            }];
            
            NSString *_sproutToken = [defaults stringForKey:@"token"];
            if (!_sproutToken) {
                if (taskID != UIBackgroundTaskInvalid) {
                    NSLog(@"HealthKit native endBackgroundTask no token");
                    [[UIApplication sharedApplication] endBackgroundTask:taskID];
                    taskID = UIBackgroundTaskInvalid;
                }
                return;
            }
            double lastHealthKitSync = [defaults doubleForKey:@"lastHealthKitSync"];
            NSDate *date = [NSDate date];
            NSTimeInterval now = [date timeIntervalSince1970];
            if (lastHealthKitSync + 60 > now) {
                NSLog(@"HealthKit just sync'ed, skipping");
                if (taskID != UIBackgroundTaskInvalid) {
                    NSLog(@"HealthKit native endBackgroundTask");
                    [[UIApplication sharedApplication] endBackgroundTask:taskID];
                    taskID = UIBackgroundTaskInvalid;
                }
                return;
            }
            [defaults setDouble:now forKey:@"lastHealthKitSync"];
            [self sprout_stepsQuery:taskID];
            
        }];
    
    [self.healthStore executeQuery:backgroundquery];


//    HKQuery *workoutquery = [[HKObserverQuery alloc] initWithSampleType:[HKWorkoutType workoutType] predicate:nil updateHandler:
//        ^void(HKObserverQuery *observerQuery, HKObserverQueryCompletionHandler completionHandler, NSError *error) {
//            NSLog(@"HealthKit native received a background call for workout");
//            if (completionHandler) {
//                completionHandler();
//            }
//            
//            // Added to sync when app is closed.
//            UIBackgroundTaskIdentifier __block taskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
//                if (taskID != UIBackgroundTaskInvalid) {
//                    [[UIApplication sharedApplication] endBackgroundTask:taskID];
//                    taskID = UIBackgroundTaskInvalid;
//                }
//            }];
//            
//            NSInteger _vendorId = [defaults integerForKey:@"vendorId"];
//            NSString *_vendorName = [defaults stringForKey:@"vendorName"];
//            NSString *_deviecId = [defaults stringForKey:@"deviceId"];
//            NSString *_sproutToken = [defaults stringForKey:@"token"];
//            NSString *_url = [defaults stringForKey:@"url"];
//            if (!_sproutToken) {
//                if (taskID != UIBackgroundTaskInvalid) {
//                    NSLog(@"HealthKit native endBackgroundTask no token");
//                    [[UIApplication sharedApplication] endBackgroundTask:taskID];
//                    taskID = UIBackgroundTaskInvalid;
//                }
//                return;
//            }
//            double lastHealthKitSync = [defaults doubleForKey:@"lastHealthKitSyncWorkout"];
//            NSDate *date = [NSDate date];
//            NSTimeInterval now = [date timeIntervalSince1970];
//            if (lastHealthKitSync + 60 > now) {
//                NSLog(@"HealthKit just sync'ed, skipping");
//                if (taskID != UIBackgroundTaskInvalid) {
//                    NSLog(@"HealthKit native endBackgroundTask");
//                    [[UIApplication sharedApplication] endBackgroundTask:taskID];
//                    taskID = UIBackgroundTaskInvalid;
//                }
//                return;
//            }
//            [defaults setDouble:now forKey:@"lastHealthKitSyncWorkout"];
//            [self sprout_workoutQuery];
//            
//        }];
//    [self.healthStore executeQuery:workoutquery];
}

- (void)sprout_stepsQuery:(UIBackgroundTaskIdentifier)taskID {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.day = 1;
    NSDateComponents *anchorComponents = [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                                     fromDate:[NSDate date]];
    anchorComponents.hour = 0;
    NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
    HKQuantityType *quantityType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    // Create the query
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                           quantitySamplePredicate:nil
                                                                                           options:HKStatisticsOptionCumulativeSum
                                                                                        anchorDate:anchorDate
                                                                                intervalComponents:interval];
    // Set the results handler
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *results, NSError *error) {
        if (error) {
            // Perform proper error handling here
            NSLog(@"*** An error occurred while calculating the statistics: %@ ***",error.localizedDescription);
            if (taskID != UIBackgroundTaskInvalid) {
                NSLog(@"HealthKit native endBackgroundTask");
                [[UIApplication sharedApplication] endBackgroundTask:taskID];
            }
            return;
        }
        
        NSDate *endDate = [NSDate date];
        NSDate *startDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:-7 toDate:endDate options:0];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        [dateFormatter setLocale:enUSPOSIXLocale];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
        
        NSMutableArray *activity = [[NSMutableArray alloc] init];
        // Plot the daily step counts over the past 7 days
        [results enumerateStatisticsFromDate:startDate toDate:endDate
                                   withBlock:^(HKStatistics *result, BOOL *stop) {
                                       HKQuantity *quantity = result.sumQuantity;
                                       if (quantity) {
                                           NSMutableDictionary *dayActivity = [[NSMutableDictionary alloc] init];
                                           [dayActivity setObject:@"healthKit" forKey:@"source"];
                                           [dayActivity setObject:@"movement" forKey:@"type"];
                                           [dayActivity setObject:@NO forKey:@"manual"];
                                           
                                           NSString *startDateString = [dateFormatter stringFromDate:result.startDate];
                                           NSString *endDateString = [dateFormatter stringFromDate:result.endDate];
                                           
                                           [dayActivity setObject:startDateString forKey:@"startTime"];
                                           [dayActivity setObject:endDateString forKey:@"endTime"];
                                           
                                           NSInteger offset = [[NSTimeZone localTimeZone] secondsFromGMT] / 60;    // In minutes
                                           NSInteger offsetHr = (NSInteger) offset / 60;
                                           NSInteger offsetMin = (NSInteger) offset % 60;
                                           NSString *offsetString;
                                           if (offsetHr < 0) {
                                               offsetString = [NSString stringWithFormat:@"%+03d:%02d", offsetHr, offsetMin];
                                           }
                                           else {
                                               offsetString = [NSString stringWithFormat:@"%02d:%02d", offsetHr, offsetMin];
                                           }
                                           
                                           [dayActivity setObject:offsetString forKey:@"offset"];
                                           
                                           int stepsValue = (int) [quantity doubleValueForUnit:[HKUnit countUnit]];
                                           
                                           NSDictionary *metrics = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:stepsValue] forKey:@"steps"];
                                           [dayActivity setObject:metrics forKey:@"metrics"];
                                           NSLog(@"%@: %d", startDateString, stepsValue);
                                           
                                           [activity addObject:dayActivity];
                                       }
                                   }
        ];
        
        NSDictionary *submitData = [NSDictionary dictionaryWithObject:activity forKey:@"activity"];
        
        NSMutableDictionary *submit = [[NSMutableDictionary alloc] init];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSInteger _vendorId = [defaults integerForKey:@"vendorId"];
        NSString *_vendorName = [defaults stringForKey:@"vendorName"];
        NSString *_deviecId = [defaults stringForKey:@"deviceId"];
        NSString *_sproutToken = [defaults stringForKey:@"token"];
        NSString *_url = [defaults stringForKey:@"url"];

        [submit setObject:submitData forKey:@"data"];
        [submit setObject:_deviecId forKey:@"deviceId"];
        [submit setObject:@"iOSHealth" forKey:@"vendorName"];
        [submit setObject:[NSNumber numberWithUnsignedInteger:_vendorId] forKey:@"vendorId"];
        
        [self sprout_postData:submit apiURL:_url sproutToken:_sproutToken taskID:taskID];
    };
    
    [self.healthStore executeQuery:query];
}

- (void)sprout_postData:(NSDictionary *)data apiURL:(NSString *)apiURL sproutToken:(NSString*)sproutToken taskID:(UIBackgroundTaskIdentifier)taskID {
    //NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", _url, @"client_logs"]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", apiURL, @"users/apps_devices"]];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = @"POST";
    [request addValue:[NSString stringWithFormat:@"sprout-token %@", sproutToken] forHTTPHeaderField:@"Authorization"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSData *postData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    [request setHTTPBody:postData];
    
    NSURLSessionDataTask *postDataTask = [session dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            // Handle response here
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
            if (!error && httpResp.statusCode == 201) {
                NSLog(@"HealthKit native logging completed...");
            } else {
                NSLog(@"HealthKit native logging failed...");
            }
            if (taskID != UIBackgroundTaskInvalid) {
                NSLog(@"HealthKit native endBackgroundTask");
                [[UIApplication sharedApplication] endBackgroundTask:taskID];
            }
        }];
    [postDataTask resume];

}

@end

