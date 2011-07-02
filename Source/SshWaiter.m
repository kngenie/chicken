/* SshWaiter.m
 * Copyright (C) 2011 Dustin Cartwright
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

#import "SshWaiter.h"
#import "IServerData.h"
#import "RFBConnection.h"
#import "SshTunnel.h"

#import <sys/socket.h>
#import <unistd.h>

@implementation SshWaiter

- (id)initWithServer:(id<IServerData>)aServer
    delegate:(id<ConnectionWaiterDelegate>)aDelegate window:(NSWindow *)aWind
{
    if (self = [super init]) {
        server = [aServer retain];
        delegate = aDelegate;
        window = [aWind retain];

        tunnel = [[SshTunnel alloc] initWithServer:server delegate:self];
    }

    return self;
}

/* Starts a connection attempt, reusing an existing tunnel. */
- (id)initWithServer:(id<IServerData>)aServer
            delegate:(id<ConnectionWaiterDelegate>)aDelegate
              window:(NSWindow *)aWind sshTunnel:(SshTunnel *)aTunnel
{
    if (self = [super init]) {
        server = [aServer retain];
        delegate = aDelegate;
        window = [aWind retain];
        tunnel = [aTunnel retain];

        [self tunnelEstablishedAtPort:[tunnel localPort]];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [tunnel close];
    [tunnel release];
    [auth release];

    [super dealloc];
}

- (void)cancel
{
    [super cancel];
    [tunnel close];
}

- (void)firstTimeConnecting
{
    /* This is ssh's first time connecting to this server. We want to verify
     * that the user wants to add the unauthenticated server key to the hosts
     * file. */

    NSAlert     *alert = [[NSAlert alloc] init];

    if ([delegate respondsToSelector:@selector(connectionPrepareForSheet)])
        [delegate connectionPrepareForSheet];

    [alert setMessageText:NSLocalizedString(@"FirstTimeHeader", nil)];
    [alert setInformativeText:NSLocalizedString(@"FirstTimeMessage", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Connect", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert beginSheetModalForWindow:window modalDelegate:self
                     didEndSelector:@selector(firstTime:returnCode:contextInfo:)
                        contextInfo:NULL];
}

- (void)firstTime:(NSAlert *)sheet returnCode:(int)retCode
      contextInfo:(void *)info
{
    [tunnel acceptKey:retCode == NSAlertFirstButtonReturn];
}

- (void)getPassword
{
    auth = [[AuthPrompt alloc] initWithDelegate:self];

    if ([delegate respondsToSelector:@selector(connectionPrepareForSheet)])
        [delegate connectionPrepareForSheet];
    [auth runSheetOnWindow:window]; 
}

- (void)tunnelEstablishedAtPort:(in_port_t)aPort
{
    host = @"localhost";
    port = aPort;
    lock = [[NSLock alloc] init];
    currentSock = -1;

    [NSThread detachNewThreadSelector: @selector(connect:) toTarget: self
                           withObject: nil];
}

- (void)finishConnection
{
    NSFileHandle    *fh;
    RFBConnection   *conn;
    
    if (delegate == nil)
        return;

    fh = [[NSFileHandle alloc] initWithFileDescriptor: currentSock
                                       closeOnDealloc: YES];
    conn = [[RFBConnection alloc] initWithFileHandle:fh server:server];
    [conn setSshTunnel:tunnel];
    [delegate connectionSucceeded:conn];

    [fh release];
    [tunnel release];
    tunnel = nil;
    [conn release];
    currentSock = -1;
}

- (void)sshFailed
{
    [delegate connectionFailed];
}

- (void)sshFailedWithError:(NSString *)err
{
    NSString    *fmt = NSLocalizedString(@"SshError", nil);
    NSString    *header = [NSString stringWithFormat:fmt, [server sshHost]];

    [self error:header message:err];
}

- (void)authCancelled
{
    [auth release];
    auth = nil;
    [delegate connectionFailed];
    [tunnel close];
}

- (void)authPasswordEntered:(NSString *)password
{
    [auth release];
    auth = nil;
    [tunnel usePassword:password];
    if ([delegate respondsToSelector:@selector(connectionSheetOver)])
        [delegate connectionSheetOver];
}

@end
