/* FrameBufferUpdateReader.m created by helmut on Wed 17-Jun-1998 */

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

#import "FrameBufferUpdateReader.h"
#import "ByteBlockReader.h"
#import "RawEncodingReader.h"
#import "CopyRectangleEncodingReader.h"
#import "CoRREEncodingReader.h"
#import "HextileEncodingReader.h"
#import "PrefController.h"
#import "RFBConnection.h"
#import "RFBConnectionManager.h"
#import "RREEncodingReader.h"
#import "TightEncodingReader.h"
#import "ZlibEncodingReader.h"
#import "ZlibHexEncodingReader.h"
#import "ZRLEEncodingReader.h"

#import "debug.h"

@implementation FrameBufferUpdateReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
    if (self = [super initTarget:aTarget action:anAction]) {
		PrefController *prefs = [PrefController sharedController];
		int pst = [prefs PS_THRESHOLD];
		int mpr = [prefs PS_MAXRECTS];

		headerReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setHeader:) size:3];
		rawEncodingReader = [[RawEncodingReader alloc] initTarget:self action:@selector(didRect:)];
		copyRectangleEncodingReader = [[CopyRectangleEncodingReader alloc] initTarget:self action:@selector(didRect:)];
		rreEncodingReader = [[RREEncodingReader alloc] initTarget:self action:@selector(didRect:)];
		coRreEncodingReader = [[CoRREEncodingReader alloc] initTarget:self action:@selector(didRect:)];
		hextileEncodingReader = [[HextileEncodingReader alloc] initTarget:self action:@selector(didRect:)];
		tightEncodingReader = [[TightEncodingReader alloc] initTarget:self action:@selector(didRect:)];
		zlibEncodingReader = [[ZlibEncodingReader alloc] initTarget:self action:@selector(didRect:)];
		zrleEncodingReader = [[ZRLEEncodingReader alloc] initTarget:self action:@selector(didRect:)];
		zlibHexEncodingReader = [[ZlibHexEncodingReader alloc] initTarget:self action:@selector(didRect:)];
		rectHeaderReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setRect:) size:12];
		connection = [target topTarget];
		[rreEncodingReader setPSThreshold:pst];
		[coRreEncodingReader setPSThreshold:pst];
		[rreEncodingReader setMaximumPSRectangles:mpr];
		[coRreEncodingReader setMaximumPSRectangles:mpr];
	}
    return self;
}

- (void)dealloc
{
    [headerReader release];
    [rawEncodingReader release];
    [copyRectangleEncodingReader release];
    [rreEncodingReader release];
    [coRreEncodingReader release];
    [hextileEncodingReader release];
    [tightEncodingReader release];
    [rectHeaderReader release];
	[zlibEncodingReader release];
	[zrleEncodingReader release];
	[zlibHexEncodingReader release];
    [super dealloc];
}

- (void)setFrameBuffer:(id)aBuffer
{
    [rawEncodingReader setFrameBuffer:aBuffer];
    [copyRectangleEncodingReader setFrameBuffer:aBuffer];
    [rreEncodingReader setFrameBuffer:aBuffer];
    [coRreEncodingReader setFrameBuffer:aBuffer];
    [hextileEncodingReader setFrameBuffer:aBuffer];
    [tightEncodingReader setFrameBuffer:aBuffer];
	[zlibEncodingReader setFrameBuffer:aBuffer];
	[zrleEncodingReader setFrameBuffer:aBuffer];
	[zlibHexEncodingReader setFrameBuffer:aBuffer];
}

- (void)resetReader
{
    [target setReader:headerReader];
}

- (void)setHeader:(NSData*)header
{
    rfbFramebufferUpdateMsg msg;

#ifdef COLLECT_STATS
    bytesTransferred += [header length];
#endif
    memcpy(&msg.pad, [header bytes], sizeof(msg) - 1);
    numberOfRects = ntohs(msg.nRects);
    [connection pauseDrawing];
    [target setReader:rectHeaderReader];
}

- (void)setRect:(NSData*)rectInfo
{
    id theReader = nil;
    CARD32 e;
    rfbFramebufferUpdateRectHeader* msg = (rfbFramebufferUpdateRectHeader*)[rectInfo bytes];

#ifdef COLLECT_STATS
    bytesTransferred += [rectInfo length];
#endif
    currentRect.origin.x = ntohs(msg->r.x);
    currentRect.origin.y = ntohs(msg->r.y);
    currentRect.size.width = ntohs(msg->r.w);
    currentRect.size.height = ntohs(msg->r.h);
    if ((currentRect.size.width == 0) && (currentRect.size.height == 0)) {
		// this is a hack for compatibility with OSXvnc 1.0
		[self updateComplete];
		return;
    }
    e = ntohl(msg->encoding);
    switch(e) {
        case rfbEncodingRaw:
//			NSLog(@"Raw Encoding");
            theReader = rawEncodingReader;
            break;
        case rfbEncodingCopyRect:
//			NSLog(@"CopyRect Encoding");
            theReader = copyRectangleEncodingReader;
            break;
        case rfbEncodingRRE:
//			NSLog(@"RRE Encoding");
            theReader = rreEncodingReader;
            break;
        case rfbEncodingCoRRE:
//			NSLog(@"CoRRE Encoding");
            theReader = coRreEncodingReader;
            break;
        case rfbEncodingHextile:
//			NSLog(@"Hextile Encoding");
            theReader = hextileEncodingReader;
            break;
		case rfbEncodingZlib:
//			NSLog(@"Zlib Encoding");
			theReader = zlibEncodingReader;
			break;
        case rfbEncodingTight:
//			NSLog(@"Tight Encoding");
            theReader = tightEncodingReader;
            break;
		case rfbEncodingZlibHex:
//			NSLog(@"ZlibHex Encoding");
			theReader = zlibHexEncodingReader;
			break;
		case rfbEncodingZRLE:
//			NSLog(@"ZRLE Encoding");
			theReader = zrleEncodingReader;
			break;
    }
    if(theReader == nil) {
        [connection terminateConnection:[NSString stringWithFormat:
            @"Unknown rectangle encoding %d -> exiting", e]];
    } else {
        [theReader setRectangle:currentRect];
        [target setReader:theReader];
    }
}

- (void)didRect:(EncodingReader*)aReader
{
    id rlist = [aReader rectangleList];

#ifdef COLLECT_STATS
    bytesTransferred += [aReader bytesTransferred];
    bytesRepresented += currentRect.size.width * currentRect.size.height * [[aReader frameBuffer] bytesPerPixel];
    rectsTransferred++;
#endif
    if(rlist) {
        [connection drawRectList:rlist];
    } else {
        [connection drawRectFromBuffer:currentRect];
    }
    numberOfRects--;
    if(numberOfRects) {
        [target setReader:rectHeaderReader];
    } else {
		[self updateComplete];
    }
}

- (double)compressRatio
{
    return (bytesRepresented/bytesTransferred);
}

- (double)rectanglesTransferred
{
    return rectsTransferred;
}

- (double)bytesTransferred
{
    return bytesTransferred;
}

- (double)bytesRepresented
{
    return bytesRepresented;
}

- (void)updateComplete
{
	[target performSelector:action withObject:self];
	[connection flushDrawing];
}

@end
