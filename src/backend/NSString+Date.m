//
//  NSString+Date.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 18/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "NSString+Date.h"

#include <regex.h>

@implementation NSString (PLDate)

- (NSCalendarDate *) PLDate
{
    NSArray * array;
    NSString * yearStr;
    NSString  * monthStr;
    NSString * dayStr;
    int year;
    int month;
    int day;
    unsigned int yearIndex;
    
    array = [self componentsSeparatedByString:@"-"];
    if ([array count] < 4)
        return nil;
    
    yearIndex = [array count] - 3;
    while (yearIndex >= 1) {
        yearStr = [array objectAtIndex:yearIndex];
        year = [yearStr intValue];
        monthStr = [array objectAtIndex:yearIndex + 1];
        month = [monthStr intValue];
        dayStr = [array objectAtIndex:yearIndex + 2];
        day = [dayStr intValue];
        if ((year >= 1900) && ((month >= 1) && (month <= 12)) & ((day >= 1) && (day <= 31)))
            return [NSCalendarDate dateWithYear:year month:month day:day hour:12 minute:0 second:0 timeZone:[NSTimeZone systemTimeZone]];
        
        yearIndex --;
    }
    return nil;
}

- (NSString *) stringByRemovingPLDate
{
    NSArray * array;
    NSString * yearStr;
    NSString  * monthStr;
    NSString * dayStr;
    int year;
    int month;
    int day;
    NSMutableString * str;
    unsigned int i;
    
    array = [self componentsSeparatedByString:@"-"];
    if ([array count] < 4)
        return self;
    
    yearStr = [array objectAtIndex:[array count] - 3];
    year = [yearStr intValue];
    monthStr = [array objectAtIndex:[array count] - 2];
    month = [monthStr intValue];
    dayStr = [array objectAtIndex:[array count] - 1];
    day = [dayStr intValue];
    if (!((year >= 1900) && ((month >= 1) && (month <= 12)) & ((day >= 1) && (day <= 31))))
        return self;
    
    str = [NSMutableString string];
    for(i = 0 ; i < [array count] - 3 ; i ++) {
        if (i != 0) {
            [str appendString:@"-"];
        }
        [str appendString:[array objectAtIndex:i]];
    }
    
    return str;
}

- (NSString *) stringByAppendingPLDate
{
    return [self stringByAppendingPLDate:[NSDate date]];
}

- (NSString *) stringByAppendingPLDate:(NSDate *)date
{
    NSMutableString * str;
    
    str = [self mutableCopy];
    [str appendString:[date descriptionWithCalendarFormat:@"-%Y-%m-%d" timeZone:nil locale:nil]];
    
    return [str autorelease];
}

- (NSString *) stringByAppendingPLDateIfNeeded
{
    if ([self PLDate] == nil) {
        return [self stringByAppendingPLDate];
    }
    else {
        return self;
    }
}

@end
