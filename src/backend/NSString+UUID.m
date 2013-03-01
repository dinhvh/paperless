//
//  NSString+UUID.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 19/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "NSString+UUID.h"

@implementation NSString (UUID)

+ (NSString*) stringWithNewUUID
{
    // Create a new UUID
    CFUUIDRef uuidObj = CFUUIDCreate(nil);
    
    // Get the string representation of the UUID
    NSString *newUUID = (NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    return [newUUID autorelease];
}

@end