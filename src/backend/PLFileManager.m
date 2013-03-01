//
//  PLDocumentCopyScheduler.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 30/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLFileManager.h"

#import "PLDocument.h"
#import "PLLibrary.h"

@interface PLFileManager (Private)

- (void) _removePendingDoc:(PLDocument *)doc;
- (void) _startOperationList;
- (void) _finishOperationList;
- (void) _setProgressInfo;
- (void) _notifyDoc:(PLDocument *)doc;

@end


@interface PLDocumentItemExportOperation : NSOperation {
    PLDocument * _doc;
    NSString * _destination;
    PLFileManager * _queue;
}

- (id) initWithDocument:(PLDocument *)doc destination:(NSString *)destination queue:(PLFileManager *)queue;
- (void) dealloc;

- (void) main;
- (void) mainThread;

@end

@implementation PLDocumentItemExportOperation

- (id) initWithDocument:(PLDocument *)doc destination:(NSString *)destination queue:(PLFileManager *)queue;
{
    self = [super init];
    
    _doc = [doc retain];
    _destination = [destination copy];
    _queue = queue;
    
    return self;
}

- (void) dealloc
{
    [_destination release];
    [_doc release];
    [super dealloc];
}

- (NSString *) description
{
    return @"Exporting documents...";
}

- (void) main
{
    [[NSFileManager defaultManager] copyPath:[_doc filename] toPath:_destination handler:nil];
    [self performSelectorOnMainThread:@selector(mainThread) withObject:nil waitUntilDone:YES];
}

- (void) mainThread
{
    //NSLog(@"copy done for %@", _doc);
    [_queue _removePendingDoc:_doc];
    [_queue _finishOperationList];
}

@end

@interface PLDocumentItemCopyOperation : NSOperation {
    PLDocument * _doc;
    NSString * _filename;
    NSString * _destination;
    PLFileManager * _queue;
}

- (id) initWithFile:(NSString *)filename document:(PLDocument *)doc queue:(PLFileManager *)queue;
- (void) dealloc;

- (void) main;
- (void) mainThread;

@end

@implementation PLDocumentItemCopyOperation

- (id) initWithFile:(NSString *)filename document:(PLDocument *)doc queue:(PLFileManager *)queue
{
    self = [super init];
    
    _filename = [filename copy];
    _doc = [doc retain];
    _destination = [doc filename];
    [_destination retain];
    _queue = queue;
    [_doc setImportInProgress:YES];
    
    return self;
}

- (void) dealloc
{
    [_destination release];
    [_doc release];
    [_filename release];
    [super dealloc];
}

- (NSString *) description
{
    return @"Importing documents...";
}

- (void) main
{
    [[NSFileManager defaultManager] copyPath:_filename toPath:_destination handler:nil];
    [self performSelectorOnMainThread:@selector(mainThread) withObject:nil waitUntilDone:YES];
}

- (void) mainThread
{
    [_doc setImportInProgress:NO];
    [_queue _notifyDoc:_doc];
    [_queue _removePendingDoc:_doc];
    [_queue _finishOperationList];
}

@end

@interface PLDocumentItemDeleteOperation : NSOperation {
    PLDocument * _doc;
    NSString * _filename;
    PLFileManager * _queue;
}

- (id) initWithDocument:(PLDocument *)doc queue:(PLFileManager *)queue;
- (void) dealloc;

- (void) main;
- (void) mainThread;

@end

@implementation PLDocumentItemDeleteOperation

- (id) initWithDocument:(PLDocument *)doc queue:(PLFileManager *)queue
{
    self = [super init];
    
    _doc = [doc retain];
    _filename = [doc filename];
    [_filename retain];
    _queue = queue;
    
    return self;
}

- (void) dealloc
{
    [_doc release];
    [_filename release];
    [super dealloc];
}

- (NSString *) description
{
    return @"Deleting documents...";
}

- (void) main
{
    NSString * destFile;
    
    destFile = [[@"~/Library/Application Support/PaperLess/Trash" stringByExpandingTildeInPath] stringByAppendingPathComponent:[_filename lastPathComponent]];
    [[NSFileManager defaultManager] moveItemAtPath:_filename toPath:destFile error:NULL];
    [self performSelectorOnMainThread:@selector(mainThread) withObject:nil waitUntilDone:YES];
}

- (void) mainThread
{
    //NSLog(@"delete done for %@", _doc);
    [_queue _removePendingDoc:_doc];
    [_queue _finishOperationList];
}

@end

@interface PLDocumentItemUndeleteOperation : NSOperation {
    PLDocument * _doc;
    NSString * _filename;
    PLFileManager * _queue;
}

- (id) initWithDocument:(PLDocument *)doc queue:(PLFileManager *)queue;
- (void) dealloc;

- (void) main;
- (void) mainThread;

@end

@implementation PLDocumentItemUndeleteOperation

- (id) initWithDocument:(PLDocument *)doc queue:(PLFileManager *)queue
{
    self = [super init];
    
    _doc = [doc retain];
    _filename = [doc filename];
    [_filename retain];
    _queue = queue;
    
    return self;
}

- (void) dealloc
{
    [_doc release];
    [_filename release];
    [super dealloc];
}

- (NSString *) description
{
    return @"Undeleting documents...";
}

- (void) main
{
    NSString * sourceFile;
    
    sourceFile = [[@"~/Library/Application Support/PaperLess/Trash" stringByExpandingTildeInPath] stringByAppendingPathComponent:[_filename lastPathComponent]];
    [[NSFileManager defaultManager] moveItemAtPath:sourceFile toPath:_filename error:NULL];
    [self performSelectorOnMainThread:@selector(mainThread) withObject:nil waitUntilDone:YES];
}

- (void) mainThread
{
    //NSLog(@"delete done for %@", _doc);
    [_queue _removePendingDoc:_doc];
    [_queue _finishOperationList];
}

@end

@interface PLEmptyTrashOperation : NSOperation {
    PLFileManager * _queue;
}

- (id) initWithQueue:(PLFileManager *)queue;
- (void) dealloc;

- (void) main;
- (void) mainThread;

@end

@implementation PLEmptyTrashOperation

- (id) initWithQueue:(PLFileManager *)queue
{
    self = [super init];
    
    _queue = queue;
    
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

- (NSString *) description
{
    return @"Emptying Trash...";
}

- (void) main
{
    NSString * trashFolder;
    unsigned int i;
    NSArray * contents;
    
    trashFolder = [@"~/Library/Application Support/PaperLess/Trash" stringByExpandingTildeInPath];
    contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:trashFolder error:NULL];
    for(i = 0 ; i < [contents count] ; i ++) {
        NSString * filename;
        
        filename = [contents objectAtIndex:i];
        filename = [trashFolder stringByAppendingPathComponent:filename];
        //NSLog(@"remove %@", filename);
        [[NSFileManager defaultManager] removeItemAtPath:filename error:NULL];
    }
    [self performSelectorOnMainThread:@selector(mainThread) withObject:nil waitUntilDone:YES];
}

- (void) mainThread
{
    [_queue _finishOperationList];
}

@end

@interface PLEmptyDragFolderOperation : NSOperation {
    PLFileManager * _queue;
}

- (id) initWithQueue:(PLFileManager *)queue;
- (void) dealloc;

- (void) main;
- (void) mainThread;

@end

@implementation PLEmptyDragFolderOperation

- (id) initWithQueue:(PLFileManager *)queue
{
    self = [super init];
    
    _queue = queue;
    
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

- (NSString *) description
{
    return @"Cleanup...";
}

- (void) main
{
    NSString * trashFolder;
    unsigned int i;
    NSArray * contents;
    
    trashFolder = [@"~/Library/Application Support/PaperLess/Drag" stringByExpandingTildeInPath];
    contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:trashFolder error:NULL];
    for(i = 0 ; i < [contents count] ; i ++) {
        NSString * filename;
        
        filename = [contents objectAtIndex:i];
        filename = [trashFolder stringByAppendingPathComponent:filename];
        [[NSFileManager defaultManager] removeItemAtPath:filename error:NULL];
    }
    [self performSelectorOnMainThread:@selector(mainThread) withObject:nil waitUntilDone:YES];
}

- (void) mainThread
{
    [_queue _finishOperationList];
}

@end

@implementation PLFileManager

- (id) init
{
    self = [super init];
    
    _opQueue = [[NSOperationQueue alloc] init];
    [_opQueue setMaxConcurrentOperationCount:1];
    _pendingDoc = [[NSMutableSet alloc] init];
    
    return self;
}

- (void) dealloc
{
    [_opQueue release];
    [super dealloc];
}

static PLFileManager * singleton = nil;

+ (PLFileManager *) sharedManager
{
    @synchronized([PLFileManager class]) {
        if (singleton == nil)
            singleton = [[PLFileManager alloc] init];
    }
    return singleton;
}

- (void) _removePendingDoc:(PLDocument *)doc
{
    [_pendingDoc removeObject:doc];
}

- (void) _notifyDoc:(PLDocument *)doc
{
    NSMutableDictionary * userInfo;
    
    userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:doc forKey:@"doc"];
    [[NSNotificationCenter defaultCenter] postNotificationName:PLFILEMANAGER_FINISHED_NOTIFICATION object:self userInfo:userInfo];
}

- (NSSet *) pendingDoc
{
    return _pendingDoc;
}

- (void) queueFile:(NSString *)filename document:(PLDocument *)doc
{
    PLDocumentItemCopyOperation * op;
    
    [self _startOperationList];
    [_pendingDoc addObject:doc];
    
    op = [[PLDocumentItemCopyOperation alloc] initWithFile:filename document:doc queue:self];
    
    [_opQueue addOperation:op];
    [self _setProgressInfo];
    
    [op release];
}

- (void) queueUndeleteDocument:(PLDocument *)doc
{
    PLDocumentItemUndeleteOperation * op;
    
    [self _startOperationList];
    [_pendingDoc addObject:doc];
    
    op = [[PLDocumentItemUndeleteOperation alloc] initWithDocument:doc queue:self];
    
    [_opQueue addOperation:op];
    [self _setProgressInfo];
    
    [op release];
}

- (void) queueDeleteDocument:(PLDocument *)doc
{
    PLDocumentItemDeleteOperation * op;
    
    [self _startOperationList];
    [_pendingDoc addObject:doc];
    
    op = [[PLDocumentItemDeleteOperation alloc] initWithDocument:doc queue:self];
    
    [_opQueue addOperation:op];
    [self _setProgressInfo];
    
    [op release];
}

- (void) queueExportDocument:(PLDocument *)doc destination:(NSString *)destination
{
    PLDocumentItemExportOperation * op;
    
    [self _startOperationList];
    [_pendingDoc addObject:doc];
    
    op = [[PLDocumentItemExportOperation alloc] initWithDocument:doc destination:destination queue:self];
    
    [_opQueue addOperation:op];
    [self _setProgressInfo];
    
    [op release];
}

- (void) emptyTrash
{
    PLEmptyTrashOperation * op;
    
    [self _startOperationList];
    
    op = [[PLEmptyTrashOperation alloc] initWithQueue:self];
    
    [_opQueue addOperation:op];
    [self _setProgressInfo];
    
    [op release];
}

- (void) emptyDragFolder
{
    PLEmptyDragFolderOperation * op;
    
    [self _startOperationList];
    
    op = [[PLEmptyDragFolderOperation alloc] initWithQueue:self];
    
    [_opQueue addOperation:op];
    [self _setProgressInfo];
    
    [op release];
}

- (BOOL) isPendingDoc:(PLDocument *)doc
{
    return [_pendingDoc containsObject:doc];
}

- (void) _startOperationList
{
    if ([[_opQueue operations] count] == 0) {
        _progressMaxValue = 0;
        _progressValue = 0;
        [[NSNotificationCenter defaultCenter] postNotificationName:PLFILEMANAGER_PROGRESS_START_NOTIFICATION object:self userInfo:nil];
    }
}

- (void) _finishOperationList
{
    _progressValue ++;
    [[NSNotificationCenter defaultCenter] postNotificationName:PLFILEMANAGER_PROGRESS_UPDATE_NOTIFICATION object:self userInfo:nil];
    if ([[_opQueue operations] count] == 1) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PLFILEMANAGER_PROGRESS_END_NOTIFICATION object:self userInfo:nil];
        _progressMaxValue = 0;
        _progressValue = 0;
    }
}

- (void) _setProgressInfo
{
    _progressMaxValue ++;
}

- (unsigned int) progressMaxValue
{
    return _progressMaxValue;
}

- (unsigned int) progressValue
{
    return _progressValue;
}

- (NSString *) currentOperationDescription
{
    if ([[_opQueue operations] count] == 0)
        return @"";
    
    return [[[_opQueue operations] objectAtIndex:0] description];
}

- (BOOL) hasPendingOperations
{
    if ([[_opQueue operations] count] == 0)
        return NO;
    
    return YES;
}

- (void) cleanImport
{
    NSString * destFile;
    NSString * filename;
    
    filename = [@"~/Library/Application Support/PaperLess/Import" stringByExpandingTildeInPath];
    destFile = [[@"~/Library/Application Support/PaperLess/Trash" stringByExpandingTildeInPath] stringByAppendingPathComponent:[filename lastPathComponent]];
    [[NSFileManager defaultManager] moveItemAtPath:filename toPath:destFile error:NULL];
}

@end
