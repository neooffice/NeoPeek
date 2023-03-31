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

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
	bool isWriter=false;
	
	// check if this is a writer document.  For writer documents that do not have the
	// PDF extensions, we'll default to the Apple QuickLook generator which produces
	// more meaningful results than the low-quality PNG.
	
	if((CFStringCompare(contentTypeUTI, CFSTR("org.oasis.opendocument.text"), 0)==kCFCompareEqualTo) || (CFStringCompare(contentTypeUTI, CFSTR("org.oasis-open.opendocument.text"), 0)==kCFCompareEqualTo))
		isWriter=true;
	
	if(ODHasPreviewPDF(url)) {
		CFDataRef pdfData=CreatePreviewPDFForOD(url);
		if(pdfData)
		{
			QLPreviewRequestSetDataRepresentation(preview, pdfData, kUTTypePDF, NULL);
            CFRelease(pdfData);
			return(noErr);
		}
	}
	
	// if we get here, we do not have a PDF embedded within the document.  Apple provides a default
	// QuickLook plugin for Writer documents.  While only extracting text and basic tables, it
	// still provides better quality than the PNG.
	
	if(isWriter && GetAppleTextQLGenerator()) {
		OSStatus appleRetVal=(*GetAppleTextQLGenerator())->GeneratePreviewForURL(GetAppleTextQLGenerator(), preview, url, contentTypeUTI, options);
		if(appleRetVal==noErr)
			return(noErr);
	}
	
	// fallback on the PNG embedded within the document.
	
	if(ODHasPreviewImage(url)) {
		CGImageRef odPreviewImage=CreatePreviewImageForOD(url);
		if(odPreviewImage)
		{
			CGContextRef drawRef=QLPreviewRequestCreateContext(preview, CGSizeMake(CGImageGetWidth(odPreviewImage), CGImageGetHeight(odPreviewImage)), 1, NULL);
			if(drawRef)
			{
				CGRect destRect;
				destRect.origin.x=destRect.origin.y=0;
				destRect.size=CGSizeMake(CGImageGetWidth(odPreviewImage), CGImageGetHeight(odPreviewImage));
				CGContextDrawImage(drawRef, destRect, odPreviewImage);
				
				CGContextRelease(drawRef);
			}
            
            CGImageRelease(odPreviewImage);
            
            return(noErr);
		}		
	}
	
	return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
