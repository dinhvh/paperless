//
//  PLCompletion.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 22/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PLCompletionTree;

@interface PLCompletion : NSObject {
	PLCompletionTree * _root;
}

- (id) init;
- (void) dealloc;

- (void) addDocumentWithName:(NSString *)name;
- (void) removeDocumentWithName:(NSString *)name;
- (NSArray *) nameStartWith:(NSString *)name;
- (NSString *) probableNameStartWith:(NSString *)name;

@end
