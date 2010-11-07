//
//  ZlibHexEncodingReader.m
//  Chicken of the VNC
//
//  Created by Helmut Maierhofer on Fri Nov 08 2002.
//  Copyright (c) 2002 Helmut Maierhofer. All rights reserved.
//

#import "ZlibHexEncodingReader.h"
#import "RFBConnection.h"
#import "CARD16Reader.h"
#import "ByteBlockReader.h"

@implementation ZlibHexEncodingReader

- (id)initWithUpdater: (FrameBufferUpdateReader *)aUpdater connection: (RFBConnection *)aConnection
{
    if (self = [super initWithUpdater: aUpdater connection: aConnection]) {
		int inflateResult;
	
		zLengthReader = [[CARD16Reader alloc] initTarget:self action:@selector(setZLength:)];
		inflateResult = inflateInit(&rawStream);
		if(inflateResult != Z_OK) {
			[connection terminateConnection:[NSString stringWithFormat:@"Zlib encoding: inflateInit: %s.\n", rawStream.msg]];
		}
		inflateResult = inflateInit(&encodedStream);
		if(inflateResult != Z_OK) {
			[connection terminateConnection:[NSString stringWithFormat:@"Zlib encoding: inflateInit: %s.\n", encodedStream.msg]];
		}
	}
    return self;
}

- (void)dealloc
{
	[zLengthReader release];
	inflateEnd(&rawStream);
	inflateEnd(&encodedStream);
	[super dealloc];
}

- (void)checkSubEncoding
{
    if(subEncodingMask & rfbHextileRaw) {
        int s = [frameBuffer bytesPerPixel] * currentTile.size.width * currentTile.size.height;
        subEncodingMask = 0;
        [rawReader setBufferSize:s];
        [connection setReader:rawReader];
	} else if(subEncodingMask & (rfbHextileZlibRaw | rfbHextileZlibHex)) {
		[connection setReader:zLengthReader];
    } else if(subEncodingMask & rfbHextileBackgroundSpecified) {
        subEncodingMask &= ~rfbHextileBackgroundSpecified;
        [connection setReader:backGroundReader];
    } else if(subEncodingMask & rfbHextileForegroundSpecified) {
        subEncodingMask &= ~(rfbHextileForegroundSpecified | rfbHextileSubrectsColoured);
        [connection setReader:foreGroundReader];
    } else if(subEncodingMask & rfbHextileAnySubrects) {
        [connection setReader:numOfSubRectReader];
    } else {
        [self nextTile];
    }
}

- (void)inflateError
{
    NSString    *fmt = NSLocalizedString(@"ZlibHexInflateError", nil);
    NSString    *err = [NSString stringWithFormat: fmt, encodedStream.msg];

    [connection terminateConnection:err];
}

#define ZLIBHEX_MAX_RAW_TILE_SIZE 4096

/* Read the data for a tile. This may be zlib-compressed, in which case we
 * inflate, or it may be an actual raw tile, in which case we pass it along
 * super to interpret. */
- (void)drawRawTile:(NSData*)data
{
	int inflateResult, bpp;
	unsigned char* ptr;
	
	if(subEncodingMask & rfbHextileZlibRaw) {
        unsigned char buffer[ZLIBHEX_MAX_RAW_TILE_SIZE];
		rawStream.next_in = (unsigned char*)[data bytes];
		rawStream.avail_in = [data length];
		rawStream.next_out = buffer;
		rawStream.avail_out = ZLIBHEX_MAX_RAW_TILE_SIZE;
		rawStream.data_type = Z_BINARY;
		inflateResult = inflate(&rawStream, Z_SYNC_FLUSH);
		if(inflateResult < 0) {
			[connection terminateConnection:[NSString stringWithFormat:@"ZlibHex inflate error: %s", rawStream.msg]];
			return;
		}
#ifdef COLLECT_STATS
		bytesTransferred += [data length];
#endif
		[frameBuffer putRect:currentTile fromData:buffer];
		[self nextTile];
	} else if(subEncodingMask & rfbHextileZlibHex) {
        unsigned bufferSz = ZLIBHEX_MAX_RAW_TILE_SIZE;
        unsigned char *buffer = (unsigned char *)malloc(bufferSz);
        
		encodedStream.next_in = (unsigned char*)[data bytes];
		encodedStream.avail_in = [data length];
		encodedStream.next_out = buffer;
		encodedStream.avail_out = bufferSz;
		encodedStream.data_type = Z_BINARY;
		inflateResult = inflate(&encodedStream, Z_SYNC_FLUSH);
		if(inflateResult < 0) {
            [self inflateError];
            free(buffer);
			return;
		}

        // parse Hextile header
		ptr = buffer;
		bpp = [frameBuffer bytesPerPixel];
		if(subEncodingMask & rfbHextileBackgroundSpecified) {
			[frameBuffer fillColor:&background fromPixel:ptr];
			[frameBuffer fillRect:currentTile withFbColor:&background];
			ptr += bpp;
		}
		if(subEncodingMask & rfbHextileForegroundSpecified) {
			subEncodingMask &= ~(rfbHextileSubrectsColoured);
			[frameBuffer fillColor:&foreground fromPixel:ptr];
			ptr += bpp;
		}
		if(subEncodingMask & rfbHextileAnySubrects) {
            numOfSubRects = *ptr++;
            unsigned coloured = subEncodingMask & rfbHextileSubrectsColoured;
            unsigned length = (coloured ? bpp + 2 : 2) * numOfSubRects;
            unsigned size = length + (ptr - buffer);

            if (size > bufferSz) {
                // buffer wasn't large enough
                buffer = realloc(buffer, size);
                encodedStream.next_out = buffer + bufferSz
                                                - encodedStream.avail_out;
                encodedStream.avail_out += size - bufferSz;
                bufferSz = size;
                ptr = buffer + (size - length);

                inflateResult = inflate(&encodedStream, Z_SYNC_FLUSH);
                if (inflateResult < 0) {
                    [self inflateError];
                    free(buffer);
                    return;
                }
            }

            if (size > bufferSz - encodedStream.avail_out) {
                NSString    *err = NSLocalizedString(@"ZlibHexDeflateTooSmall", nil);
                [connection terminateConnection:err];
                free(buffer);
                return;
            }

            // send uncompressed data to superclass
            NSData *data = [NSData dataWithBytesNoCopy:ptr length:length
                                          freeWhenDone:NO];
            if (coloured)
                [self drawSubColorRects:data];
            else
                [self drawSubRects:data];
		} else {
			[self nextTile];
		}
        free(buffer);
	} else
        [super drawRawTile:data];
}

- (void)setZLength:(NSNumber*)theLength
{
#ifdef COLLECT_STATS
	bytesTransferred += 2;
#endif
    // Note that here we're repurposing rawReader to read either a raw tile, a
    // ZlibRaw tile, or a Zlib tile
	[rawReader setBufferSize:[theLength unsignedIntValue]];
	[connection setReader:rawReader];
}

@end
