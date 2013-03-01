//
//  PLIndex.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 16/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PLIndex : NSObject {
	SKIndexRef _index;
    NSString * _filename;
}

- (id) initWithFilename:(NSString *)filename;
- (void) dealloc;

- (BOOL) open;
- (void) close;

- (BOOL) setString:(NSString *)str forKey:(NSString *)key;
- (void) removeKey:(NSString *)key;

- (NSArray *) search:(NSString *)searchStr;
- (NSArray *) searchBeginsWith:(NSString *)searchStr;

- (void) save;

@end
