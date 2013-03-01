//
//  PLDocumentByDate.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 19/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PLDocument;
@class PLLibrary;

@interface PLDocumentByDate : NSObject {
	NSMutableArray * _intervalList;
	NSMutableArray * _documentByIntervalList;
    PLLibrary * _library;
}

- (id) init;
- (void) dealloc;
- (void) addDocumentList:(NSArray *)documentList;
- (void) addDocument:(PLDocument *)document;
- (void) addDocument:(PLDocument *)document sort:(BOOL)sort;
- (void) removeDocument:(PLDocument *)document;
- (void) removeDocumentList:(NSArray *)documentList;
- (void) sort;

- (NSArray *) documentByIntervalList;

- (NSString *) dateDescriptionForInterval:(unsigned int)intervalIndex;

@end
