//
//  KeyEquivalentScenario.h
//  Chicken of the VNC
//
//  Created by Bob Newhart on Sun Mar 21 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
@class KeyEquivalent, KeyEquivalentEntry;


@interface KeyEquivalentScenario : NSObject {
	NSMutableDictionary *mEquivalentToEntryMapping; // KeyEquivalent => KeyEquivalentEntry
	BOOL mIsActive;
}

// Creation
- (id)initWithPropertyList: (NSArray *)array;

// Persistance
- (NSArray *)propertyList;

// Accessing Key Equivalents
- (KeyEquivalentEntry *)entryForKeyEquivalent: (KeyEquivalent *)equivalent;
- (NSMenuItem *)menuItemForKeyEquivalent: (KeyEquivalent *)equivalent;
- (void)setEntry: (KeyEquivalentEntry *)entry forEquivalent: (KeyEquivalent *)equivalent;
- (KeyEquivalent *)keyEquivalentForMenuItem: (NSMenuItem *)menuItem;
- (void)removeEntry: (KeyEquivalentEntry *)entry;

// Making Scenarios Active
- (void)makeActive: (BOOL)active;

@end
