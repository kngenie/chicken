/* RFBServerInitReader.h created by helmut on Tue 16-Jun-1998 */

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
#import "ByteReader.h"

@interface ServerInitMessage : NSObject
{
    struct {
        CARD16	width;
        CARD16	height;
        CARD8	bpp;
        CARD8	depth;
        CARD8	big_endian;
        CARD8	true_color;
        CARD16	red_max;
        CARD16	green_max;
        CARD16	blue_max;
        CARD8	red_shift;
        CARD8	green_shift;
        CARD8	blue_shift;
        CARD8	padding[3];
    } fixed;
    NSString*	name;
}

- (void)setFixed:(NSData*)data;
- (void)setName:(NSString*)aName;
- (NSString*)name;
- (NSSize)size;
- (unsigned char*)pixelFormatData;

@end

@interface RFBServerInitReader : ByteReader
{
    id	blockReader;
    id	nameReader;
    ServerInitMessage* msg;
}

@end
