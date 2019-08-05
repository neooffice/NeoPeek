/**
 * @file GeneratePreviewForURL.c
 *
 * Output hi-res preview image for a particular document type, if available.
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
				
				CFRelease(drawRef);
			}
            
            CFRelease(odPreviewImage);
            
            return(noErr);
		}		
	}
	
	return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
