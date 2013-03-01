//
//  PLSQLDB.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 3/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <sqlite3.h>

@interface PLSQLDB : NSObject {
	NSMutableDictionary * _statementHash;
	sqlite3 * _db;
	NSString * _filename;
	NSArray * _columns;
}

- (id) initWithFilename:(NSString *)filename columns:(NSArray *)columns;
- (void) dealloc;

- (BOOL) open;
- (void) close;

- (id) objectForKey:(NSString *)keyStr column:(NSString *)column;
- (BOOL) setObject:(id)object forKey:(NSString *)key column:(NSString *)column;
- (void) removeObjectForKey:(NSString *)key;
- (void) removeAllObjects;

- (NSArray *) allKeys;

- (void) beginTransaction;
- (void) endTransaction;

@end
