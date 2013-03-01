//
//  PLDocumentByDate.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 19/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLDocumentByDate.h"

#import "PLDocument.h"
#import "PLLibrary.h"
#import "NSArray+sort.h"

@interface PLDocumentByDate (Private)

- (unsigned int) _intervalForDocument:(PLDocument *)document;

@end

@implementation PLDocumentByDate

- (id) init
{
    self = [super init];
    
	_intervalList = [[NSMutableArray alloc] init];
    [_intervalList addObject:[NSNumber numberWithInt:1]];
    [_intervalList addObject:[NSNumber numberWithInt:2]];
    [_intervalList addObject:[NSNumber numberWithInt:7]];
    [_intervalList addObject:[NSNumber numberWithInt:30]];
    // then, by year
    
	_documentByIntervalList = [[NSMutableArray alloc] init];
    [_documentByIntervalList addObject:[NSMutableArray array]];
    [_documentByIntervalList addObject:[NSMutableArray array]];
    [_documentByIntervalList addObject:[NSMutableArray array]];
    [_documentByIntervalList addObject:[NSMutableArray array]];
    
    return self;
}

- (void) dealloc
{
    [_documentByIntervalList release];
    [_intervalList release];
    
    [super dealloc];
}

- (void) addDocumentList:(NSArray *)documentList
{
    unsigned int i;
    
    for(i = 0 ; i < [documentList count] ; i ++) {
        [self addDocument:[documentList objectAtIndex:i] sort:NO];
    }
    [self sort];
}

- (void) addDocument:(PLDocument *)document
{
    [self addDocument:document sort:YES];
}

- (unsigned int) _intervalForDocument:(PLDocument *)document
{
#if 0
    time_t timestamp;
    time_t docTimestamp;
    time_t age;
    unsigned int i;
    struct tm docTimeData;
    struct tm timeData;
    int yearDiff;
    unsigned int intervalIndex;
    NSDate * date;
	
    timestamp = time(NULL);
    date = [NSDate dateWithTimeIntervalSinceReferenceDate:[document timestamp]];
    docTimestamp = [date timeIntervalSince1970];
    age = timestamp - docTimestamp;
    age = age / (24 * 60 * 60);
    for(i = 0 ; i < [_intervalList count] ; i ++) {
        NSNumber * nbAge;
        
        nbAge = [_intervalList objectAtIndex:i];
        if (age <= [nbAge intValue]) {
            return i;
        }
    }
    
    localtime_r(&docTimestamp, &docTimeData);
    localtime_r(&timestamp, &timeData);
    yearDiff = timeData.tm_year - docTimeData.tm_year;
    intervalIndex = yearDiff + [_intervalList count];
    while ([_documentByIntervalList count] <= intervalIndex) {
        [_documentByIntervalList addObject:[NSMutableArray array]];
    }
    
    return intervalIndex;
#else
    NSCalendarDate * date;
    NSCalendarDate * today;
    NSCalendar * calendar;
    
    calendar = [NSCalendar currentCalendar];
    
    date = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:[document timestamp]];
    today = [NSCalendarDate date];
    
    if ([date dayOfCommonEra] == [today dayOfCommonEra]) {
        return 0;
    }
    else if ([date dayOfCommonEra] == [today dayOfCommonEra] - 1) {
        return 1;
    }
    else {
        unsigned int interval;
        
        if ([date dayOfCommonEra] >= [today dayOfCommonEra] - 6) {
            if ([date dayOfWeek] < [today dayOfWeek]) {
                return 2;
            }
        }
        if ([today timeIntervalSinceReferenceDate] < [date timeIntervalSinceReferenceDate]) {
            interval = 0;
        }
        else {
            interval = (12 - ([date monthOfYear] - 1)) + ([today yearOfCommonEra] - [date yearOfCommonEra]) * 12 + 3;
        }
        //NSLog(@"%@ %u %u", [document name], interval, [date yearOfCommonEra]);
        while ([_documentByIntervalList count] <= interval) {
            [_documentByIntervalList addObject:[NSMutableArray array]];
        }
        
        return interval;
    }
#endif
}


- (NSString *) dateDescriptionForInterval:(unsigned int)intervalIndex
{
#if 0
    switch (intervalIndex) {
        case 0:
            // today
            return @"Today";
            break;
        case 1:
            // yesterday
            return @"Yesterday";
            break;
        case 2:
            // this week
            return @"This week";
            break;
        case 3:
            // this month
            return @"This month";
            break;
        default:
        {
            // year
            int year;
            time_t date;
            struct tm gm_value;
            
            date = time(NULL);
            localtime_r(&date, &gm_value);
            year = gm_value.tm_year + 1900 - (intervalIndex - [_intervalList count]);
            return [NSString stringWithFormat:@"Year %i", year];
            break;
        }
    }
#else
    NSCalendarDate * today;
    
    today = [NSCalendarDate date];
    
    switch (intervalIndex) {
        case 0:
            // today
            return @"Today";
        case 1:
            // yesterday
            return @"Yesterday";
        case 2:
            // this week
            return @"This week";
        default:
        {
            unsigned int month;
            unsigned int year;
            NSCalendarDate * date;
            
            month = (12 - (intervalIndex - 3) % 12) + 1;
            year = [today yearOfCommonEra] - (intervalIndex - 3) / 12;
            
            date = [NSCalendarDate dateWithYear:year month:month day:1 hour:12 minute:0 second:0 timeZone:nil];
            return [date descriptionWithCalendarFormat:@"%b %Y" timeZone:nil locale:nil];
            //return [NSString stringWithFormat:@"%02u/%u", month, year];
        }
    }
#endif
}

- (void) addDocument:(PLDocument *)document sort:(BOOL)sort
{
    unsigned int interval;
    NSMutableArray * documentList;
    
    interval = [self _intervalForDocument:document];
    documentList = [_documentByIntervalList objectAtIndex:interval];
    [documentList addObject:document];
    if (sort) {
        [documentList sortUsingSelector:@selector(compareDate:)];
    }
}

- (void) sort
{
    unsigned int i;
    
    for(i = 0 ; i < [_documentByIntervalList count] ; i ++) {
        NSMutableArray * table;
        
        table = [_documentByIntervalList objectAtIndex:i];
        [table sortUsingSelector:@selector(compareDate:)];
    }
}

- (NSArray *) documentByIntervalList
{
    return _documentByIntervalList;
}

- (void) removeDocumentList:(NSArray *)documentListToRemove
{
    unsigned int k;
    
    for(k = 0 ; k < [_documentByIntervalList count] ; k ++) {
        NSMutableIndexSet * indexSet;
        NSMutableArray * documentList;
        unsigned int i;
        
        indexSet = [[NSMutableIndexSet alloc] init];
        documentList = [_documentByIntervalList objectAtIndex:k];
        
        for(i = 0 ; i < [documentListToRemove count] ; i ++) {
            unsigned int interval;
            PLDocument * doc;
            
            doc = [documentListToRemove objectAtIndex:i];
            
            interval = [self _intervalForDocument:doc];
            if (interval == k) {
                NSUInteger foundIndex;
                
                foundIndex = [documentList indexOfObjectInSortedArray:doc selector:@selector(compareDate:)];
                if (foundIndex != NSNotFound) {
                    [indexSet addIndex:foundIndex];
                }
            }
        }
        
        [documentList removeObjectsAtIndexes:indexSet];
        [indexSet release];
    }
}

- (void) removeDocument:(PLDocument *)document
{
    unsigned int interval;
    NSMutableArray * documentList;
    NSUInteger foundIndex;
    
    interval = [self _intervalForDocument:document];
    documentList = [_documentByIntervalList objectAtIndex:interval];
    foundIndex = [documentList indexOfObjectInSortedArray:document selector:@selector(compareDate:)];
    if (foundIndex != NSNotFound) {
        [documentList removeObjectAtIndex:foundIndex];
    }
}

@end
