//
//  NSArray+sort.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 28/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "NSArray+sort.h"

@implementation NSArray (PLSort)

- (NSUInteger) indexOfObjectInSortedArray:(id)anObject selector:(SEL)selector
{
    return [self indexOfObjectInSortedArray:anObject selector:selector inRange:NSMakeRange(0, [self count])];
}

static NSComparisonResult compare(id anObject, id other, SEL selector)
{
    NSComparisonResult result;
    NSInvocation * invocation;
    
    invocation = [NSInvocation invocationWithMethodSignature:[[anObject class] instanceMethodSignatureForSelector:selector]];
    [invocation setTarget:anObject];
    [invocation setSelector:selector];
    [invocation setArgument:&other atIndex:2];
    [invocation invoke];
    [invocation getReturnValue:&result];
    
    return result;
}

- (NSUInteger) indexOfObjectInSortedArray:(id)anObject selector:(SEL)selector inRange:(NSRange)range
{
    id other;
    NSComparisonResult result;
    unsigned int middle;
    
    if (range.length == 0)
        return NSNotFound;
    
    if (range.length == 1) {
        other = [self objectAtIndex:range.location];
        if (other == anObject)
            return range.location;
        else
            return NSNotFound;
    }
    
    middle = range.location + range.length / 2;
    other = [self objectAtIndex:middle];
    // fast path
    if (other == anObject)
        return middle;
    
    result = compare(anObject, other, selector);
    if (result == NSOrderedSame) {
        unsigned int location;
        unsigned int i;
        
        location = middle;
        while (location >= range.location) {
            id objectAtLocation;
            
            objectAtLocation = [self objectAtIndex:location];
            if (compare(other, objectAtLocation, selector) == NSOrderedSame) {
                middle = location;
            }
            if (location == 0)
                break;
            location --;
        }
        for(i = middle ; i < range.location + range.length ; i ++) {
            id current;
            
            current = [self objectAtIndex:i];
            if (compare(current, other, selector) != NSOrderedSame) {
                break;
            }
            if (current == anObject) {
                return i;
            }
        }
        
        return NSNotFound;
    }
    else if (result == NSOrderedAscending) {
        NSRange newRange;
        
        newRange = NSMakeRange(range.location, range.length / 2);
        return [self indexOfObjectInSortedArray:anObject selector:selector inRange:newRange];
    }
    else /* if (result == NSOrderedDescending) */ {
        NSRange newRange;
        
        if (range.length - range.length / 2 - 1 == 0) {
            return NSNotFound;
        }
        newRange = NSMakeRange(range.location + range.length / 2 + 1, range.length - range.length / 2 - 1);
        return [self indexOfObjectInSortedArray:anObject selector:selector inRange:newRange];
    }
}

@end
