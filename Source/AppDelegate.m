//
//  AppDelegate.m
//  Chicken of the VNC
//
//  Created by Bob Newhart on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "AppDelegate.h"
#import "PrefController.h"
#import "RFBConnectionManager.h"
//#import "ServerDataManager.h"


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	RFBConnectionManager *cm = [RFBConnectionManager sharedManager];
	[cm wakeup];
	if ( ! [cm runFromCommandLine] )
		[cm runNormally];
	
	[mRendezvousMenuItem setState: [[PrefController sharedController] usesRendezvous] ? NSOnState : NSOffState];
	[mInfoVersionNumber setStringValue: [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]];
}


- (IBAction)showPreferences: (id)sender
{
	[[PrefController sharedController] showWindow];
}


- (IBAction)changeRendezvousUse:(id)sender
{
	PrefController *prefs = [PrefController sharedController];
	[prefs toggleUseRendezvous: sender];
	
	[mRendezvousMenuItem setState: [prefs usesRendezvous] ? NSOnState : NSOffState];
}


- (IBAction)showConnectionDialog: (id)sender
{  [[RFBConnectionManager sharedManager] showConnectionDialog: nil];  }


- (IBAction)showProfileManager: (id)sender
{  [[ProfileManager sharedManager] showWindow: nil];  }

@end
