//
//  NSArray+sort.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 28/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSArray (PLSort)

- (NSUInteger) indexOfObjectInSortedArray:(id)anObject selector:(SEL)selector;
- (NSUInteger) indexOfObjectInSortedArray:(id)anObject selector:(SEL)selector inRange:(NSRange)range;

@end
