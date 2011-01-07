//
//  ServerFromPrefs.h
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
#import "PersistentServer.h"
#import "IServerData.h"
@class ServerDataManager;

/* A server which is or can be stored in our preferences */
@interface ServerFromPrefs : PersistentServer {
}

+ (id<IServerData>)createWithName:(NSString*)name;
+ (id<IServerData>)createWithHost:(NSString*)hostName preferenceDictionary:(NSDictionary*)prefDict;

- (id)initWithHost:(NSString*)host preferenceDictionary:(NSDictionary*)prefDict;

/* @name Archiving and Unarchiving
 * Implements the NSCoding protocol for serialization
 */
//@{
- (void)encodeWithCoder:(NSCoder*)coder;
- (id)initWithCoder:(NSCoder*)coder;
//@}

/** @name IServerData
 *  Implements elements of the IServerData protocol
 */
//@{
- (bool)doYouSupport: (SUPPORT_TYPE)type;
//@}

@end
