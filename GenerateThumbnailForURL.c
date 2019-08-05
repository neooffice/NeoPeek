/**
 * @file GenerateThumbnailForURL.c
 *
 * Contains primary extraction routines for the NeoPeek QuickLook plugin
 *
 *  $RCSfile$
 *
 *  $Revision$
 *
 *  last change: $Author$ $Date$
 *
 *  The Contents of this file are made available subject to the terms of
 *  either of the following licenses
 *
 *         - GNU General Public License Version 2.1
 *
 *  Edward Peterlin, 2007
 *
 *  GNU General Public License Version 2.1
 *  =============================================
 *  Copyright 2007 by Edward Peterlin (OPENSTEP@neooffice.org)
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public
 *  License version 2.1, as published by the Free Software Foundation.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 *  MA  02111-1307  USA
 *
 ************************************************************************/

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include "common.h"
#include <stdio.h>

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	OSStatus toReturn = noErr;
	bool isDraw=false;
	bool isWriter=false;
	
	// check if this is a draw document.  We will suppress explicit background drawing for Draw,
	// leaving backgrounds as transparent unless put in explicitly by rects
	
	if((CFStringCompare(contentTypeUTI, CFSTR("org.oasis.opendocument.graphics"), 0)==kCFCompareEqualTo) || (CFStringCompare(contentTypeUTI, CFSTR("org.oasis-open.opendocument.graphics"), 0)==kCFCompareEqualTo))
		isDraw=true;
	
	// check if this is a writer document.  For writer documents that do not have the
	// PDF extensions, we'll default to the Apple QuickLook generator which produces
	// more meaningful results than the low-quality PNG.
	
	if((CFStringCompare(contentTypeUTI, CFSTR("org.oasis.opendocument.text"), 0)==kCFCompareEqualTo) || (CFStringCompare(contentTypeUTI, CFSTR("org.oasis-open.opendocument.text"), 0)==kCFCompareEqualTo))
		isWriter=true;
	
	// the bitmap PNGs bite, so first check if we have the PDF thumbnail in our
	// document.  If so, render its first page into the thumbnail.
	
	if(ODHasPreviewPDF(url)) {
		if(DrawThumbnailPDFPageOneForOD(url, thumbnail, !isDraw))
			return(noErr);
	}
	
	// if we get here, we do not have a PDF embedded within the document.  Apple provides a default
	// QuickLook plugin for Writer documents.  While only extracting text and basic tables, it
	// still provides better quality than the PNG.
	
	if(isWriter && GetAppleTextQLGenerator()) {
		OSStatus appleRetVal;
		appleRetVal=(*GetAppleTextQLGenerator())->GenerateThumbnailForURL(GetAppleTextQLGenerator(), thumbnail, url, contentTypeUTI, options, maxSize);
		if(appleRetVal==noErr)
			return(noErr);
	}
	
	// fallback onto the PNG, if available
	
	if(ODHasPreviewImage(url)) {
		CGImageRef odPreviewImage=CreatePreviewImageForOD(url);
		if(odPreviewImage)
		{
			CGSize imageSize;
			imageSize.width = CGImageGetWidth(odPreviewImage);
			imageSize.height = CGImageGetHeight(odPreviewImage);
			CGContextRef thumbnailContext=QLThumbnailRequestCreateContext(thumbnail, imageSize, true, NULL);
			if (thumbnailContext)
			{
				CGRect bgRect;
				bgRect.origin.x=0;
				bgRect.origin.y=0;
				bgRect.size.width=imageSize.width;
				bgRect.size.height=imageSize.height;
				if(!isDraw)
				{
					CGContextSetRGBFillColor(thumbnailContext, 1.0, 1.0, 1.0, 1.0);
					CGContextFillRect(thumbnailContext, bgRect);
				}
				CGContextDrawImage(thumbnailContext, bgRect, odPreviewImage);
				QLThumbnailRequestFlushContext(thumbnail, thumbnailContext);
				CFRelease(thumbnailContext);
			}
            
            CFRelease(odPreviewImage);
            
			return(noErr);
		}
	}
    
	return(toReturn);
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}
