/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import <AppKit/AppKit.h>
#import "rfbproto.h"
#import "Profile.h"
@class ProfileManager;
@protocol IServerData;

/* Constants, generally used for userdefaults */
#define RFB_COLOR_MODEL		@"RFBColorModel"
#define RFB_GAMMA_CORRECTION	@"RFBGammaCorrection"
#define RFB_LAST_HOST		@"RFBLastHost"

#define RFB_HOST_INFO		@"HostPreferences"
#define RFB_LAST_DISPLAY	@"Display"
#define RFB_LAST_PROFILE	@"Profile"

#define KEYCHAIN_SERVICE_NAME	@"cotvnc" // This should really be the appname, but I'm too lame to know how to find that - kjw

@interface RFBConnectionManager : NSObject
{
    IBOutlet NSTextField *display;
    IBOutlet NSTextField *hostName;
    IBOutlet NSSecureTextField *passWord;
    IBOutlet NSButton *shared;
    IBOutlet NSPanel *loginPanel;
    IBOutlet NSMatrix *colorModelMatrix;
    IBOutlet NSTextField *psThreshold;
    IBOutlet NSTextField *psMaxRects;
    IBOutlet NSTextField *gamma;
    IBOutlet NSPopUpButton *profilePopup;
    IBOutlet ProfileManager *profileManager;
    IBOutlet NSButton *rememberPwd;
	IBOutlet NSSlider *autoscrollIncrement;
	IBOutlet NSButton *fullscreenScrollbars;
	IBOutlet NSButton *displayFullscreenWarning;
	IBOutlet NSSlider *frontInverseCPUSlider;
	IBOutlet NSSlider *otherInverseCPUSlider;
	IBOutlet NSTableView *serverList;
    NSMutableArray*	connections;
    NSString *cmdlineHost;
    NSString *cmdlineDisplay;
    NSString *cmdlinePassword;
    NSString *cmdlineFullscreen;
}

+ (float)gammaCorrection;
+ (void)getLocalPixelFormat:(rfbPixelFormat*)pf;

- (void)updateProfileList:(id)notification;
- (void)removeConnection:(id)aConnection;
- (IBAction)connect:(id)sender;
- (void)processArguments;
- (void)cmdlineUsage;

- (void)selectedHostChanged;

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost;
- (void)setDisplayNameTranslation:(NSString*)translation forName:(NSString*)aName forHost:(NSString*)aHost;

- (BOOL)createConnectionWithServer:(id<IServerData>) server profile:(Profile *) someProfile owner:(id) someOwner;

- (IBAction)preferencesChanged:(id)sender;
- (IBAction)hostChanged:(id)sender;
- (IBAction)passwordChanged:(id)sender;
- (IBAction)rememberPwdChanged:(id)sender;
- (IBAction)displayChanged:(id)sender;
- (IBAction)profileSelectionChanged:(id)sender;
- (IBAction)sharedChanged:(id)sender;

- (IBAction)addServer:(id)sender;
- (IBAction)deleteSelectedServer:(id)sender;

- (id)defaultFrameBufferClass;

//- (void)controlTextDidChange:(NSNotification *)aNotification; no needed?

- (void)makeAllConnectionsWindowed;

- (BOOL)haveMultipleConnections; // True if there is more than one connection open.
- (BOOL)haveAnyConnections;      // True if there are any connections open.

- (IBAction)frontInverseCPUSliderChanged: (NSSlider *)sender;
- (IBAction)otherInverseCPUSliderChanged: (NSSlider *)sender;
- (float)maxPossibleFrameBufferUpdateSeconds;

- (void)controlTextDidEndEditing:(NSNotification*)notification;
- (void)serverListDidChange:(NSNotification*)notification;

- (id<IServerData>)getSelectedServer;

@end
