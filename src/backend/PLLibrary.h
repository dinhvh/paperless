//
//  PLLibrary.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 16/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PLSQLDB;
@class PLIndex;
@class PLLibraryLoadOperation;
@class PLLibrarySearchOperation;
@class PLDocument;
@class PLCompletion;

@protocol PLLibrarySearchDelegate

- (void) plLibrary_searchDone:(NSArray *)documentList;

@end

@interface PLLibrary : NSObject {
    PLSQLDB * _db;
    PLIndex * _index;
    BOOL _loaded;
    BOOL _cancelled;
    NSError * _loadError;
    NSMutableDictionary * _documentDict;
    PLLibraryLoadOperation * _loadOp;
    PLLibrarySearchOperation * _searchOp;
    id <PLLibrarySearchDelegate> _delegate;
    BOOL _libraryLoading;
    NSMutableDictionary * _untitledDict;
    PLCompletion * _completion;
}

- (id) init;
- (void) dealloc;

@property (readonly) BOOL loaded;
@property (readonly) BOOL cancelled;
@property (readonly) PLSQLDB * db;
@property (readonly) PLIndex * index;
@property (readonly) NSDictionary * documentDict;

- (NSString *) contentsPath;

- (void) save;

- (void) cancelLoad;

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;

- (void) search:(NSString *)searchString delegate:(id <PLLibrarySearchDelegate>)delegate;

- (NSArray *) allKeys;
- (PLDocument *) documentForKey:(NSString *)key;
- (void) addDocument:(PLDocument *)document;
- (void) modifyDocument:(PLDocument *)document;
- (void) modifyDocument:(PLDocument *)document oldName:(NSString *)oldName;
- (void) removeDocumentForKey:(NSString *)key;

- (void) beginTransaction;
- (void) endTransaction;

- (BOOL) loading;

- (NSString *) getUntitledName;

- (void) searchBeginsWith:(NSString *)searchString delegate:(id <PLLibrarySearchDelegate>)delegate;
- (NSArray *) nameStartWith:(NSString *)name;
- (NSString *) probableNameStartWith:(NSString *)name;

@end
