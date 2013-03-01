//
//  PLLibrary.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 16/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLLibrary.h"

#import "PLDocument.h"
#import "PLSQLDB.h"
#import "PLIndex.h"
#import "PLCompletion.h"
#import "NSString+Date.h"

@interface PLLibrary (Private)

- (void) privateAsyncLoad;
- (void) privateLoadDone;
- (void) privateSearchDone;

- (void) _collectUntitled;
- (void) _collectUntitledDoc:(PLDocument *)doc;
- (void) _uncollectUntitledDoc:(NSString *)uid;

@end

@interface PLLibrarySearchOperation : NSOperation {
    PLLibrary * _library;
    NSArray * _result;
    NSString * _searchString;
    BOOL _begins;
}

@property (readonly) NSArray * result;

- (id) initWithLibrary:(PLLibrary *)library searchString:(NSString *)searchString;
- (id) initWithLibrary:(PLLibrary *)library searchString:(NSString *)searchString begins:(BOOL)begins;
- (void) dealloc;

- (void) main;

@end

@implementation PLLibrarySearchOperation

@synthesize result = _result;

- (id) initWithLibrary:(PLLibrary *)library searchString:(NSString *)searchString
{
    self = [self initWithLibrary:library searchString:searchString begins:NO];
    
    return self;
}

- (id) initWithLibrary:(PLLibrary *)library searchString:(NSString *)searchString begins:(BOOL)begins
{
    self = [super init];
    
    _library = [library retain];
    _searchString = [searchString copy];
    _begins = begins;
    
    return self;
}

- (void) dealloc
{
    [_searchString release];
    [_library release];
    [super dealloc];
}

- (void) main
{
    if (_begins) {
        _result = [[_library index] searchBeginsWith:_searchString];
    }
    else {
        _result = [[_library index] search:_searchString];
    }
}

@end

@interface PLLibraryLoadOperation : NSOperation {
    NSMutableDictionary * _documentDict;
    PLLibrary * _library;
    PLCompletion * _completion;
}

@property (readonly) NSDictionary * documentDict;
@property (readonly) PLCompletion * completion;

- (id) initWithLibrary:(PLLibrary *)library;
- (void) dealloc;

- (void) main;

@end

@implementation PLLibraryLoadOperation

@synthesize documentDict = _documentDict;
@synthesize completion = _completion;

- (id) initWithLibrary:(PLLibrary *)library
{
    self = [super init];
    
    _library = [library retain];
    _documentDict = [[NSMutableDictionary alloc] init];
    _completion = [[PLCompletion alloc] init];
    
    return self;
}

- (void) dealloc
{
    [_completion release];
    [_documentDict release];
    [_library release];
    [super dealloc];
}

- (void) main
{
    PLSQLDB * db;
    unsigned int i;
    NSArray * allKeys;
    
    [self retain];
    db = [_library db];
    
    allKeys = [db allKeys];
    //NSLog(@"load %i documents", [allKeys count]);
    for(i = 0 ; i < [allKeys count] ; i ++) {
        NSString * key;        
        PLDocument * doc;
        NSNumber * nbTimestamp;
        time_t timestamp;
        NSString * name;
        
        if ([self isCancelled])
            break;
        
        key = [allKeys objectAtIndex:i];
        doc = [[PLDocument alloc] initWithLibrary:_library];
        [doc setUid:key];
        nbTimestamp = [db objectForKey:key column:@"timestamp"];
        //NSLog(@"timestamp : %p", nbTimestamp);
        timestamp = [nbTimestamp unsignedLongLongValue];
        //NSLog(@"timestamp : %u", timestamp);
        name = [db objectForKey:key column:@"name"];
        [doc setName:name];
        [doc setTimestamp:timestamp];
        [doc setInDatabase:YES];
        
        [_documentDict setObject:doc forKey:key];
        
        [_completion addDocumentWithName:[name stringByRemovingPLDate]];
        
        [doc release];
    }
    
    [self release];
    //NSLog(@"load done");
}

@end

@implementation PLLibrary

@synthesize cancelled = _cancelled;
@synthesize loaded = _loaded;
@synthesize db = _db;
@synthesize index = _index;
@synthesize documentDict = _documentDict;

- (id) init
{
    NSString * filename;
    NSMutableArray * columns;
    NSString * folder;
    
    self = [super init];
    
    _loaded = NO;
    
    folder = [@"~/Library/Application Support/PaperLess" stringByExpandingTildeInPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    folder = [@"~/Library/Application Support/PaperLess/Contents" stringByExpandingTildeInPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    folder = [@"~/Library/Application Support/PaperLess/Trash" stringByExpandingTildeInPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    folder = [@"~/Library/Application Support/PaperLess/Drag" stringByExpandingTildeInPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    
    columns = [[NSMutableArray alloc] init];
    [columns addObject:@"timestamp"];
    [columns addObject:@"comment"];
    [columns addObject:@"name"];
    filename = [@"~/Library/Application Support/PaperLess/documents.db" stringByExpandingTildeInPath];
    _db = [[PLSQLDB alloc] initWithFilename:filename columns:columns];
    [_db open];
    [columns release];
    
    filename = [@"~/Library/Application Support/PaperLess/documents.index" stringByExpandingTildeInPath];
    _index = [[PLIndex alloc] initWithFilename:filename];
    [_index open];
    
    _untitledDict = [[NSMutableDictionary alloc] init];
    
    [self privateAsyncLoad];
    
    return self;
}

- (void) dealloc
{
    //NSLog(@"library dealloc");
    [_untitledDict release];
    [_completion release];
    [_documentDict release];
    [_index close];
    [_index release];
    [_db close];
    [_db release];
    
    [super dealloc];
}

- (NSString *) contentsPath
{
    return [@"~/Library/Application Support/PaperLess/Contents" stringByExpandingTildeInPath];
}

- (void) save
{
    [_index save];
}

- (void) cancelLoad
{
    [self willChangeValueForKey:@"cancelled"];
    _cancelled = YES;
    [self didChangeValueForKey:@"cancelled"];
    [_loadOp cancel];
}

- (void) privateAsyncLoad
{
    //NSLog(@"async load");
    _libraryLoading = YES;
    _loadOp = [[PLLibraryLoadOperation alloc] initWithLibrary:self];
    
	[_loadOp addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
    [_loadOp start];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    //NSLog(@"observe value %@", keyPath);
    if ([keyPath isEqualToString:@"isFinished"] && (object == _loadOp)) {
        [_loadOp removeObserver:self forKeyPath:@"isFinished"];
        if ([_loadOp isFinished])
            [self privateLoadDone];
    }
    else if ([keyPath isEqualToString:@"isFinished"] && (object == _searchOp)) {
        [_searchOp removeObserver:self forKeyPath:@"isFinished"];
        if ([_searchOp isFinished])
            [self privateSearchDone];
    }
}

- (void) privateLoadDone
{
    _documentDict = [[_loadOp documentDict] mutableCopy];
    _completion = [[_loadOp completion] retain];
    [_loadOp release];
    _loadOp = nil;
    [self willChangeValueForKey:@"loaded"];
    _loaded = YES;
    _libraryLoading = NO;
    [self didChangeValueForKey:@"loaded"];
    //NSLog(@"loaded");
    
    [self _collectUntitled];
}

- (void) _collectUntitled
{
    NSArray * keys;
    unsigned int i;
    
    keys = [_documentDict allKeys];
    
    for(i = 0 ; i < [keys count] ; i ++) {
        NSString * key;
        PLDocument * doc;
        
        key = [keys objectAtIndex:i];
        doc = [_documentDict objectForKey:key];
        if ([[doc name] hasPrefix:@"untitled"]) {
            [_untitledDict setObject:doc forKey:[doc uid]];
            //NSLog(@"collect untitled %@", [doc name]);
        }
    }
}

- (void) _collectUntitledDoc:(PLDocument *)doc
{
    if ([[doc name] hasPrefix:@"untitled"]) {
        [_untitledDict setObject:doc forKey:[doc uid]];
    }
}

- (void) _uncollectUntitledDoc:(NSString *)uid
{
    [_untitledDict removeObjectForKey:uid];
}

- (NSString *) getUntitledName
{
    unsigned int i;
    NSArray * keys;
    int untitledMaxCount;
    
    untitledMaxCount = -1;
    keys = [_untitledDict allKeys];
    for(i = 0 ; i < [keys count] ; i ++) {
        NSString * key;
        PLDocument * doc;
        NSString * strValue;
        int value;
        
        key = [keys objectAtIndex:i];
        doc = [_untitledDict objectForKey:key];
        if ([[doc name] isEqualToString:@"untitled"]) {
            if (untitledMaxCount < 0)
                untitledMaxCount = 0;
        }
        else if ([[doc name] hasPrefix:@"untitled "]) {
            strValue = [[[doc name] stringByRemovingPLDate] substringFromIndex:[@"untitled" length] + 1];
            //NSLog(@"%@ %@", [doc name], strValue);
            value = [strValue intValue];
            if (value > untitledMaxCount) {
                untitledMaxCount = value;
            }
        }
    }
    
    if (untitledMaxCount == -1) {
        return @"untitled";
    }
    else {
        return [NSString stringWithFormat:@"untitled %i", untitledMaxCount + 1];
    }
}

- (PLSQLDB *) db
{
    return _db;
}
- (NSDictionary * ) documentDict
{
    return _documentDict;
}

- (void) search:(NSString *)searchString delegate:(id <PLLibrarySearchDelegate>)delegate
{
    _delegate = delegate;
    _searchOp = [[PLLibrarySearchOperation alloc] initWithLibrary:self searchString:searchString];
    
	[_searchOp addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
    [_searchOp start];
}

- (void) privateSearchDone
{
    NSMutableArray * docList;
    NSArray * result;
    unsigned int i;
    
    docList = [[NSMutableArray alloc] init];
    
    result = [_searchOp result];
    for(i = 0 ; i < [result count] ; i ++) {
        NSString * uid;
        PLDocument * doc;
        
        uid = [result objectAtIndex:i];
        doc = [_documentDict objectForKey:uid];
        if (doc == nil)
            continue;
        
        [docList addObject:doc];
    }
    
    [_delegate plLibrary_searchDone:docList];
    
    [docList release];
    
    [_searchOp release];
    _searchOp = nil;
}

- (NSArray *) allKeys
{
    return [_documentDict allKeys];
}

- (PLDocument *) documentForKey:(NSString *)key
{
    return [_documentDict objectForKey:key];
}

- (void) addDocument:(PLDocument *)document
{
    [_documentDict setObject:document forKey:[document uid]];
    [_completion addDocumentWithName:[[document name] stringByRemovingPLDate]];
    [document setInDatabase:YES];
    
    if (!_libraryLoading) {
        [_index setString:[document indexString] forKey:[document uid]];
        [self _collectUntitledDoc:document];
    }
}

- (void) modifyDocument:(PLDocument *)document
{
    [self modifyDocument:document oldName:nil];
}

- (void) modifyDocument:(PLDocument *)document oldName:(NSString *)oldName
{
    if (!_libraryLoading) {
        if (oldName != nil) {
            [_completion removeDocumentWithName:[oldName stringByRemovingPLDate]];
            [_completion addDocumentWithName:[[document name] stringByRemovingPLDate]];
        }
        
        [_index removeKey:[document uid]];
        [_index setString:[document indexString] forKey:[document uid]];
        [self _collectUntitledDoc:document];
    }
}

- (void) removeDocumentForKey:(NSString *)key
{
    PLDocument * document;
    
    if (!_libraryLoading) {
        [self _uncollectUntitledDoc:key];
        [_index removeKey:key];
    }
    
    document = [_documentDict objectForKey:key];
    [_completion addDocumentWithName:[[document name] stringByRemovingPLDate]];
    [document setInDatabase:NO];
    [_documentDict removeObjectForKey:key];
    [_db removeObjectForKey:key];
}

- (void) beginTransaction
{
    [_db beginTransaction];
}
 
- (void) endTransaction
{
    [_db endTransaction];
}

- (BOOL) loading
{
    return _libraryLoading;
}

- (void) searchBeginsWith:(NSString *)searchString delegate:(id <PLLibrarySearchDelegate>)delegate
{
    _delegate = delegate;
    _searchOp = [[PLLibrarySearchOperation alloc] initWithLibrary:self searchString:searchString begins:YES];
    
	[_searchOp addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
    [_searchOp start];
}

- (NSArray *) nameStartWith:(NSString *)name
{
    return [_completion nameStartWith:name];
}

- (NSString *) probableNameStartWith:(NSString *)name
{
    return [_completion probableNameStartWith:name];
}

@end
