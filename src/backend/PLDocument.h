//
//  PLDocument.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 16/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PLLibrary;

#define PLMDNAMEKEY @"org.etpan.PaperLess.document.name"
#define PLMDCOMMENTKEY @"org.etpan.PaperLess.document.comment"

@interface PLDocument : NSObject {
    NSString * _uid;
    NSString * _name;
    time_t _timestamp;
    PLLibrary * _library;
    BOOL _inDatabase;
    NSString * _comment;
    BOOL _importInProgress;
}

- (id) initWithLibrary:(PLLibrary *)library;
- (void) dealloc;

@property (copy) NSString * uid;
@property time_t timestamp;
@property (readonly) PLLibrary * library;
@property BOOL inDatabase;
@property (copy) NSString * name;
@property BOOL importInProgress;

- (void) setComment:(NSString *)comment;
- (NSString *) comment;

- (NSComparisonResult) compareDate:(PLDocument *)doc;

- (NSString *) indexString;

- (NSUInteger) hash;

- (NSString *) filename;

- (void) importMetaData;

@end
