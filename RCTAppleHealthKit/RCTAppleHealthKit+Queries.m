//
//  RCTAppleHealthKit+Queries.m
//  RCTAppleHealthKit
//
//  Created by Greg Wilson on 2016-06-26.
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "RCTAppleHealthKit+Queries.h"
#import "RCTAppleHealthKit+Utils.h"

#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>

@implementation RCTAppleHealthKit (Queries)

- (void)fetchMostRecentQuantitySampleOfType:(HKQuantityType *)quantityType
                                  predicate:(NSPredicate *)predicate
                                 completion:(void (^)(HKQuantity *, NSDate *, NSDate *, NSDictionary *, NSError *))completion {

    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc]
            initWithKey:HKSampleSortIdentifierEndDate
              ascending:NO
    ];

    HKSampleQuery *query = [[HKSampleQuery alloc]
            initWithSampleType:quantityType
                     predicate:predicate
                         limit:1
               sortDescriptors:@[timeSortDescriptor]
                resultsHandler:^(HKSampleQuery *query, NSArray *results, NSError *error) {

                      if (!results) {
                          if (completion) {
                              completion(nil, nil, nil, nil, error);
                          }
                          return;
                      }

                      if (completion) {
                          // If quantity isn't in the database, return nil in the completion block.
                          HKQuantitySample *quantitySample = results.firstObject;
                          NSDictionary *deviceInfo = [self deviceInfoForSample:quantitySample];
                          HKQuantity *quantity = quantitySample.quantity;
                          NSDate *startDate = quantitySample.startDate;
                          NSDate *endDate = quantitySample.endDate;
                          completion(quantity, startDate, endDate, deviceInfo, error);
                      }
                }
    ];
    [self.healthStore executeQuery:query];
}

- (void)fetchQuantitySamplesOfType:(HKQuantityType *)quantityType
                              unit:(HKUnit *)unit
                         predicate:(NSPredicate *)predicate
                         ascending:(BOOL)asc
                             limit:(NSUInteger)lim
                        completion:(void (^)(NSArray *, NSError *))completion {

    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate
                                                                       ascending:asc];

    // declare the block
    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);
    // create and assign the block
    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

            dispatch_async(dispatch_get_main_queue(), ^{

                for (HKQuantitySample *sample in results) {
                    HKQuantity *quantity = sample.quantity;
                    double value = [quantity doubleValueForUnit:unit];

                    NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                    NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                    NSDictionary *deviceInfo = [self deviceInfoForSample:sample];

                    NSDictionary *elem = @{
                            @"value" : @(value),
                            @"sourceName" : [[[sample sourceRevision] source] name],
                            @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                            @"startDate" : startDateString,
                            @"endDate" : endDateString,
                            @"deviceInfo" : deviceInfo
                    };

                    [data addObject:elem];
                }

                completion(data, error);
            });
        }
    };

    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:quantityType
                                                           predicate:predicate
                                                               limit:lim
                                                     sortDescriptors:@[timeSortDescriptor]
                                                      resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}

- (void)fetchSamplesOfType:(HKSampleType *)type
                              unit:(HKUnit *)unit
                         predicate:(NSPredicate *)predicate
                         ascending:(BOOL)asc
                             limit:(NSUInteger)lim
                        completion:(void (^)(NSArray *, NSError *))completion {
    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate
                                                                       ascending:asc];

    // declare the block
    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);
    // create and assign the block
    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (type == [HKObjectType workoutType]) {
                    for (HKWorkout *sample in results) {
                        double energy =  [[sample totalEnergyBurned] doubleValueForUnit:[HKUnit kilocalorieUnit]];
                        double distance = [[sample totalDistance] doubleValueForUnit:[HKUnit mileUnit]];
                        NSString *type = [RCTAppleHealthKit stringForHKWorkoutActivityType:[sample workoutActivityType]];

                        NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                        NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                        bool isTracked = true;
                        if ([[sample metadata][HKMetadataKeyWasUserEntered] intValue] == 1) {
                            isTracked = false;
                        }

                        NSString* device = @"";
                        if (@available(iOS 11.0, *)) {
                            device = [[sample sourceRevision] productType];
                        } else {
                            device = [[sample device] name];
                            if (!device) {
                                device = @"iPhone";
                            }
                        }

                        NSDictionary *elem = @{
                                               @"activityId" : [NSNumber numberWithInt:[sample workoutActivityType]],
                                               @"activityName" : type,
                                               @"calories" : @(energy),
                                               @"tracked" : @(isTracked),
                                               @"sourceName" : [[[sample sourceRevision] source] name],
                                               @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                                               @"device": device,
                                               @"distance" : @(distance),
                                               @"start" : startDateString,
                                               @"end" : endDateString
                                               };

                        [data addObject:elem];
                    }
                } else {
                    for (HKQuantitySample *sample in results) {
                        HKQuantity *quantity = sample.quantity;
                        double value = [quantity doubleValueForUnit:unit];

                        NSString * valueType = @"quantity";
                        if (unit == [HKUnit mileUnit]) {
                            valueType = @"distance";
                        }

                        NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                        NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                        bool isTracked = true;
                        if ([[sample metadata][HKMetadataKeyWasUserEntered] intValue] == 1) {
                            isTracked = false;
                        }

                        NSString* device = @"";
                        if (@available(iOS 11.0, *)) {
                            device = [[sample sourceRevision] productType];
                        } else {
                            device = [[sample device] name];
                            if (!device) {
                                device = @"iPhone";
                            }
                        }

                        NSDictionary *elem = @{
                                               valueType : @(value),
                                               @"tracked" : @(isTracked),
                                               @"sourceName" : [[[sample sourceRevision] source] name],
                                               @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                                               @"device": device,
                                               @"start" : startDateString,
                                               @"end" : endDateString
                                               };

                        [data addObject:elem];
                    }
                }

                completion(data, error);
            });
        }
    };

    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:type
                                                           predicate:predicate
                                                               limit:lim
                                                     sortDescriptors:@[timeSortDescriptor]
                                                      resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}

- (void)setObserverForType:(HKSampleType *)type
                      unit:(HKUnit *)unit {
    HKObserverQuery *query = [[HKObserverQuery alloc] initWithSampleType:type predicate:nil updateHandler:^(HKObserverQuery *query, HKObserverQueryCompletionHandler completionHandler, NSError * _Nullable error){
        if (error) {
            NSLog(@"*** An error occured while setting up the stepCount observer. %@ ***", error.localizedDescription);
            return;
        }
        [self.bridge.eventDispatcher sendAppEventWithName:@"observer" body:@""];

        // Theoretically, HealthKit expect that copletionHandler would be called at the end of query process,
        // but it's unclear how to do in in event paradigm

//        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 5);
//        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
//            completionHandler();
//        });
    }];

    [self.healthStore executeQuery:query];
    [self.healthStore enableBackgroundDeliveryForType:type frequency:HKUpdateFrequencyImmediate withCompletion:^(BOOL success, NSError * _Nullable error) {
        NSLog(@"success %s print some error %@", success ? "true" : "false", [error localizedDescription]);
    }];
}

- (void)fetchSleepCategorySamplesForPredicate:(NSPredicate *)predicate
                                   limit:(NSUInteger)lim
                                   completion:(void (^)(NSArray *, NSError *))completion {

    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate
                                                                       ascending:false];


    // declare the block
    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);
    // create and assign the block
    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

            dispatch_async(dispatch_get_main_queue(), ^{

                for (HKCategorySample *sample in results) {

                    // HKCategoryType *catType = sample.categoryType;
                    NSInteger val = sample.value;

                    // HKQuantity *quantity = sample.quantity;
                    // double value = [quantity doubleValueForUnit:unit];

                    NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                    NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                    NSString *valueString;
                    
                    switch (val) {
                      case HKCategoryValueSleepAnalysisInBed:
                        valueString = @"INBED";
                      break;
                      case HKCategoryValueSleepAnalysisAsleep:
                        valueString = @"ASLEEP";
                      break;
                     default:
                        valueString = @"UNKNOWN";
                     break;
                  }

                    NSDictionary *deviceInfo = [self deviceInfoForSample:sample];

                    NSDictionary *elem = @{
                            @"value" : valueString,
                            @"sourceName" : [[[sample sourceRevision] source] name],
                            @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                            @"startDate" : startDateString,
                            @"endDate" : endDateString,
                            @"deviceInfo" : deviceInfo
                    };

                    [data addObject:elem];
                }

                completion(data, error);
            });
        }
    };

    // HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:quantityType
    //                                                        predicate:predicate
    //                                                            limit:lim
    //                                                  sortDescriptors:@[timeSortDescriptor]
    //                                                   resultsHandler:handlerBlock];

    HKCategoryType *categoryType =
    [HKObjectType categoryTypeForIdentifier:HKCategoryTypeIdentifierSleepAnalysis];

    // HKCategorySample *categorySample =
    // [HKCategorySample categorySampleWithType:categoryType
    //                                    value:value
    //                                startDate:startDate
    //                                  endDate:endDate];


   HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:categoryType
                                                          predicate:predicate
                                                              limit:lim
                                                    sortDescriptors:@[timeSortDescriptor]
                                                     resultsHandler:handlerBlock];


    [self.healthStore executeQuery:query];
}













- (void)fetchCorrelationSamplesOfType:(HKQuantityType *)quantityType
                                 unit:(HKUnit *)unit
                            predicate:(NSPredicate *)predicate
                            ascending:(BOOL)asc
                                limit:(NSUInteger)lim
                           completion:(void (^)(NSArray *, NSError *))completion {

    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate
                                                                       ascending:asc];

    // declare the block
    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);
    // create and assign the block
    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

            dispatch_async(dispatch_get_main_queue(), ^{

                for (HKCorrelation *sample in results) {
                    NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                    NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                    NSDictionary *elem = @{
                      @"correlation" : sample,
                      @"startDate" : startDateString,
                      @"endDate" : endDateString,
                    };
                    [data addObject:elem];
                }

                completion(data, error);
            });
        }
    };

    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:quantityType
                                                           predicate:predicate
                                                               limit:lim
                                                     sortDescriptors:@[timeSortDescriptor]
                                                      resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}


- (void)fetchSumOfSamplesTodayForType:(HKQuantityType *)quantityType
                                 unit:(HKUnit *)unit
                           completion:(void (^)(double, NSError *))completionHandler {

    NSPredicate *predicate = [RCTAppleHealthKit predicateForSamplesToday];
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:quantityType
                                                          quantitySamplePredicate:predicate
                                                          options:HKStatisticsOptionCumulativeSum
                                                          completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
                                                                HKQuantity *sum = [result sumQuantity];
                                                                if (completionHandler) {
                                                                    double value = [sum doubleValueForUnit:unit];
                                                                    completionHandler(value, error);
                                                                }
                                                          }];

    [self.healthStore executeQuery:query];
}


- (void)fetchSumOfSamplesOnDayForType:(HKQuantityType *)quantityType
                                 unit:(HKUnit *)unit
                                  day:(NSDate *)day
                           completion:(void (^)(double, NSDate *, NSDate *, NSError *))completionHandler {

    NSPredicate *predicate = [RCTAppleHealthKit predicateForSamplesOnDay:day];
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:quantityType
                                                          quantitySamplePredicate:predicate
                                                          options:HKStatisticsOptionCumulativeSum
                                                          completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
                                                              HKQuantity *sum = [result sumQuantity];
                                                              NSDate *startDate = result.startDate;
                                                              NSDate *endDate = result.endDate;
                                                              if (completionHandler) {
                                                                     double value = [sum doubleValueForUnit:unit];
                                                                     completionHandler(value,startDate, endDate, error);
                                                              }
                                                          }];

    [self.healthStore executeQuery:query];
}


- (void)fetchCumulativeSumStatisticsCollection:(HKQuantityType *)quantityType
                                          unit:(HKUnit *)unit
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate
                                    completion:(void (^)(NSArray *, NSError *))completionHandler {

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.day = 1;

    NSDateComponents *anchorComponents = [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                                     fromDate:[NSDate date]];
    anchorComponents.hour = 0;
    NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"metadata.%K != YES", HKMetadataKeyWasUserEntered];
    // Create the query
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                           quantitySamplePredicate:predicate
                                                                                           options:HKStatisticsOptionCumulativeSum
                                                                                        anchorDate:anchorDate
                                                                                intervalComponents:interval];

    // Set the results handler
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *results, NSError *error) {
        if (error) {
            // Perform proper error handling here
            NSLog(@"*** An error occurred while calculating the statistics: %@ ***",error.localizedDescription);
        }

        NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];
        [results enumerateStatisticsFromDate:startDate
                                      toDate:endDate
                                   withBlock:^(HKStatistics *result, BOOL *stop) {

                                       HKQuantity *quantity = result.sumQuantity;
                                       if (quantity) {
                                           NSDate *date = result.startDate;
                                           double value = [quantity doubleValueForUnit:[HKUnit countUnit]];
                                           NSLog(@"%@: %f", date, value);

                                           NSString *dateString = [RCTAppleHealthKit buildISO8601StringFromDate:date];
                                           NSArray *elem = @[dateString, @(value)];
                                           [data addObject:elem];
                                       }
                                   }];
        NSError *err;
        completionHandler(data, err);
    };

    [self.healthStore executeQuery:query];
}


- (void)fetchCumulativeSumStatisticsCollection:(HKQuantityType *)quantityType
                                          unit:(HKUnit *)unit
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate
                                     ascending:(BOOL)asc
                                         limit:(NSUInteger)lim
                                    completion:(void (^)(NSArray *, NSError *))completionHandler {

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.day = 1;

    NSDateComponents *anchorComponents = [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                                     fromDate:[NSDate date]];
    anchorComponents.hour = 0;
    NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"metadata.%K != YES", HKMetadataKeyWasUserEntered];
    // Create the query
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                           quantitySamplePredicate:predicate
                                                                                           options:HKStatisticsOptionCumulativeSum | HKStatisticsOptionSeparateBySource
                                                                                        anchorDate:anchorDate
                                                                                intervalComponents:interval];

    // Set the results handler
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *results, NSError *error) {
        if (error) {
            // Perform proper error handling here
            NSLog(@"*** An error occurred while calculating the statistics: %@ ***", error.localizedDescription);
        }

        NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

        [results enumerateStatisticsFromDate:startDate
                                      toDate:endDate
                                   withBlock:^(HKStatistics *result, BOOL *stop) {

                                       HKQuantity *quantity = result.sumQuantity;
                                       if (quantity) {
                                           NSDate *startDate = result.startDate;
                                           NSDate *endDate = result.endDate;
                                           double value = [quantity doubleValueForUnit:unit];

                                           NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:startDate];
                                           NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:endDate];

                                           NSArray *sources = result.sources;
                                           NSMutableArray *sourceNames = [NSMutableArray array];
                                           for (HKSource *source in sources) {
                                               [sourceNames addObject:source.name];
                                           } 

                                           NSDictionary *elem = @{
                                                   @"value" : @(value),
                                                   @"startDate" : startDateString,
                                                   @"endDate" : endDateString,
                                                   @"sourceNames" : sourceNames
                                           };
                                           [data addObject:elem];
                                       }
                                   }];
        // is ascending by default
        if(asc == false) {
            [RCTAppleHealthKit reverseNSMutableArray:data];
        }

        if((lim > 0) && ([data count] > lim)) {
            NSArray* slicedArray = [data subarrayWithRange:NSMakeRange(0, lim)];
            NSError *err;
            completionHandler(slicedArray, err);
        } else {
            NSError *err;
            completionHandler(data, err);
        }
    };

    [self.healthStore executeQuery:query];
}

- (void)fetchCumulativeSumStatisticsCollection:(HKQuantityType *)quantityType
                                          unit:(HKUnit *)unit
                                          period:(NSUInteger)period
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate
                                     ascending:(BOOL)asc
                                         limit:(NSUInteger)lim
                                         includeManuallyAdded:(BOOL)includeManuallyAdded
                                    completion:(void (^)(NSArray *, NSError *))completionHandler {

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.minute = period;

    NSDateComponents *anchorComponents = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                                     fromDate:startDate];
    //anchorComponents.hour = 0;
    NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
    NSPredicate *predicate = nil;
    if (includeManuallyAdded == false) {
        predicate = [NSPredicate predicateWithFormat:@"metadata.%K != YES", HKMetadataKeyWasUserEntered];
    }
    // Create the query
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                           quantitySamplePredicate:predicate
                                                                                           options:HKStatisticsOptionCumulativeSum | HKStatisticsOptionSeparateBySource
                                                                                        anchorDate:anchorDate
                                                                                intervalComponents:interval];

    // Set the results handler
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *results, NSError *error) {
        if (error) {
            // Perform proper error handling here
            NSLog(@"*** An error occurred while calculating the statistics: %@ ***", error.localizedDescription);
        }

        NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

        [results enumerateStatisticsFromDate:startDate
                                      toDate:endDate
                                   withBlock:^(HKStatistics *result, BOOL *stop) {

                                       HKQuantity *quantity = result.sumQuantity;
                                       if (quantity) {
                                           NSDate *startDate = result.startDate;
                                           NSDate *endDate = result.endDate;
                                           double value = [quantity doubleValueForUnit:unit];

                                           NSArray *sources = result.sources;
                                           NSMutableArray *sourceNames = [NSMutableArray array];
                                           for (HKSource *source in sources) {
                                               [sourceNames addObject:source.name];
                                           } 

                                           NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:startDate];
                                           NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:endDate];
                                           
                                           NSDictionary *elem = @{
                                                   @"value" : @(value),
                                                   @"startDate" : startDateString,
                                                   @"endDate" : endDateString,
                                                   @"sourceNames" : sourceNames
                                           };
                                           [data addObject:elem];
                                       }
                                   }];
        // is ascending by default
        if(asc == false) {
            [RCTAppleHealthKit reverseNSMutableArray:data];
        }

        if((lim > 0) && ([data count] > lim)) {
            NSArray* slicedArray = [data subarrayWithRange:NSMakeRange(0, lim)];
            NSError *err;
            completionHandler(slicedArray, err);
        } else {
            NSError *err;
            completionHandler(data, err);
        }
    };

    [self.healthStore executeQuery:query];
}


- (NSDictionary *) workoutActivityTypeDict {
    NSDictionary *workoutActivities = @{
                                        @(HKWorkoutActivityTypeAmericanFootball): @"AmericanFootball",
                                        @(HKWorkoutActivityTypeArchery): @"Archery",
                                        @(HKWorkoutActivityTypeAustralianFootball): @"AustralianFootball",
                                        @(HKWorkoutActivityTypeBadminton): @"Badminton",
                                        @(HKWorkoutActivityTypeBaseball): @"Baseball",
                                        @(HKWorkoutActivityTypeBasketball): @"Basketball",
                                        @(HKWorkoutActivityTypeBowling): @"Bowling",
                                        @(HKWorkoutActivityTypeBoxing): @"Boxing",
                                        @(HKWorkoutActivityTypeClimbing): @"Climbing",
                                        @(HKWorkoutActivityTypeCricket): @"Cricket",
                                        @(HKWorkoutActivityTypeCrossTraining): @"CrossTraining",
                                        @(HKWorkoutActivityTypeCurling): @"Curling",
                                        @(HKWorkoutActivityTypeCycling): @"Cycling",
                                        @(HKWorkoutActivityTypeDance): @"Dance",
                                        @(HKWorkoutActivityTypeCardioDance): @"Dance",
                                        @(HKWorkoutActivityTypeSocialDance): @"Dance",
                                        @(HKWorkoutActivityTypeDanceInspiredTraining): @"DanceInspiredTraining",
                                        @(HKWorkoutActivityTypeElliptical): @"Elliptical",
                                        @(HKWorkoutActivityTypeEquestrianSports): @"EquestrianSports",
                                        @(HKWorkoutActivityTypeFencing): @"Fencing",
                                        @(HKWorkoutActivityTypeFishing): @"Fishing",
                                        @(HKWorkoutActivityTypeFunctionalStrengthTraining): @"FunctionalStrengthTraining",
                                        @(HKWorkoutActivityTypeGolf): @"Golf",
                                        @(HKWorkoutActivityTypeGymnastics): @"Gymnastics",
                                        @(HKWorkoutActivityTypeHandball): @"Handball",
                                        @(HKWorkoutActivityTypeHiking): @"Hiking",
                                        @(HKWorkoutActivityTypeHockey): @"Hockey",
                                        @(HKWorkoutActivityTypeHunting): @"Hunting",
                                        @(HKWorkoutActivityTypeLacrosse): @"Lacrosse",
                                        @(HKWorkoutActivityTypeMartialArts): @"MartialArts",
                                        @(HKWorkoutActivityTypeMindAndBody): @"MindAndBody",
                                        @(HKWorkoutActivityTypeMixedMetabolicCardioTraining): @"MixedMetabolicCardioTraining",
                                        @(HKWorkoutActivityTypePaddleSports): @"PaddleSports",
                                        @(HKWorkoutActivityTypePlay): @"Play",
                                        @(HKWorkoutActivityTypePreparationAndRecovery): @"PreparationAndRecovery",
                                        @(HKWorkoutActivityTypeRacquetball): @"Racquetball",
                                        @(HKWorkoutActivityTypeRowing): @"Rowing",
                                        @(HKWorkoutActivityTypeRugby): @"Rugby",
                                        @(HKWorkoutActivityTypeRunning): @"Running",
                                        @(HKWorkoutActivityTypeSailing): @"Sailing",
                                        @(HKWorkoutActivityTypeSkatingSports): @"SkatingSports",
                                        @(HKWorkoutActivityTypeSnowSports): @"SnowSports",
                                        @(HKWorkoutActivityTypeSoccer): @"Soccer",
                                        @(HKWorkoutActivityTypeSoftball): @"Softball",
                                        @(HKWorkoutActivityTypeSquash): @"Squash",
                                        @(HKWorkoutActivityTypeStairClimbing): @"StairClimbing",
                                        @(HKWorkoutActivityTypeSurfingSports): @"SurfingSports",
                                        @(HKWorkoutActivityTypeSwimming): @"Swimming",
                                        @(HKWorkoutActivityTypeTableTennis): @"TableTennis",
                                        @(HKWorkoutActivityTypeTennis): @"Tennis",
                                        @(HKWorkoutActivityTypeTrackAndField): @"TrackAndField",
                                        @(HKWorkoutActivityTypeTraditionalStrengthTraining): @"TraditionalStrengthTraining",
                                        @(HKWorkoutActivityTypeVolleyball): @"Volleyball",
                                        @(HKWorkoutActivityTypeWalking): @"Walking",
                                        @(HKWorkoutActivityTypeWaterFitness): @"WaterFitness",
                                        @(HKWorkoutActivityTypeWaterPolo): @"WaterPolo",
                                        @(HKWorkoutActivityTypeWaterSports): @"WaterSports",
                                        @(HKWorkoutActivityTypeWrestling): @"Wrestling",
                                        @(HKWorkoutActivityTypeYoga): @"Yoga",
                                        @(HKWorkoutActivityTypeOther): @"Other",
                                        @(HKWorkoutActivityTypeBarre): @"Barre",
                                        @(HKWorkoutActivityTypeCoreTraining): @"CoreTraining",
                                        @(HKWorkoutActivityTypeCrossCountrySkiing): @"CrossCountrySkiing",
                                        @(HKWorkoutActivityTypeDownhillSkiing): @"DownhillSkiing",
                                        @(HKWorkoutActivityTypeFlexibility): @"Flexibility",
                                        @(HKWorkoutActivityTypeCooldown): @"Cooldown",
                                        @(HKWorkoutActivityTypeHighIntensityIntervalTraining): @"HighIntensityIntervalTraining",
                                        @(HKWorkoutActivityTypeJumpRope): @"JumpRope",
                                        @(HKWorkoutActivityTypeKickboxing): @"Kickboxing",
                                        @(HKWorkoutActivityTypePilates): @"Pilates",
                                        @(HKWorkoutActivityTypeSnowboarding): @"Snowboarding",
                                        @(HKWorkoutActivityTypeStairs): @"Stairs",
                                        @(HKWorkoutActivityTypeStepTraining): @"StepTraining",
                                        @(HKWorkoutActivityTypeWheelchairWalkPace): @"WheelchairWalkPace",
                                        @(HKWorkoutActivityTypeWheelchairRunPace): @"WheelchairRunPace",
                                        @(HKWorkoutActivityTypeTaiChi): @"TaiChi",
                                        @(HKWorkoutActivityTypeMixedCardio): @"MixedCardio",
                                        @(HKWorkoutActivityTypeHandCycling): @"HandCycling",
                                        };
    return workoutActivities;
}


- (void)fetchWorkoutSamplesForPredicate:(NSPredicate *)predicate
                                        limit:(NSUInteger)lim
                                   completion:(void (^)(NSArray *, NSError *))completion {
    
    
    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate
                                                                       ascending:false];
    
    
    // declare the block
    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);
    // create and assign the block
    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        
        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary *activityDict = [self workoutActivityTypeDict];
                
                for (HKWorkout *sample in results) {
                    HKWorkoutActivityType type = sample.workoutActivityType;
                    NSTimeInterval duration = sample.duration;
                    NSInteger durationInt = round(duration);
                    
                    HKQuantity *totalDistance = sample.totalDistance;
                    HKQuantity *totalEnergyBurned = sample.totalEnergyBurned;
                    
                    NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                    NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];
                    
                    NSString *activityString = [activityDict objectForKey:@(type)];
                    if (!activityString) {
                        // Unknown
                        activityString = [NSString stringWithFormat:@"Activity-%@", @(type)];
                    }

                    NSDictionary *deviceInfo = [self deviceInfoForSample:sample];

                    NSDictionary *elem = @{
                                           @"startDate" : startDateString,
                                           @"endDate" : endDateString,
                                           @"activityType": activityString,
                                           @"duration": @(durationInt),
                                           @"totalDistance": totalDistance ? @([totalDistance doubleValueForUnit:[HKUnit meterUnit]]) : @(0),
                                           @"totalEnergyBurned": totalEnergyBurned ? @([totalEnergyBurned doubleValueForUnit:[HKUnit kilocalorieUnit]]) : @(0),
                                           @"deviceInfo" : deviceInfo
                                           };
                    
                    [data addObject:elem];
                    
                }
                
                completion(data, error);
            });
        }
    };
    
    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:[HKWorkoutType workoutType]
                                                           predicate:predicate
                                                               limit:lim
                                                     sortDescriptors:@[timeSortDescriptor]
                                                      resultsHandler:handlerBlock];
    
    
    [self.healthStore executeQuery:query];
}


- (NSDictionary *)deviceInfoForSample:(HKSample *)sample {
    if (sample && [sample isKindOfClass:[HKSample class]]) {
        NSString *deviceName = @"";
        if ([[sample device] name]) {
            deviceName = [[sample device] name];
        }
        NSString *deviceModel = @"";
        if ([[sample device] model]) {
            deviceModel = [[sample device] model];
        }
        NSString *sourceName = @"";
        if ([[[sample sourceRevision] source] name]) {
            sourceName = [[[sample sourceRevision] source] name];
        }
        NSString *productType = @"";
        if ([[sample sourceRevision] productType]) {
            productType = [[sample sourceRevision] productType];
        }

        NSDictionary *deviceInfo = @{
            @"sourceName" : sourceName,
            @"productType" : productType,
            @"deviceName" : deviceName,
            @"deviceModel" : deviceModel
            };

        return deviceInfo;
    }

    return @{};
}



@end