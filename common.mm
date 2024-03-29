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
 
// Edward Peterlin
// 1/27/07

#include "common.h"
#include "minizip/unzip.h"
#include <stdio.h>
#include <ApplicationServices/ApplicationServices.h>
#include <QuickLook/QuickLook.h>
#include <CoreServices/CoreServices.h>

///// constants ////

/**
 * Path to Apple QuickLook plugin for handling Writer documents
 */
#define kAppleTextQLGeneratorPath	"/System/Library/QuickLook/Text.qlgenerator"

#define UNZIP_BUFFER_SIZE 4096

/**
 * Path to the thumnail preview in OpenDocument formatted files
 */
#define kODThumbnailPath	"Thumbnails/thumbnail.png"

/**
 * Path to the PDF preview in OpenDocument formatted files.
 */
#define kODPDFPath			"Thumbnails/thumbnail.pdf"

///// prototypes /////

static OSErr ExtractZipArchiveContent(CFStringRef pathToArchive, const char *fileToExtract, CFMutableDataRef fileContents);
static bool ExtractZipArchiveHasFile(CFStringRef pathToArchive, const char *fileToExtract);

///// functions /////

/**
 * Query if the specified document contains a preview image.
 *
 * @param docURL	URL to document to query.
 * @return true if document contains a PNG preview image, false if not
 */
extern "C" bool ODHasPreviewImage(CFURLRef docURL)
{
	bool ret = false;

	// check if the URL is a local file
	
	CFStringRef filePath=CFURLCopyFileSystemPath(docURL, kCFURLPOSIXPathStyle);
	if(!filePath)
		return(ret);
	
	// get listing of contents in the file
	
	ret=ExtractZipArchiveHasFile(filePath, kODThumbnailPath);
	CFRelease(filePath);

	return(ret);
}

/**
 * Extract the thumbnail image from an OpenDocument text file into a CGImage
 */
extern "C" CGImageRef CreatePreviewImageForOD(CFURLRef docURL)
{
	// check if the URL is a local file
	
	CFStringRef filePath=CFURLCopyFileSystemPath(docURL, kCFURLPOSIXPathStyle);
	if(!filePath)
		return(NULL);
	
	// extract the thumbnail image data from the file
	
	CFMutableDataRef pngData=CFDataCreateMutable(kCFAllocatorDefault, 0);
    if(!pngData)
    {
        CFRelease(filePath);
        return(NULL);
    }
    
	if(ExtractZipArchiveContent(filePath, kODThumbnailPath, pngData)!=noErr)
	{
		CFStringRef asString=CFURLGetString(docURL);
		const char *asCString=CFStringGetCStringPtr(asString, kCFStringEncodingASCII);
		fprintf(stderr, "NeoPeek: No thumbnail png content available! for '%s'\n", ((asCString) ? asCString : "<URL not convertible>"));
		CFRelease(filePath);
		CFRelease(pngData);
		return(NULL);
	}
	
	// convert the OpenDocument preview PNG into a CGImage
	
    CGImageRef toReturn=NULL;
	CGDataProviderRef imageData=CGDataProviderCreateWithCFData(pngData);
    if(imageData)
    {
        toReturn=CGImageCreateWithPNGDataProvider(imageData, NULL, true, kCGRenderingIntentDefault);
        CGDataProviderRelease(imageData);
    }
	
	// free memory
    
    CFRelease(filePath);
    CFRelease(pngData);
	
	return(toReturn);
}

/**
 * Query if the specified document contains a PDF preview data representation.
 *
 * @param docURL	URL of document to query
 * @return true if document contains a PDF preview image, false if not
 */
extern "C" bool ODHasPreviewPDF(CFURLRef docURL)
{
	bool ret = false;

	// check if the URL is a local file
	
	CFStringRef filePath=CFURLCopyFileSystemPath(docURL, kCFURLPOSIXPathStyle);
	if(!filePath)
		return(false);
	
	// get listing of contents in the file
	
	ret=ExtractZipArchiveHasFile(filePath, kODPDFPath);
	CFRelease(filePath);

	return(ret);
}

/**
 * Extract the thumbnail PDF data from an OpenDocument file into a CFDataRef.
 *
 * @param docURL	URL of document to query.
 * @return PDF image, or NULL if document does not contain a valid PDF image.
 */
extern "C" CFDataRef CreatePreviewPDFForOD(CFURLRef docURL)
{
	// check if the URL is a local file
	
	CFStringRef filePath=CFURLCopyFileSystemPath(docURL, kCFURLPOSIXPathStyle);
	if(!filePath)
		return(NULL);
	
	// extract the thumbnail image data from the file
	
	CFMutableDataRef pngData=CFDataCreateMutable(kCFAllocatorDefault, 0);
    if(!pngData)
    {
        CFRelease(filePath);
        return(NULL);
    }
    
	if(ExtractZipArchiveContent(filePath, kODPDFPath, pngData)!=noErr)
	{
		CFStringRef asString=CFURLGetString(docURL);
		const char *asCString=CFStringGetCStringPtr(asString, kCFStringEncodingASCII);
		fprintf(stderr, "NeoPeek: No thumbnail PDF content available! for '%s'\n", ((asCString) ? asCString : "<URL not convertible>"));
		CFRelease(filePath);
		CFRelease(pngData);
		return(NULL);
	}
	
	// free memory
	
	CFRelease(filePath);
	
	return(pngData);
}

/**
 * Draw the first page of a PDF into a thumbnail CG context.
 *
 * @param docURL				URL of document to query
 * @param thumbRequest			request where teh thunbmail should be output
 * @param drawWhiteBackground	true to draw a white background, false to suppress
 * @return true if thumbnail was drawn, false if not
 */
extern "C" bool DrawThumbnailPDFPageOneForOD(CFURLRef docURL, QLThumbnailRequestRef thumbRequest, bool drawWhiteBackground)
{
	// check if the URL is a local file
	
	CFStringRef filePath=CFURLCopyFileSystemPath(docURL, kCFURLPOSIXPathStyle);
	if(!filePath)
		return(NULL);
	
	// extract the thumbnail image data from the file
	
	CFMutableDataRef pdfData=CFDataCreateMutable(kCFAllocatorDefault, 0);
    if(!pdfData)
    {
        CFRelease(filePath);
        return(NULL);
    }
    
	if(ExtractZipArchiveContent(filePath, kODPDFPath, pdfData)!=noErr)
	{
		CFStringRef asString=CFURLGetString(docURL);
		const char *asCString=CFStringGetCStringPtr(asString, kCFStringEncodingASCII);
		fprintf(stderr, "NeoPeek: No thumbnail PDF content available! for '%s'\n", ((asCString) ? asCString : "<URL not convertible>"));
		CFRelease(filePath);
		CFRelease(pdfData);
		return(NULL);
	}
	
	// construct the representation of the PDF and draw the first page into the thumbnail
	
	bool toReturn=false;
	
	CGDataProviderRef pdfDataProvider=CGDataProviderCreateWithCFData(pdfData);
	if(pdfDataProvider)
	{
	CGPDFDocumentRef theDoc=CGPDFDocumentCreateWithProvider(pdfDataProvider);
	if(theDoc)
	{
		if(CGPDFDocumentGetNumberOfPages(theDoc))
		{
			CGPDFPageRef pageZero=CGPDFDocumentGetPage(theDoc, 1);
			if(pageZero)
			{
				CGRect pageRect=CGPDFPageGetBoxRect(pageZero, kCGPDFMediaBox);
				CGContextRef thumbnailContext=QLThumbnailRequestCreateContext(thumbRequest, pageRect.size, false, NULL);
				if (thumbnailContext)
				{
					if(drawWhiteBackground)
					{
						CGRect bgRect;
						bgRect.origin.x=0;
						bgRect.origin.y=0;
						bgRect.size.width=pageRect.size.width;
						bgRect.size.height=pageRect.size.height;
						CGContextSetRGBFillColor(thumbnailContext, 1.0, 1.0, 1.0, 1.0);
						CGContextFillRect(thumbnailContext, bgRect);
					}
					CGContextDrawPDFPage(thumbnailContext, pageZero);
					QLThumbnailRequestFlushContext(thumbRequest, thumbnailContext);
					CGContextRelease(thumbnailContext);
					toReturn=true;
				}
			}
		}
		
		CGPDFDocumentRelease(theDoc);
	}

		CGDataProviderRelease(pdfDataProvider);
	}
	
	// free memory
	
	CFRelease(pdfData);
	CFRelease(filePath);
	
	return(toReturn);
}

/**
 * Extract the listing of the contents of a zip archive.  Listing is in the format of unzip -l
 *
 * @param pathToArchive		path to the zip archive on disk
 * @param fileToExtract		file from the archive that should be extracted
 * @return true	if the file exists in the zipfile
 */
static bool ExtractZipArchiveHasFile(CFStringRef pathToArchive, const char *fileToExtract)
{
	bool ret = false;

	// extract the path as UTF-8 for internationalization
	
	CFIndex numChars=CFStringGetLength(pathToArchive);
	CFRange rangeToConvert={0,numChars};
	CFIndex numBytesUsed=0;
	
	if(!CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, NULL, 0, &numBytesUsed))
		return(ret);
	UInt8 *filePath=new UInt8[numBytesUsed+1];
	memset(filePath, '\0', numBytesUsed+1);
	CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, filePath, numBytesUsed+1, NULL);
		
	// open the "content.xml" file living within the sxw and read it into
	// a CFData structure for use with other CoreFoundation elements.
	
	unzFile f = unzOpen((const char *)filePath);
	if (f)
	{
		if (unzLocateFile(f, fileToExtract, 0) == UNZ_OK)
		{
			if (unzOpenCurrentFile(f) == UNZ_OK)
			{
				ret = true;
				unzCloseCurrentFile(f);
			}
		}

		unzClose(f);
	}

	delete[] filePath;
	
	return(ret);
}

/**
 * Given a path to a zip archive, extract the content of an individual file
 * of that zip archive into a mutable data structure.
 *
 * The file is attempted to be extracted using UTF8 encoding.
 *
 * @param pathToArchive		path to the zip archive on disk
 * @param fileToExtract		file from the archive that should be extracted
 * @param fileContents		mutable data that should be filled with the
 *				contents of that subfile.  File content
 *				will be appended onto any preexisting data
 *				already in the ref.
 * @return noErr on success, else OS error code
 */
static OSErr ExtractZipArchiveContent(CFStringRef pathToArchive, const char *fileToExtract, CFMutableDataRef fileContents)
{
	OSErr ret = -50;

	// extract the path as UTF-8 for internationalization
	
	CFIndex numChars=CFStringGetLength(pathToArchive);
	CFRange rangeToConvert={0,numChars};
	CFIndex numBytesUsed=0;
	
	if(!CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, NULL, 0, &numBytesUsed))
		return(ret);
	UInt8 *filePath=new UInt8[numBytesUsed+1];
	memset(filePath, '\0', numBytesUsed+1);
	CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, filePath, numBytesUsed+1, NULL);
		
	// open the "content.xml" file living within the sxw and read it into
	// a CFData structure for use with other CoreFoundation elements.
	
	unzFile f = unzOpen((const char *)filePath);
	if (f)
	{
		if (unzLocateFile(f, fileToExtract, 0) == UNZ_OK)
		{
			if (unzOpenCurrentFile(f) == UNZ_OK)
			{
				ret = noErr;

				unsigned char buf[UNZIP_BUFFER_SIZE];
				int bytesRead = 0;
				while ((bytesRead = unzReadCurrentFile(f, buf, UNZIP_BUFFER_SIZE)) > 0)
					CFDataAppendBytes(fileContents, buf, bytesRead);

				unzCloseCurrentFile(f);
			}
		}

		unzClose(f);
	}

	delete[] filePath;
	
	if (ret == noErr && CFDataGetLength(fileContents) < 28)
		return(-100);
	
	return(ret);
}

/**
 * Get a reference to the QuickLook plugin interface for the Apple Text.qlgenerator
 * plugin.
 *
 * @return interface handle, or NULL if the generator could not be loaded.
 */
QLGeneratorInterfaceStruct ** GetAppleTextQLGenerator(void)
{
	static QLGeneratorInterfaceStruct **interface=NULL;
	
	if(interface)
		return(interface);
	
	CFURLRef pluginURL=CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR(kAppleTextQLGeneratorPath), kCFURLPOSIXPathStyle, TRUE);
    if(!pluginURL)
        return(interface);
    
	CFPlugInRef generatorPlugin=CFPlugInCreate(kCFAllocatorDefault, pluginURL);
	if(generatorPlugin)
	{
		// get factory for the qlgenerator plugin type
		
		CFArrayRef qlgeneratorFactories=CFPlugInFindFactoriesForPlugInTypeInPlugIn(kQLGeneratorTypeID, generatorPlugin);
		if(qlgeneratorFactories)
		{
			for(CFIndex i=0; i < CFArrayGetCount(qlgeneratorFactories); i++)
			{
				CFUUIDRef theFactory=(CFUUIDRef)CFArrayGetValueAtIndex(qlgeneratorFactories, i);
				IUnknownVTbl **iUnknown=(IUnknownVTbl **)CFPlugInInstanceCreate(kCFAllocatorDefault, theFactory, kQLGeneratorTypeID);
				if(iUnknown)
				{
					// bootstrap off of IUnknown to get the function pointers for the QuickLook callbacks
					
					(*iUnknown)->QueryInterface(iUnknown, CFUUIDGetUUIDBytes(kQLGeneratorCallbacksInterfaceID), (LPVOID *)&interface);
					(*iUnknown)->Release(iUnknown);
					
					// if we found the correct interface, stop searching remaining factories.  We don't need them!
					
					if(interface)
						break;
				}
			}
            
            CFRelease(qlgeneratorFactories);
		}
        
        CFRelease(generatorPlugin);
        
		// NOTE:  We don't release the plugin;  we never release the plugin since we'll keep the interface statically
		// in memory so we don't need to relocate it.  As we continue to use the code, we need to keep the plugin
		// in memory.
	}
	
	CFRelease(pluginURL);
	return(interface);
}
