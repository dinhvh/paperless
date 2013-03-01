//
//  PLIndex.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 16/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLIndex.h"

@interface PLIndex (Private)

- (NSArray *) _searchWithQuery:(NSString *)query;

@end

@implementation PLIndex

- (id) initWithFilename:(NSString *)filename
{
    self = [super init];
    
    _filename = [filename copy];
    
    return self;
}

 
- (void) dealloc
{
    [_filename release];
    [super dealloc];
}

- (BOOL) open
{
    NSURL * url;
    
    url = [NSURL fileURLWithPath:_filename];
    
    _index = SKIndexOpenWithURL((CFURLRef) url, NULL, true);
    if (_index == NULL) {
        _index = SKIndexCreateWithURL((CFURLRef) url, NULL, kSKIndexInverted, NULL);
        if (_index == NULL)
            return NO;
    }
    
    return YES;
}

- (void) close
{
    SKIndexFlush(_index);
    SKIndexClose(_index);
    _index = NULL;
}

- (void) save
{
    SKIndexFlush(_index);
}

- (BOOL) setString:(NSString *)str forKey:(NSString *)key
{
    SKDocumentRef doc;
    Boolean result;
    NSURL * url;
    
    url = [NSURL URLWithString:[NSString stringWithFormat:@"file:///%@", key]];
    doc = SKDocumentCreateWithURL((CFURLRef) url);
    if (doc == NULL) {
        //NSLog(@"could not create doc");
        return NO;
    }
    
    result = SKIndexAddDocumentWithText(_index, doc, (CFStringRef) str, true);
    
    CFRelease(doc);
    
    return result;
}

- (void) removeKey:(NSString *)key
{
    SKDocumentRef doc;
    NSURL * url;

    url = [NSURL URLWithString:[NSString stringWithFormat:@"file:///%@", key]];
    doc = SKDocumentCreateWithURL((CFURLRef) url);
    if (doc == NULL) {
        //NSLog(@"could not remove doc");
        return;
    }
    
    SKIndexRemoveDocument(_index, doc);
    
    CFRelease(doc);
}

#define SEARCHMAX 512

- (NSArray *) _searchWithQuery:(NSString *)query
{
    Boolean more;
    SKSearchRef search;
    NSMutableArray * result;
    unsigned int i;
    
    result = [[NSMutableArray alloc] init];
    SKIndexFlush(_index);
    search = SKSearchCreate(_index, (CFStringRef) query, kSKSearchOptionNoRelevanceScores);
	
    more = true;
    
    while (more) {
        SKDocumentID foundDocIDs[SEARCHMAX];
        SKDocumentRef foundDocRefs[SEARCHMAX];
        CFIndex foundCount;
        
        more = SKSearchFindMatches(search, SEARCHMAX, foundDocIDs, NULL, 1, &foundCount);
        
        SKIndexCopyDocumentRefsForDocumentIDs((SKIndexRef) _index, foundCount, foundDocIDs, foundDocRefs);
        for(i = 0 ; i < (unsigned int) foundCount ; i ++) {
            SKDocumentRef doc;
            NSURL * url;
            
            doc = foundDocRefs[i];
            url = (NSURL *) SKDocumentCopyURL(doc);
            [result addObject:[[url path] lastPathComponent]];
            [url release];
        }
        
        for(i = 0 ; i < (unsigned int) foundCount ; i ++) {
            SKDocumentRef doc;
            
            doc = foundDocRefs[i];
            CFRelease(doc);
        }
    }
    
    CFRelease(search);
    
    return [result autorelease];
}

- (NSArray *) search:(NSString *)searchStr
{
    NSMutableString * query;
    NSArray * termList;
    unsigned int i;
    
    query = [NSMutableString string];
    
    termList = [searchStr componentsSeparatedByString:@" "];
    for(i = 0 ; i < [termList count] ; i ++) {
        NSString * term;
        
        term = [termList objectAtIndex:i];
        [query appendString:@"*"];
        [query appendString:term];
        [query appendString:@"*"];
        
        if (i != [termList count] - 1) {
            [query appendString:@" "];
        }
    }
    
    return [self _searchWithQuery:query];
}

- (NSArray *) searchBeginsWith:(NSString *)searchStr
{
    NSMutableString * query;
    
    query = [NSMutableString string];
    [query appendString:searchStr];
    [query appendString:@"*"];
    
    //NSLog(@"search with query: %@", query);
    return [self _searchWithQuery:query];
}

@end
