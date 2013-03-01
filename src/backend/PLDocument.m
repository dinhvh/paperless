//
//  PLDocument.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 16/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLDocument.h"

#import "PLLibrary.h"
#import "NSString+UUID.h"
#import "PLSQLDB.h"
#import "NSFileManager+MetaData.h"
#import "NSString+Date.h"

@interface PLDocument (Private)

- (void) _changeDate;

@end


@implementation PLDocument

@synthesize uid = _uid;
@synthesize timestamp = _timestamp;
@synthesize library = _library;
@synthesize inDatabase = _inDatabase;
@synthesize name = _name;
@synthesize importInProgress = _importInProgress;

- (id) initWithLibrary:(PLLibrary *)library
{
    NSString * uid;
    
    self = [super init];
    
    _library = library;
    uid = [NSString stringWithNewUUID];
    [self setUid:uid];
    _timestamp = [NSDate timeIntervalSinceReferenceDate];
    _inDatabase = NO;
    
	[self addObserver:self forKeyPath:@"inDatabase" options:0 context:NULL];
	[self addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionOld context:NULL];
	[self addObserver:self forKeyPath:@"timestamp" options:0 context:NULL];
    
    return self;
}

- (void) dealloc
{
	[self removeObserver:self forKeyPath:@"timestamp"];
	[self removeObserver:self forKeyPath:@"name"];
	[self removeObserver:self forKeyPath:@"inDatabase"];
    [_uid release];
    [super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ((object == self) && ([keyPath isEqualToString:@"inDatabase"])) {
        //NSLog(@"set in database %u", [self inDatabase]);
        if (![_library loading]) {
            NSString * comment;
            NSNumber * nbTimestamp;
            
            comment = [self comment];
            [self setComment:comment];
            
            if ([self inDatabase]) {
                [[NSFileManager defaultManager] setMetaData:[self name] forKey:PLMDNAMEKEY forFilename:[self filename]];
                [[_library db] setObject:[self name] forKey:[self uid] column:@"name"];
                
                nbTimestamp = [[NSNumber alloc] initWithUnsignedLongLong:[self timestamp]];
                [[_library db] setObject:nbTimestamp forKey:[self uid] column:@"timestamp"];
                [nbTimestamp release];
            }
        }
    }
    else if ((object == self) && ([keyPath isEqualToString:@"timestamp"])) {
        if ([self inDatabase]) {
            if (![_library loading]) {
                NSNumber * nbTimestamp;
                
                //NSLog(@"timestamp");
                nbTimestamp = [[NSNumber alloc] initWithUnsignedLongLong:[self timestamp]];
                [[_library db] setObject:nbTimestamp forKey:[self uid] column:@"timestamp"];
                [nbTimestamp release];
                [_library modifyDocument:self];
            }
        }
    }
    else if ((object == self) && ([keyPath isEqualToString:@"name"])) {
        if ([self inDatabase]) {
            if (![_library loading]) {
                NSString * oldName;
                
                //NSLog(@"name");
                oldName = [change objectForKey:NSKeyValueChangeOldKey];
                //NSLog(@"old value %@", oldName);
                [[_library db] setObject:[self name] forKey:[self uid] column:@"name"];
                [_library modifyDocument:self oldName:oldName];
                [[NSFileManager defaultManager] setMetaData:[self name] forKey:PLMDNAMEKEY forFilename:[self filename]];
                [self _changeDate];
            }
        }
    }
}

- (NSString *) comment
{
    NSString * comment;
    
    if (_comment != nil) {
        comment = _comment;
    }
    else {
        comment = [[_library db] objectForKey:[self uid] column:@"comment"];
    }
    
    if (comment == nil)
        comment = @"";
    
    return comment;
}

- (void) setComment:(NSString *)comment
{
    if ([self inDatabase]) {
        [[_library db] setObject:comment forKey:[self uid] column:@"comment"];
        [_library modifyDocument:self];
        [[NSFileManager defaultManager] setMetaData:comment forKey:PLMDCOMMENTKEY forFilename:[self filename]];
    }
    else {
        if (comment != _comment) {
            [_comment release];
            _comment = [comment copy];
        }
    }
}

- (NSComparisonResult) compareDate:(PLDocument *)doc
{
    if ([self timestamp] == [doc timestamp]) {
        return [[self name] compare:[doc name]];
    }
    else if ([self timestamp] < [doc timestamp]) {
        return NSOrderedDescending;
    }
    else {
        return NSOrderedAscending;
    }
}

- (NSString *) indexString
{
    if ([self comment] == nil)
        return _name;
    
    return [NSString stringWithFormat:@"%@ %@", _name, [self comment]];
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<PLDocument: %p (%@)>", self, [self name]];
}

- (NSUInteger) hash
{
    return [_uid hash];
}

- (NSString *) filename
{
    return [[[[self library] contentsPath] stringByAppendingPathComponent:[self uid]] stringByAppendingPathExtension:@"pdf"];
}

- (void) importMetaData
{
    NSString * comment;
    NSString * name;
    BOOL nameSet;
    
    nameSet = NO;
    comment = [[NSFileManager defaultManager] metaDataForKey:PLMDCOMMENTKEY forFilename:[self filename]];
    if (comment != nil) {
        [self setComment:comment];
    }
    name = [[NSFileManager defaultManager] metaDataForKey:PLMDNAMEKEY forFilename:[self filename]];
    if (name != nil) {
        nameSet = YES;
        [self setName:name];
    }
    else {
        [[NSFileManager defaultManager] setMetaData:[self name] forKey:PLMDNAMEKEY forFilename:[self filename]];
    }
    
    if (!nameSet) {
        [self _changeDate];
    }
}

- (void) _changeDate
{
    NSDate * date;
    NSCalendarDate * fileDate;
    NSCalendarDate * nameDate;
    NSCalendarDate * resultDate;
    NSDictionary * fileAttributes;
    time_t resultTimestamp;
    
    fileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:[self filename] traverseLink:YES];
    if (fileAttributes == nil) {
        fileDate = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:[self timestamp]];
    }
    else {
        date = [fileAttributes objectForKey:NSFileModificationDate];
        fileDate = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:[date timeIntervalSinceReferenceDate]];
    }
    nameDate = [[self name] PLDate];
    if (nameDate != nil) {
        resultDate = [NSCalendarDate dateWithYear:[nameDate yearOfCommonEra] month:[nameDate monthOfYear] day:[nameDate dayOfMonth] hour:[fileDate hourOfDay] minute:[fileDate minuteOfHour] second:[fileDate secondOfMinute] timeZone:nil];
    }
    else {
        resultDate = fileDate;
    }
    
    resultTimestamp = [resultDate timeIntervalSinceReferenceDate];
    if ([self timestamp] != resultTimestamp)
        [self setTimestamp:resultTimestamp];
}

@end
