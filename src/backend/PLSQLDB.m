//
//  PLSQLDB.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 3/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLSQLDB.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

@interface PLSQLDB (Private)

- (sqlite3 *) privateGetSQLite;
- (BOOL) privatePrepareStatement:(NSString *)sql;
- (BOOL) privateExecute:(NSString *)sql;
- (BOOL) privatePrepare;
- (void) privateUnprepare;
- (BOOL) privateTryOpen;

@end

@interface PLSQLStatement : NSObject {
	NSString * _sql;
	sqlite3_stmt * _statement;
	PLSQLDB * _db;
}

- (id) initWithSQL:(NSString *)sql db:(PLSQLDB *)db;
- (void) dealloc;

- (BOOL) prepare;

- (sqlite3_stmt *) getStatement;

@end

@implementation PLSQLStatement

- (id) initWithSQL:(NSString *)sql db:(PLSQLDB *)db
{
    self = [super init];
    
	_sql = [sql copy];
	_db = db;
    
    return self;
}

- (void) dealloc
{
    sqlite3_finalize(_statement);
	[_sql release];
	[super dealloc];
}

- (BOOL) prepare
{
    int r;
    
    r = sqlite3_prepare([_db privateGetSQLite], [_sql UTF8String], -1, &_statement, 0);
    if (r != SQLITE_OK) {
        sqlite3_finalize(_statement);
        _statement = NULL;
        return NO;
    }
    
    return YES;
}

- (sqlite3_stmt *) getStatement
{
    return _statement;
}

@end


@implementation PLSQLDB

- (void) privateUnprepare
{
    [_statementHash removeAllObjects];
}

- (BOOL) privatePrepareStatement:(NSString *)sql
{
	PLSQLStatement * statement;
	
	statement = [[PLSQLStatement alloc] initWithSQL:sql db:self];
    if (![statement prepare]) {
        [statement release];
        
        return NO;
    }
	[_statementHash setObject:statement forKey:sql];
	[statement release];
    
    return YES;
}

- (sqlite3 *) privateGetSQLite
{
	return _db;
}

- (id) initWithFilename:(NSString *)filename columns:(NSArray *)columns
{
	self = [super init];
    
	_filename = [filename copy];
	_columns = [columns copy];
	_statementHash = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void) dealloc
{
	[_statementHash release];
	[_columns release];
	[_filename release];
	[super dealloc];
}

- (sqlite3_stmt *) privateGetStatement:(NSString *)sql
{
	return [[_statementHash objectForKey:sql] getStatement];
}

- (BOOL) privatePrepare
{
    NSAutoreleasePool * pool;
    unsigned int i;
    
    pool = [[NSAutoreleasePool alloc] init];
    for(i = 0 ; i < [_columns count] ; i ++) {
        NSString * name;
        
        name = [_columns objectAtIndex:i];
        if (![self privatePrepareStatement:[NSString stringWithFormat:@"SELECT %@ FROM kvstore WHERE key = ?", name]])
            goto err;
        if (![self privatePrepareStatement:[NSString stringWithFormat:@"INSERT OR ABORT INTO kvstore (key, %@) VALUES (?, ?)", name]])
            goto err;
        if (![self privatePrepareStatement:[NSString stringWithFormat:@"UPDATE kvstore SET %@ = ? WHERE key = ?", name]])
            goto err;
    }
    if (![self privatePrepareStatement:@"SELECT key FROM kvstore"])
        goto err;
    if (![self privatePrepareStatement:@"DELETE FROM kvstore WHERE key = ?"])
        goto err;
    
    [pool release];
	return YES;
    
err:
    [pool release];
    return NO;
}

- (BOOL) privateTryOpen
{
	int r;
    int file_exist;
    struct stat stat_buf;
    BOOL b;
    unsigned int i;
    
    file_exist = 1;
    r = stat([_filename fileSystemRepresentation], &stat_buf);
    if (r < 0)
        file_exist = 0;
    
    r = sqlite3_open([_filename fileSystemRepresentation], &_db);
    if (r != SQLITE_OK)
        return NO;
    
    if (!file_exist) {
        NSMutableString * str;
        
        str = [[NSMutableString alloc] init];
        [str appendString:@"CREATE TABLE kvstore (key TEXT UNIQUE PRIMARY KEY"];
        
        for(i = 0 ; i < [_columns count] ; i ++) {
            NSString * name;
            
            name = [_columns objectAtIndex:i];
            [str appendString:@", "];
            [str appendString:name];
            [str appendString:@" BLOB"];
        }
        [str appendString:@")"];
        
        [self privateExecute:str];
    }
    
    b = [self privatePrepare];
    if (!b) {
        sqlite3_close(_db);
        _db = NULL;
        return NO;
    }
    
    return YES;
}

- (BOOL) open
{
    BOOL b;
    
    b = [self privateTryOpen];
    if (!b) {
        unlink([_filename fileSystemRepresentation]);
        b = [self privateTryOpen];
        if (!b)
            return NO;
    }
    
    return YES;
}

- (void) close
{
    [self privateUnprepare];
    
    sqlite3_close(_db);
}

- (id) objectForKey:(NSString *)keyStr column:(NSString *)column
{
    NSString * str;
    sqlite3_stmt * statement;
    int r;
    int data_size;
    const void * data;
    NSData * objData;
    NSObject * object;
    
    str = [[NSString alloc] initWithFormat:@"SELECT %@ FROM kvstore WHERE key = ?", column];
    statement = [self privateGetStatement:str];
    [str release];
    
    sqlite3_bind_text(statement, 1, [keyStr UTF8String], -1, SQLITE_STATIC);
    r = sqlite3_step(statement);
    if (r != SQLITE_ROW) {
        goto reset;
    }
    
    data_size = sqlite3_column_bytes(statement, 0);
    if (data_size == 0) {
        goto reset;
    }
    
    data = sqlite3_column_blob(statement, 0);
    objData = [[NSData alloc] initWithBytesNoCopy:(void *) data length:data_size freeWhenDone:NO];
    object = [NSKeyedUnarchiver unarchiveObjectWithData:objData];
    [objData release];
    
    sqlite3_reset(statement);
    
    return object;

reset:
    sqlite3_reset(statement);
    return nil;
}

- (BOOL) setObject:(id)object forKey:(NSString *)key column:(NSString *)column
{
    sqlite3_stmt * statement;
    int r;
    NSData * data;
    NSString * str;
    
    str = [[NSString alloc] initWithFormat:@"INSERT OR ABORT INTO kvstore (key, %@) VALUES (?, ?)", column];
    statement = [self privateGetStatement:str];
    [str release];
    
    data = [NSKeyedArchiver archivedDataWithRootObject:object];
    
    sqlite3_bind_text(statement, 1, [key UTF8String], -1, SQLITE_STATIC);
    sqlite3_bind_blob(statement, 2, [data bytes], [data length], SQLITE_STATIC);
    r = sqlite3_step(statement);
    if (r != SQLITE_DONE) {
        sqlite3_reset(statement);
        
        str = [[NSString alloc] initWithFormat:@"UPDATE kvstore SET %@ = ? WHERE key = ?", column];
        statement = [self privateGetStatement:str];
        [str release];
        
        sqlite3_bind_blob(statement, 1, [data bytes], [data length], SQLITE_STATIC);
        sqlite3_bind_text(statement, 2, [key UTF8String], -1, SQLITE_STATIC);
        r = sqlite3_step(statement);
        if (r != SQLITE_DONE) {
            //NSLog(@"error storing %@", key);
            goto reset;
        }
    }
    
    sqlite3_reset(statement);
    
    return YES;
    
reset:
    sqlite3_reset(statement);
    return NO;
}

- (void) removeObjectForKey:(NSString *)key
{
    int r;
    sqlite3_stmt * statement;
    
    statement = [self privateGetStatement:@"DELETE FROM kvstore WHERE key = ?"];
    
    sqlite3_bind_text(statement, 1, [key UTF8String], -1, SQLITE_STATIC);
    r = sqlite3_step(statement);
    sqlite3_reset(statement);
    
    if (r != SQLITE_DONE) {
        //NSLog(@"error deleting %@", key);
        return;
    }
}

- (NSArray *) allKeys
{
    NSMutableArray * keys;
    int r;
    sqlite3_stmt * statement;
    
    statement = [self privateGetStatement:@"SELECT key FROM kvstore"];
    keys = [[NSMutableArray alloc] init];
    
    r = sqlite3_step(statement);
    while (r == SQLITE_ROW) {
        char * key;
        NSString * str;
        
        key = (char *) sqlite3_column_text(statement, 0);
        str = [[NSString alloc] initWithUTF8String:key];
        [keys addObject:str];
        [str release];
        
        r = sqlite3_step(statement);
    }
    
    sqlite3_reset(statement);
    
    if (r != SQLITE_DONE) {
        //NSLog(@"get keys failed");
    }
    
    return keys;
}

- (void) removeAllObjects
{
    [self privateExecute:@"DELETE FROM kvstore"];
}

- (void) beginTransaction
{
    [self privateExecute:@"BEGIN"];
}

- (void) endTransaction
{
    [self privateExecute:@"COMMIT"];
}

- (BOOL) privateExecute:(NSString *)sql
{
    int r;
    sqlite3_stmt * statement;
    
    r = sqlite3_prepare([self privateGetSQLite], [sql UTF8String], -1, &statement, 0);
    if (r != SQLITE_OK) {
        //NSLog(@"could not prepare %s", sql);
        sqlite3_finalize(statement);
        goto err;
    }
    
    r = sqlite3_step(statement);
    sqlite3_finalize(statement);
    if (r != SQLITE_DONE) {
        //NSLog(@"could not run %s", sql);
        goto err;
    }
    
    return YES;
    
err:
    return NO;
}

@end
