//
//  ProfileManager_private.h
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/19/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "ProfileManager.h"


@interface ProfileManager (Private)

+ (int)_indexForEncodingType: (CARD32)type;
+ (NSNumber *)_tagForModifierIndex: (int)index;

- (NSMutableDictionary *)_currentProfileDictionary;
- (NSString *)_currentProfileName;
- (void)_selectProfileAtIndex: (int)index;
- (void)_selectProfileNamed:(NSString*)aProfile;
- (NSArray*)_sortedProfileNames;
- (void)_updateBrowserButtons;
- (void)_updateForm;

@end
