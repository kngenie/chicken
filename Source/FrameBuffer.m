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


#import "FrameBuffer.h"
#import "PrefController.h"
#import "RFBConnectionManager.h"

@implementation FrameBuffer

/* --------------------------------------------------------------------------------- */
static void ns_pixel(unsigned char* v, FrameBuffer *this, float* clr)
{
    unsigned int pix = 0;

    switch(this->pixelFormat.bitsPerPixel / 8) {
        case 1:
            pix = *v;
            break;
        case 2:
            if([this serverIsBigEndian]) {
                pix = *v++; pix <<= 8; pix += *v;
            } else {
                pix = *v++; pix += (((unsigned int)*v) << 8);
            }
            break;
        case 4:
            if([this serverIsBigEndian]) {
                pix = *v++; pix <<= 8;
                pix += *v++; pix <<= 8;
                pix += *v++; pix <<= 8;
                pix += *v;
            } else {
                pix = *v++;
                pix += (((unsigned int)*v++) << 8);
                pix += (((unsigned int)*v++) << 16);
                pix += (((unsigned int)*v) << 24);
            }
            break;
		default:
			[NSException raise: NSGenericException format: @"Unsupported bytesPerPixel"];
    }
    clr[0] = (float)(this->redClut[(pix >> this->pixelFormat.redShift) & this->pixelFormat.redMax] >> this->rshift) / this->maxValue;
    clr[1] = (float)(this->greenClut[(pix >> this->pixelFormat.greenShift) & this->pixelFormat.greenMax] >> this->gshift) / this->maxValue;
    clr[2] = (float)(this->blueClut[(pix >> this->pixelFormat.blueShift) & this->pixelFormat.blueMax] >> this->bshift) / this->maxValue;
    if(this->samplesPerPixel == 1) {	/* greyscale */
        clr[0] += clr[1] + clr[2];
        clr[1] = clr[2] = clr[0];
    }
}

/* --------------------------------------------------------------------------------- */
#define TO_PIX(pix,rgb)																\
	pix = (*rgb++ & pixelFormat.redMax) << pixelFormat.redShift;					\
	pix |= (*rgb++ & pixelFormat.greenMax) << pixelFormat.greenShift;				\
	pix |= (*rgb++ & pixelFormat.blueMax) << pixelFormat.blueShift	

- (void)combineRGB:(int*)rgb pixels:(unsigned)length into:(unsigned char*)v
{
    int pix, bpp = [self tightBytesPerPixel];

	switch(bpp) {
		case 1:
			while(length--) {
				TO_PIX(pix, rgb);
				*v++ = pix;
			}
			break;
		case 2:
			if([self serverIsBigEndian]) {
				while(length--) {
					TO_PIX(pix, rgb);
                    *v++ = (pix >> 8) & 0xff;
                    *v++ = pix & 0xff;
				}
			} else {
				while(length--) {
					TO_PIX(pix, rgb);
                    *v++ = pix & 0xff;
                    *v++ = (pix >> 8) & 0xff;
				}
			}
			break;
		case 3:
			if([self serverIsBigEndian]) {
				while(length--) {
					TO_PIX(pix, rgb);
                    *v++ = (pix >> 16) & 0xff;
                    *v++ = (pix >> 8) & 0xff;
                    *v++ = pix & 0xff;
				}
			} else {
				while(length--) {
					TO_PIX(pix, rgb);
                    *v++ = (pix >> 16) & 0xff;
                    *v++ = (pix >> 8) & 0xff;
                    *v++ = pix & 0xff;
				}
			}
			break;
		case 4:
			if([self serverIsBigEndian]) {
				while(length--) {
					TO_PIX(pix, rgb);
                    *v++ = (pix >> 24) & 0xff;
                    *v++ = (pix >> 16) & 0xff;
                    *v++ = (pix >> 8) & 0xff;
                    *v++ = pix & 0xff;
				}
			} else {
				while(length--) {
					TO_PIX(pix, rgb);
                    *v++ = pix & 0xff;
                    *v++ = (pix >> 8) & 0xff;
                    *v++ = (pix >> 16) & 0xff;
                    *v++ = (pix >> 24) & 0xff;
				}
			}
			break;
	}
}

/* --------------------------------------------------------------------------------- */
#define TO_RGB(d,c)														\
	*d++ = (c >> pixelFormat.redShift) & pixelFormat.redMax;			\
	*d++ = (c >> pixelFormat.greenShift) & pixelFormat.greenMax;		\
	*d++ = (c >> pixelFormat.blueShift) & pixelFormat.blueMax

- (void)splitRGB:(unsigned char*)v pixels:(unsigned)length into:(int*)rgb
{
	unsigned char c;
    int pix;
    
    switch([self tightBytesPerPixel]) {
        case 1:
            while(length--) {
				c = *v++;
				TO_RGB(rgb, c);
            }
            break;
        case 2:
			if([self serverIsBigEndian]) {
				while(length--) {
                    pix = *v++; pix <<= 8; pix += *v++;
					TO_RGB(rgb, pix);
				}
			} else {
				while(length--) {
					pix = *v++; pix += (((unsigned int)*v++) << 8);
					TO_RGB(rgb, pix);
				}
			}
            break;
        case 3:
			if([self serverIsBigEndian]) {
				while(length--) {
					pix = *v++; pix <<= 8;
					pix += *v++; pix <<= 8;
					pix += *v++;
					TO_RGB(rgb, pix);
				}
			} else {
				while(length--) {
					pix = *v++;
					pix += (((unsigned int)*v++) << 8);
					pix += (((unsigned int)*v++) << 16);
					TO_RGB(rgb, pix);
				}
			}
            break;
        case 4:
			if([self serverIsBigEndian]) {
				while(length--) {
                    pix = *v++; pix <<= 8;
                    pix += *v++; pix <<= 8;
                    pix += *v++; pix <<= 8;
                    pix += *v++;
					TO_RGB(rgb, pix);
				}
			} else {
				while(length--) {
                    pix = *v++;
                    pix += (((unsigned int)*v++) << 8);
                    pix += (((unsigned int)*v++) << 16);
                    pix += (((unsigned int)*v++) << 24);
					TO_RGB(rgb, pix);
				}
			}
            break;
    }
}

/* --------------------------------------------------------------------------------- */
- (void)getMaxValues:(int*)m
{
    m[0] = pixelFormat.redMax;
    m[1] = pixelFormat.greenMax;
    m[2] = pixelFormat.blueMax;
}

/* --------------------------------------------------------------------------------- */
- (void)setPixelFormat:(rfbPixelFormat*)theFormat
{
    int		i;
    double	rweight, gweight, bweight, gamma = 1.0/[[PrefController sharedController] gammaCorrection];

    fprintf(stderr, "rfbPixelFormat redMax = %d\n", theFormat->redMax);
    fprintf(stderr, "rfbPixelFormat greenMax = %d\n", theFormat->greenMax);
    fprintf(stderr, "rfbPixelFormat blueMax = %d\n", theFormat->blueMax);
    if(theFormat->redMax > 255)
        theFormat->redMax = 255;		/* limit at our LUT size */
    if(theFormat->greenMax > 255)
        theFormat->greenMax = 255;	/* limit at our LUT size */
    if(theFormat->blueMax > 255)
        theFormat->blueMax = 255;	/* limit at our LUT size */
    memcpy(&pixelFormat, theFormat, sizeof(pixelFormat));
    bytesPerPixel = pixelFormat.bitsPerPixel / 8;
	
    if(samplesPerPixel == 1) {			/* greyscale */
        rweight = 0.3;
        gweight = 0.59;
        bweight = 0.11;
    } else {
        rweight = gweight = bweight = 1.0;
    }

    for(i=0; i<=theFormat->redMax; i++) {
        redClut[i] = (int)(rweight * pow((double)i / (double)theFormat->redMax, gamma) * maxValue + 0.5) << rshift;
    }
    for(i=0; i<=theFormat->greenMax; i++) {
        greenClut[i] = (int)(gweight * pow((double)i / (double)theFormat->greenMax, gamma) * maxValue + 0.5) << gshift;
    }
    for(i=0; i<=theFormat->blueMax; i++) {
        blueClut[i] = (int)(bweight * pow((double)i / (double)theFormat->blueMax, gamma) * maxValue + 0.5) << bshift;
    }
}

/* --------------------------------------------------------------------------------- */
+ (void)getPixelFormat:(rfbPixelFormat*)pf
{
}

/* --------------------------------------------------------------------------------- */
+ (BOOL)bigEndian
{
    union {
        unsigned char	c[2];
        unsigned short	s;
    } x;

    x.s = 0x1234;
    return (x.c[0] == 0x12);
}

/* --------------------------------------------------------------------------------- */
- (BOOL)bigEndian
{
    return isBig;
}

/* --------------------------------------------------------------------------------- */
- (BOOL)serverIsBigEndian
{
	// tightvnc on Intel Linux isn't conforming to the spec.  The spec says that if 
	// we're using 24 bit Tight encoding with 8-bit color channels, the byte order
	// should always be RGB.  They're sending BGR.  So this is a nasty hack to make 
	// it display correctly.
	//
	// The intent is to force bigEndianness only for that particular server.
	//
	// Caveat. I'm only forcing if the server version is reported as 3.3 or 3.7.  I don't know
	// whether they've fixed it in a later build.  If they haven't, this will break.
	if ( ! forceServerBigEndian )
	{
		forceServerBigEndian = malloc( sizeof(*forceServerBigEndian) );
		*forceServerBigEndian = (32 == pixelFormat.bitsPerPixel
								 && 24 == pixelFormat.depth
								 && 0 == pixelFormat.bigEndian
								 && 0 != pixelFormat.trueColour
								 && 16 == pixelFormat.redShift
								 && 8 == pixelFormat.greenShift
								 && 0 == pixelFormat.blueShift
								 && 3 == serverMajorVersion 
								 && (3 == serverMinorVersion || 7 == serverMinorVersion) );
		if ( *forceServerBigEndian )
			NSLog(@"stupid compatibility hack - forcing server to be bigEndian if Tight Encoding is used");
	}
	return *forceServerBigEndian ? currentReaderIsTight : pixelFormat.bigEndian;
}

/* --------------------------------------------------------------------------------- */
- (void)setServerMajorVersion: (int)major minorVersion: (int)minor
{
	serverMajorVersion = major;
	serverMinorVersion = minor;
}

/* --------------------------------------------------------------------------------- */
- (void)setCurrentReaderIsTight: (BOOL)flag
{
//	NSLog(@"current reader is tight: %@", flag ? @"YES" : @"NO");
	currentReaderIsTight = currentReaderIsTight || flag;
}

/* --------------------------------------------------------------------------------- */
- (id)initWithSize:(NSSize)aSize andFormat:(rfbPixelFormat*)theFormat
{
    union {
        unsigned char	c[2];
        unsigned short	s;
    } x;

    if (self = [super init]) {
		x.s = 0x1234;
		isBig = (x.c[0] == 0x12);
		size = aSize;
/*
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(monitor:)
                                   userInfo:nil repeats:YES];
*/
	}
    return self;
}

/* --------------------------------------------------------------------------------- */
- (void)dealloc
{
	if ( forceServerBigEndian )
		free( forceServerBigEndian );
	[super dealloc];
}

/* --------------------------------------------------------------------------------- */
- (void)monitor:(id)sender
{
    static unsigned	_fillRectCount = 0;
    static unsigned	_drawRectCount = 0;
    static unsigned	_copyRectCount = 0;
    static unsigned	_putRectCount = 0;
    static unsigned	_fillPixelCount = 0;
    static unsigned	_drawPixelCount = 0;
    static unsigned	_copyPixelCount = 0;
    static unsigned	_putPixelCount = 0;

    printf("\nrects (f/d/c/p): %d/%d/%d/%d",
           (fillRectCount - _fillRectCount),
           (drawRectCount - _drawRectCount),
           (copyRectCount - _copyRectCount),
           (putRectCount - _putRectCount));
    printf("\npixls (f/d/c/p): %d/%d/%d/%d",
           (fillPixelCount - _fillPixelCount),
           (drawPixelCount - _drawPixelCount),
           (copyPixelCount - _copyPixelCount),
           (putPixelCount - _putPixelCount));
    fflush(stdout);
    
    _fillRectCount = fillRectCount;
    _drawRectCount = drawRectCount;
    _copyRectCount = copyRectCount;
    _putRectCount = putRectCount;
    _fillPixelCount = fillPixelCount;
    _drawPixelCount = drawPixelCount;
    _copyPixelCount = copyPixelCount;
    _putPixelCount = putPixelCount;
}

/* --------------------------------------------------------------------------------- */
- (NSSize)size
{
    return size;
}

/* --------------------------------------------------------------------------------- */
- (unsigned int)bytesPerPixel
{
    return bytesPerPixel;
}

- (unsigned int)tightBytesPerPixel
{
    if((pixelFormat.bitsPerPixel == 32) &&
		(pixelFormat.depth == 24) &&
        (pixelFormat.redMax == 0xff) &&
        (pixelFormat.greenMax == 0xff) &&
        (pixelFormat.blueMax == 0xff)) {
        return 3;
    } else {
        return bytesPerPixel;
    }
}

/* --------------------------------------------------------------------------------- */
- (NSColor*)nsColorFromPixel:(unsigned char*)pixValue
{
    float nsv[3];

    ns_pixel(pixValue, self, nsv);
    return [NSColor colorWithDeviceRed:nsv[0] green:nsv[1] blue:nsv[2] alpha:0.0];
}

/* --------------------------------------------------------------------------------- */
- (void)getRGB:(float*)rgb fromPixel:(unsigned char*)pixValue
{
    ns_pixel(pixValue, self, rgb);
}

/* --------------------------------------------------------------------------------- */
- (void)fillColor:(FrameBufferColor*)fbc fromPixel:(unsigned char*)pixValue {}
- (void)fillColor:(FrameBufferColor*)fbc fromTightPixel:(unsigned char*)pixValue {}
- (void)fillRect:(NSRect)aRect withPixel:(unsigned char*)pixValue {}
- (void)fillRect:(NSRect)aRect withFbColor:(FrameBufferColor*)fbc {}
- (void)copyRect:(NSRect)aRect to:(NSPoint)aPoint {}
- (void)putRect:(NSRect)aRect fromData:(unsigned char*)data {}
- (void)drawRect:(NSRect)aRect at:(NSPoint)aPoint {}
- (void)fillRect:(NSRect)aRect tightPixel:(unsigned char*)pixValue {}
- (void)putRect:(NSRect)aRect fromTightData:(unsigned char*)data {}
- (void)putRect:(NSRect)aRect withColors:(FrameBufferPaletteIndex*)data fromPalette:(FrameBufferColor*)palette {}
- (void)putRun:(FrameBufferColor*)fbc ofLength:(int)length at:(NSRect)aRect pixelOffset:(int)offset {}
- (void)putRect:(NSRect)aRect fromRGBBytes:(unsigned char*)rgb {}
/* --------------------------------------------------------------------------------- */

@end

 