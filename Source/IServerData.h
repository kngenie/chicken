//
//  IServerData.h
//  Chicken of the VNC
//
//  Created by Jared McIntyre on Sat Jan 24 2004.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import <Foundation/Foundation.h>

/** Implementers of IServerData will send this notification when a property has changed */
#define ServerChangeMsg @"ServerChangeMsg"

typedef enum
{
	EDIT_ADDRESS,
	EDIT_PORT,
	EDIT_NAME,
	SAVE_PASSWORD,
	CONNECT,
	DELETE
} SUPPORT_TYPE;

@protocol IServerDataDelegate;

@protocol IServerData

- (bool)doYouSupport: (SUPPORT_TYPE)type;

- (NSString*)name;
- (NSString*)host;
- (NSString*)password;
- (bool)rememberPassword;
- (int)display;
- (bool)shared;
- (bool)fullscreen;
- (NSString*)lastProfile;

- (void)setName: (NSString*)name;
- (void)setHost: (NSString*)host;
- (void)setPassword: (NSString*)password;
- (void)setRememberPassword: (bool)rememberPassword;
- (void)setDisplay: (int)display;
- (void)setShared: (bool)shared;
- (void)setFullscreen: (bool)fullscreen;
- (void)setLastProfile: (NSString*)lastProfile;

- (void)setDelegate: (id<IServerDataDelegate>)delegate;

@end


@protocol IServerDataDelegate

- (void)validateNameChange:(NSString *)name forServer:(id<IServerData>)server;

@end