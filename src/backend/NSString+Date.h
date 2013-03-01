//
//  NSString+Date.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 18/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString (PLDate)

- (NSCalendarDate *) PLDate;
- (NSString *) stringByRemovingPLDate;
- (NSString *) stringByAppendingPLDate;
- (NSString *) stringByAppendingPLDate:(NSDate *)date;
- (NSString *) stringByAppendingPLDateIfNeeded;

@end
