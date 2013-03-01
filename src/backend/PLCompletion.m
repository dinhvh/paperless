//
//  PLCompletion.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 22/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLCompletion.h"

#import "PLCompletionTree.h"

@implementation PLCompletion

- (id) init
{
    self = [super init];
    
    _root = [[PLCompletionTree alloc] init];
    
    return self;
}

- (void) dealloc
{
    [_root release];
    [super dealloc];
}

- (void) addDocumentWithName:(NSString *)name
{
    [_root addDocumentWithName:[name lowercaseString]];
}

- (void) removeDocumentWithName:(NSString *)name
{
    [_root removeDocumentWithName:[name lowercaseString]];
}

- (NSArray *) nameStartWith:(NSString *)name
{
    PLCompletionTree * node;
    NSArray * result;
    
    node = [_root nodeStartWith:[name lowercaseString]];
    result = [node documentNameArrayWithPrefix:name];
    return result;
}

- (NSString *) probableNameStartWith:(NSString *)name
{
    PLCompletionTree * node;
    NSMutableString * str;
    
    node = [_root nodeStartWith:[name lowercaseString]];
    str = [NSMutableString string];
    [str appendString:name];
    [node updateTotalCount];
    [node probableNodeWithString:str];
    
    return str;
}

@end
