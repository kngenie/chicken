/* FrameBufferDrawing.m created by helmut on Wed 23-Jun-1999 */

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

/* --------------------------------------------------------------------------------- */
/* the compiler will hopefully pull the switch() and if()s out of the loop after inlining... */

#undef PINFO

static inline unsigned int cvt_pixel24(unsigned char* v, FrameBuffer* this)
{
	unsigned char r, g, b;
    unsigned int col;
	
    if(this->pixelFormat.bigEndian) {
        r = *v++;
        g = *v++;
        b = *v;
    } else {
        b = *v++;
        g = *v++;
        r = *v;
    }
    col = this->redClut[r & this->pixelFormat.redMax];
    col += this->greenClut[g & this->pixelFormat.greenMax];
    col += this->blueClut[b & this->pixelFormat.blueMax];
    return col;
}

static inline unsigned int cvt_pixel(unsigned char* v, FrameBuffer *this)
{
    unsigned int pix = 0, col;

    switch(this->pixelFormat.bitsPerPixel / 8) {
        case 1:
            pix = *v;
            break;
        case 2:
            if(this->pixelFormat.bigEndian) {
                pix = *v++; pix <<= 8; pix += *v;
            } else {
                pix = *v++; pix += (((unsigned int)*v) << 8);
            }
            break;
        case 4:
            if(this->pixelFormat.bigEndian) {
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
    col = this->redClut[(pix >> this->pixelFormat.redShift) & this->pixelFormat.redMax];
    col += this->greenClut[(pix >> this->pixelFormat.greenShift) & this->pixelFormat.greenMax];
    col += this->blueClut[(pix >> this->pixelFormat.blueShift) & this->pixelFormat.blueMax];
    return col;
}

/* --------------------------------------------------------------------------------- */
- (FBColor)colorFromPixel:(unsigned char*)pixValue
{
    return (FBColor)cvt_pixel(pixValue, self);
}

- (FBColor)colorFromPixel24:(unsigned char*)pixValue
{
    return (FBColor)cvt_pixel24(pixValue, self);
}

- (void)fillColor:(FrameBufferColor*)fbc fromPixel:(unsigned char*)pixValue
{
    *((FBColor*)fbc) = cvt_pixel(pixValue, self);
}

- (void)fillColor:(FrameBufferColor*)fbc fromTightPixel:(unsigned char*)pixValue
{
	if([self tightBytesPerPixel] == 3) {
		*((FBColor*)fbc) = cvt_pixel24(pixValue, self);
	} else {
		*((FBColor*)fbc) = cvt_pixel(pixValue, self);
	}
}

/* --------------------------------------------------------------------------------- */
- (void)fillRect:(NSRect)aRect withColor:(FBColor)aColor
{	
    FBColor* start;
    unsigned int stride, i, lines;

#ifdef DEBUG_DRAW
printf("fill x=%f y=%f w=%f h=%f -> %d\n", aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height, aColor);
#endif

#ifdef PINFO
	fillRectCount++;
    fillPixelCount += aRect.size.width * aRect.size.height;
#endif

    start = pixels + (int)(aRect.origin.y * size.width) + (int)aRect.origin.x;
    lines = aRect.size.height;
    stride = size.width - aRect.size.width;
    while(lines--) {
        for(i=aRect.size.width; i; i--) {
            *start++ = aColor;
        }
        start += stride;
    }
}

/* --------------------------------------------------------------------------------- */
- (void)putRect:(NSRect)aRect withColors:(FrameBufferPaletteIndex*)data fromPalette:(FrameBufferColor*)palette
{
	FBColor*		start;
	unsigned int	stride, i, lines;

    start = pixels + (int)(aRect.origin.y * size.width) + (int)aRect.origin.x;
    lines = aRect.size.height;
    stride = size.width - aRect.size.width;
    while(lines--) {
        for(i=aRect.size.width; i; i--) {
            *start++ = *((FBColor*)(palette + *data));
			data++;
        }
        start += stride;
    }
}

/* --------------------------------------------------------------------------------- */
- (void)putRun:(FrameBufferColor*)fbc ofLength:(int)length at:(NSRect)aRect pixelOffset:(int)offset
{
	FBColor*		start;
	unsigned int	stride, width;
	unsigned int	offLines, offPixels;

	offLines = offset / (int)aRect.size.width;
	offPixels = offset - (offLines * (int)aRect.size.width);
	width = aRect.size.width - offPixels;
	offLines += aRect.origin.y;
	offPixels += aRect.origin.x;
	start = pixels + (int)(offLines * size.width + offPixels);
    stride = size.width - aRect.size.width;
	if(width > length) {
		width = length;
	}
	do {
		length -= width;
		while(width--) {
			*start++ = *((FBColor*)fbc);
		}
		start += stride;
		width = aRect.size.width;
		if(width > length) {
			width = length;
		}
	} while(width > 0);
}

/* --------------------------------------------------------------------------------- */
- (void)fillRect:(NSRect)aRect withFbColor:(FrameBufferColor*)fbc
{
    [self fillRect:aRect withColor:*((FBColor*)fbc)];
}

/* --------------------------------------------------------------------------------- */
- (void)fillRect:(NSRect)aRect withPixel:(unsigned char*)pixValue;
{	
    [self fillRect:aRect withColor:[self colorFromPixel:pixValue]];
}

/* --------------------------------------------------------------------------------- */
- (void)fillRect:(NSRect)aRect tightPixel:(unsigned char*)pixValue
{
    if([self tightBytesPerPixel] == 3) {
        [self fillRect:aRect withColor:[self colorFromPixel24:pixValue]];
    } else {
        [self fillRect:aRect withPixel:pixValue];
    }
}

/* --------------------------------------------------------------------------------- */
- (void)copyRect:(NSRect)aRect to:(NSPoint)aPoint
{
        int line_step, src_start_x, dst_start_x;
        int stride, src_start_y, dst_start_y;
        FBColor* src, *dst;
        int lines = aRect.size.height;
        int i;

#ifdef DEBUG_DRAW
printf("copy x=%f y=%f w=%f h=%f -> x=%f y=%f\n", aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height, aPoint.x, aPoint.y);
#endif

#ifdef PINFO
    copyRectCount++;
    copyPixelCount += aRect.size.width * aRect.size.height;
#endif
        if(aPoint.x < aRect.origin.x) {
                line_step = 1;
                src_start_x = aRect.origin.x;
                dst_start_x = aPoint.x;
        } else {
                line_step = -1;
                src_start_x = NSMaxX(aRect) - 1;
                dst_start_x = aPoint.x + aRect.size.width - 1;
        }
        if(aPoint.y < aRect.origin.y) {
                stride = (line_step > 0) ? size.width - aRect.size.width :
                                           size.width + aRect.size.width;
                src_start_y = aRect.origin.y;
                dst_start_y = aPoint.y;
        } else {
                stride = (line_step > 0) ? -size.width - aRect.size.width :
                                           -size.width + aRect.size.width;
                src_start_y = NSMaxY(aRect) - 1;
                dst_start_y = aPoint.y + aRect.size.height - 1;
        }
        src = pixels + (int)(src_start_y * size.width) + (int)src_start_x;
        dst = pixels + (int)(dst_start_y * size.width) + (int)dst_start_x;
        while(lines--) {
			for(i=aRect.size.width; i; i--) {
				*dst = *src;
				dst += line_step;
				src += line_step;
			}
			dst += stride;
			src += stride;
        }
}

/* --------------------------------------------------------------------------------- */
- (void)putRect:(NSRect)aRect fromTightData:(unsigned char*)data
{
    if([self tightBytesPerPixel] == 3) {
        FBColor* start;
        unsigned int stride, i, lines;

    #ifdef DEBUG_DRAW
    printf("put x=%f y=%f w=%f h=%f\n", aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height);
    #endif

    #ifdef PINFO
        putRectCount++;
        putPixelCount += aRect.size.width * aRect.size.height;
    #endif

        start = pixels + (int)(aRect.origin.y * size.width) + (int)aRect.origin.x;
        lines = aRect.size.height;
        stride = size.width - aRect.size.width;
		while(lines--) {
			for(i=aRect.size.width; i; i--) {
				*start++ = cvt_pixel24(data, self);
				data += 3;
			}
			start += stride;
		}
    } else {
        [self putRect:aRect fromData:data];
    }
}

/* --------------------------------------------------------------------------------- */
- (void)putRect:(NSRect)aRect fromRGBBytes:(unsigned char*)rgb
{
	FBColor* start;
	unsigned int stride, i, lines, col;

#ifdef PINFO
	putRectCount++;
	pubPixelCount += aRect.size.width * aRect.size.height;
#endif

    start = pixels + (int)(aRect.origin.y * size.width) + (int)aRect.origin.x;
    lines = aRect.size.height;
    stride = size.width - aRect.size.width;
	while(lines--) {
        for(i=aRect.size.width; i; i--) {
			col = redClut[(maxValue * *rgb++) / 255];
			col += greenClut[(maxValue * *rgb++) / 255];
			col += blueClut[(maxValue * *rgb++) / 255];
			*start++ = col;
		}
		start += stride;
	}
}

/* --------------------------------------------------------------------------------- */
#define CLUT(c,p)																\
c = redClut[(p >> pixelFormat.redShift) & pixelFormat.redMax];					\
c += greenClut[(p >> pixelFormat.greenShift) & pixelFormat.greenMax]; 			\
c += blueClut[(p >> pixelFormat.blueShift) & pixelFormat.blueMax]

- (void)putRect:(NSRect)aRect fromData:(unsigned char*)data
{
    FBColor* start;
    unsigned int stride, i, lines, pix, col;

#ifdef DEBUG_DRAW
printf("put x=%f y=%f w=%f h=%f\n", aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height);
#endif

#ifdef PINFO
    putRectCount++;
    putPixelCount += aRect.size.width * aRect.size.height;
#endif

    start = pixels + (int)(aRect.origin.y * size.width) + (int)aRect.origin.x;
    lines = aRect.size.height;
    stride = size.width - aRect.size.width;

	switch(pixelFormat.bitsPerPixel / 8) {
		case 1:
			while(lines--) {
				for(i=aRect.size.width; i; i--) {
					pix = *data++;
					CLUT(col, pix);
					*start++ = col;
				}
				start += stride;
			}
			break;
		case 2:
			if(pixelFormat.bigEndian) {
				while(lines--) {
					for(i=aRect.size.width; i; i--) {
						pix = *data++; pix <<= 8; pix += *data++;
						CLUT(col, pix);
						*start++ = col;
					}
					start += stride;
				}
			} else {
				while(lines--) {
					for(i=aRect.size.width; i; i--) {
						pix = *data++; pix += (((unsigned int)*data++) << 8);
						CLUT(col, pix);
						*start++ = col;
					}
					start += stride;
				}
			}
			break;
		case 4:
			if(pixelFormat.bigEndian) {
				while(lines--) {
					for(i=aRect.size.width; i; i--) {
						pix = *data++; pix <<= 8;
						pix += *data++; pix <<= 8;
						pix += *data++; pix <<= 8;
						pix += *data++;
						CLUT(col, pix);
						*start++ = col;
					}
					start += stride;
				}
			} else {
				while(lines--) {
					for(i=aRect.size.width; i; i--) {
						pix = *data++;
						pix += (((unsigned int)*data++) << 8);
						pix += (((unsigned int)*data++) << 16);
						pix += (((unsigned int)*data++) << 24);
						CLUT(col, pix);
						*start++ = col;
					}
					start += stride;
				}
			}
			break;
	}
}

/* --------------------------------------------------------------------------------- */
- (void)drawRect:(NSRect)aRect at:(NSPoint)aPoint
{
    NSRect r;
    int bpr;
    FBColor* start;

#ifdef DEBUG_DRAW
printf("draw x=%f y=%f w=%f h=%f at x=%f y=%f\n", aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height, aPoint.x, aPoint.y);
#endif

#ifdef PINFO
    drawRectCount++;
    drawPixelCount += aRect.size.width * aRect.size.height;
#endif

    r = aRect;
    if(NSMaxX(r) >= size.width) {
        r.size.width = size.width - r.origin.x;
    }
    if(NSMaxY(r) >= size.height) {
        r.size.height = size.height - r.origin.y;
    }
    start = pixels + (int)(aRect.origin.y * size.width) + (int)aRect.origin.x;
    r.origin = aPoint;
    if((aRect.size.width * aRect.size.height) > SCRATCHPAD_SIZE) {
        bpr = size.width * sizeof(FBColor);
        NSDrawBitmap(r, r.size.width, r.size.height, bitsPerColor, samplesPerPixel, sizeof(FBColor) * 8, bpr, NO, NO, NSDeviceRGBColorSpace, (const unsigned char**)&start);
    } else {
        FBColor* sp = scratchpad;
        int lines = r.size.height;
        int stride = (unsigned int)size.width - (unsigned int)r.size.width;

        while(lines--) {
            memcpy(sp, start, r.size.width * sizeof(sp));
            start += (unsigned int) r.size.width;
            sp += (unsigned int) r.size.width;
            start += stride;
        }
        bpr = r.size.width * sizeof(FBColor);
        NSDrawBitmap(r, r.size.width, r.size.height, bitsPerColor, samplesPerPixel, sizeof(FBColor) * 8, bpr, NO, NO, NSDeviceRGBColorSpace, (const unsigned char**)&scratchpad);
    }
}


/*
NSDrawBitmap

Summary: This function draws a bitmap image.

Declared in: AppKit/NSGraphics.h

Synopsis: void NSDrawBitmap(const NSRect *rect, int pixelsWide, int
pixelsHigh, int bitsPerSample, int
samplesPerPixel, int bitsPerPixel, int bytesPerRow, BOOL isPlanar, BOOL
hasAlpha, NSColorSpace colorSpace,
const unsigned char *const data[5])


Warning: This function is marginally obsolete. Most applications are better
served using the NSBitmapImageRep class to read
and display bitmap images.


Description: The NSDrawBitmap function renders an image from a bitmap, binary
data that describes the pixel values for the
image (this function replaces NSImageBitmap).

NSDrawBitmap renders a bitmap image using an appropriate PostScript
operator-image, colorimage, or alphaimage. It puts
the image in the rectangular area specified by its first argument, rect; the
rectangle is specified in the current coordinate system
and is located in the current window. The next two arguments, pixelsWide and
pixelsHigh, give the width and height of the
image in pixels. If either of these dimensions is larger or smaller than the
corresponding dimension of the destination rectangle,
the image will be scaled to fit.

The remaining arguments to NSDrawBitmap describe the bitmap data, as explained
in the following paragraphs.

bitsPerSample is the number of bits per sample for each pixel and
samplesPerPixel is the number of samples per pixel.
bitsPerPixel is based on samplesPerPixel and the configuration of the bitmap:
if the configuration is planar, then the value
of bitsPerPixel should equal the value of bitsPerSample; if the configuration
isn't planar (is meshed instead),
bitsPerPixel should equal bitsPerSample * samplesPerPixel.

bytesPerRow is calculated in one of two ways, depending on the configuration
of the image data (data configuration is
described below). If the data is planar, bytesPerRow is (7 + (pixelsWide *
bitsPerSample)) / 8. If the data is meshed,
bytesPerRow is (7 + (pixelsWide * bitsPerSample * samplesPerPixel)) / 8.

A sample is data that describes one component of a pixel. In an RGB color
system, the red, green, and blue components of a
color are specified as separate samples, as are the cyan, magenta, yellow, and
black components in a CMYK system. Color
values in a gray scale are a single sample. Alpha values that determine
transparency and opaqueness are specified as a coverage
sample separate from color. In bitmap images with alpha, the color (or gray)
components have to be premultiplied with the
alpha. This is the way images with alpha are displayed, this is the way they
are read back, and this is the way they are stored in
TIFFs.

isPlanar refers to the way data is configured in the bitmap. This flag should
be set YES if a separate data channel is used for
each sample. The function provides for up to five channels, data1, data2,
data3, data4, and data5. It should be set NO
if sample values are interwoven in a single channel (meshed); all values for
one pixel are specified before values for the next
pixel.

Gray-scale windows store pixel data in planar configuration; color windows
store it in meshed configuration. NSDrawBitmap
can render meshed data in a planar window, or planar data in a meshed window.
However, it's more efficient if the image has a
depth (bitsPerSample) and configuration (isPlanar) that matches the window.

hasAlpha indicates whether the image contains alpha. If it does, the number of
samples should be 1 greater than the number of
color components in the model (e.g., 4 for RGB).

colorSpace can be NS_CustomColorSpace, indicating that the image data is to be
interpreted according to the current color
space in the PostScript graphics state. This allows for imaging using custom
color spaces. The image parameters supplied as the
other arguments should match what the color space is expecting.

If the image data is planar, data[0] through data[samplesPerPixel-1] point to
the planes; if the data is meshed, only
data[0] needs to be set.
*/

