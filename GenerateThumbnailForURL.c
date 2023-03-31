/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * This file is part of the LibreOffice project.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This file incorporates work covered by the following license notice:
 *
 *   Licensed to the Apache Software Foundation (ASF) under one or more
 *   contributor license agreements. See the NOTICE file distributed
 *   with this work for additional information regarding copyright
 *   ownership. The ASF licenses this file to you under the Apache
 *   License, Version 2.0 (the "License"); you may not use this file
 *   except in compliance with the License. You may obtain a copy of
 *   the License at http://www.apache.org/licenses/LICENSE-2.0 .
 */

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
				CGContextRelease(thumbnailContext);
			}
            
            CGImageRelease(odPreviewImage);
            
			return(noErr);
		}
	}
    
	return(toReturn);
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}
