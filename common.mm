/**
 * @file common.mm
 *
 * Shared routines for the NeoPeek QuickLook plugin.
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
 
// Edward Peterlin
// 1/27/07

#include "common.h"
#include <stdio.h>
#include <string>
#include <ApplicationServices/ApplicationServices.h>
#include <QuickLook/QuickLook.h>
#include <CoreServices/CoreServices.h>

///// constants ////

/**
 * Path to Apple QuickLook plugin for handling Writer documents
 */
#define kAppleTextQLGeneratorPath	"/System/Library/Frameworks/QuickLook.framework/Resources/Generators/Text.qlgenerator"

/**
 * Command used by popen() to construct a file handle extracting a given
 * file out of a zip archive
 */
#define kOpenSubfileCmd		"/usr/bin/unzip -p \"%s\" \"%s\""

/**
 * Command used by popen() to construct a listing of the contents of
 * a given zip archive.
 */
#define kListCmd		"/usr/bin/unzip -l \"%s\""

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
static OSErr ExtractZipArchiveListing(CFStringRef pathToArchive, std::string& fileListing);

///// functions /////

/**
 * Query if the specified document contains a preview image.
 *
 * @param docURL	URL to document to query.
 * @return true if document contains a PNG preview image, false if not
 */
extern "C" bool ODHasPreviewImage(CFURLRef docURL)
{
	// check if the URL is a local file
	
	CFStringRef filePath=CFURLCopyFileSystemPath(docURL, kCFURLPOSIXPathStyle);
	if(!filePath)
		return(false);
	
	// get listing of contents in the file
	
	std::string fileListing;
	OSErr theErr=ExtractZipArchiveListing(filePath, fileListing);
	
	CFRelease(filePath);
	
	if(theErr!=noErr)
		return(false);
	
	return(fileListing.find(kODThumbnailPath)!=std::string::npos);
}

/**
 * Extract the thumbnail image from an OpenDocument text file into a CGImage
 */
extern "C" CGImageRef GetPreviewImageForOD(CFURLRef docURL)
{
	// check if the URL is a local file
	
	CFStringRef filePath=CFURLCopyFileSystemPath(docURL, kCFURLPOSIXPathStyle);
	if(!filePath)
		return(NULL);
	
	// extract the thumbnail image data from the file
	
	CFMutableDataRef pngData=CFDataCreateMutable(kCFAllocatorDefault, 0);
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
	
	CGDataProviderRef imageData=CGDataProviderCreateWithCFData(pngData);
	
	CGImageRef toReturn;
	toReturn=CGImageCreateWithPNGDataProvider(imageData, NULL, true, kCGRenderingIntentDefault);
	
	// free memory
	
	CFRelease(filePath);
	
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
	// check if the URL is a local file
	
	CFStringRef filePath=CFURLCopyFileSystemPath(docURL, kCFURLPOSIXPathStyle);
	if(!filePath)
		return(false);
	
	// get listing of contents in the file
	
	std::string fileListing;
	OSErr theErr=ExtractZipArchiveListing(filePath, fileListing);
		
	CFRelease(filePath);
	
	if(theErr!=noErr)
		return(false);
	
	return(fileListing.find(kODPDFPath)!=std::string::npos);
}

/**
 * Extract the thumbnail PDF data from an OpenDocument file into a CFDataRef.
 *
 * @param docURL	URL of document to query.
 * @return PDF image, or NULL if document does not contain a valid PDF image.
 */
extern "C" CFDataRef GetPreviewPDFForOD(CFURLRef docURL)
{
	// check if the URL is a local file
	
	CFStringRef filePath=CFURLCopyFileSystemPath(docURL, kCFURLPOSIXPathStyle);
	if(!filePath)
		return(NULL);
	
	// extract the thumbnail image data from the file
	
	CFMutableDataRef pngData=CFDataCreateMutable(kCFAllocatorDefault, 0);
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
	CGPDFDocumentRef theDoc=CGPDFDocumentCreateWithProvider(pdfDataProvider);
	if(theDoc)
	{
		if(CGPDFDocumentGetNumberOfPages(theDoc))
		{
			CGPDFPageRef pageZero=CGPDFDocumentGetPage(theDoc, 1);
			if(pageZero)
			{
				CGRect pageRect=CGPDFPageGetBoxRect(pageZero, kCGPDFMediaBox);
				CGContextRef thumbnailContext=QLThumbnailRequestCreateContext(thumbRequest, pageRect.size, true, NULL);
				if(drawWhiteBackground)
				{
					CGRect bgRect;
					bgRect.size=pageRect.size;
					bgRect.origin.x=bgRect.origin.y=0;
					CGContextSetRGBFillColor(thumbnailContext, 1.0, 1.0, 1.0, 1.0);
					CGContextFillRect(thumbnailContext, bgRect);
				}
				CGContextDrawPDFPage(thumbnailContext, pageZero);
				QLThumbnailRequestFlushContext(thumbRequest, thumbnailContext);
				CFRelease(thumbnailContext);
			}
			toReturn=true;
		}
		
		CGPDFDocumentRelease(theDoc);
	}
	
	// free memory
	
	CFRelease(pdfDataProvider);
	CFRelease(pdfData);
	CFRelease(filePath);
	
	return(toReturn);
}

/**
 * Extract the listing of the contents of a zip archive.  Listing is in the format of unzip -l
 *
 * @param pathToArchive		path to the zipfile on disk to list
 * @param fileListing		string to fill with listing.
 * @return noErr if listing successful, else error code.
 */
static OSErr ExtractZipArchiveListing(CFStringRef pathToArchive, std::string& fileListing)
{
	// extract the path as UTF-8 for internationalization
	
	CFIndex numChars=CFStringGetLength(pathToArchive);
	CFRange rangeToConvert={0,numChars};
	CFIndex numBytesUsed=0;
	
	if(!CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, NULL, 0, &numBytesUsed))
		return(-50);
	UInt8 *filePath=new UInt8[numBytesUsed+1];
	memset(filePath, '\0', numBytesUsed+1);
	CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, filePath, numBytesUsed+1, NULL);
		
	// open the "content.xml" file living within the sxw and read it into
	// a CFData structure for use with other CoreFoundation elements.
	
	char *openCmd=new char[strlen(kListCmd)+strlen((char *)filePath)+1];
	memset(openCmd, '\0', strlen(kListCmd)+strlen((char *)filePath)+1);
	sprintf(openCmd, kListCmd, filePath);
		
	FILE *f=popen(openCmd, "r");
	if(!f)
	{
		delete[] filePath;
		delete[] openCmd;
		return(-50);
	}
	
	unsigned char c;
	while(fread(&c, 1, 1, f)==1)
	{
		fileListing+=c;
	}
	
	fclose(f);
	delete[] openCmd;
	delete[] filePath;
	
	return(noErr);
}

/**
 * Given a path to a zip archive, extract the content of an individual file
 * of that zip archive into a mutable data structure.
 *
 * The file is attempted to be extracted using UTF8 encoding.
 *
 * @param pathToArhive		path to the zip archive on disk
 * @param fileToExtract		file from the archive that should be extracted
 * @param fileContents		mutable data that should be filled with the
 *				contents of that subfile.  File content
 *				will be appended onto any preexisting data
 *				already in the ref.
 * @return noErr on success, else OS error code
 */
static OSErr ExtractZipArchiveContent(CFStringRef pathToArchive, const char *fileToExtract, CFMutableDataRef fileContents)
{
	// extract the path as UTF-8 for internationalization
	
	CFIndex numChars=CFStringGetLength(pathToArchive);
	CFRange rangeToConvert={0,numChars};
	CFIndex numBytesUsed=0;
	
	if(!CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, NULL, 0, &numBytesUsed))
		return(-50);
	UInt8 *filePath=new UInt8[numBytesUsed+1];
	memset(filePath, '\0', numBytesUsed+1);
	CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, filePath, numBytesUsed+1, NULL);
		
	// open the "content.xml" file living within the sxw and read it into
	// a CFData structure for use with other CoreFoundation elements.
	
	char *openCmd=new char[strlen(kOpenSubfileCmd)+strlen((char *)filePath)+strlen(fileToExtract)+1];
	memset(openCmd, '\0', strlen(kOpenSubfileCmd)+strlen((char *)filePath)+strlen(fileToExtract)+1);
	sprintf(openCmd, kOpenSubfileCmd, filePath, fileToExtract);
		
	FILE *f=popen(openCmd, "r");
	if(!f)
	{
		delete[] filePath;
		delete[] openCmd;
		return(-50);
	}
	
	unsigned char c;
	while(fread(&c, 1, 1, f)==1)
		CFDataAppendBytes(fileContents, &c, 1);
	
	fclose(f);
	delete[] openCmd;
	delete[] filePath;
	
	if(CFDataGetLength(fileContents) < 28)
		return(-100);
	
	return(noErr);
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
	CFPlugInRef generatorPlugin=CFPlugInCreate(kCFAllocatorDefault, pluginURL);
	if(generatorPlugin)
	{
		// get factory for the qlgenerator plugin type
		
		CFArrayRef qlgeneratorFactories=CFPlugInFindFactoriesForPlugInTypeInPlugIn(kQLGeneratorTypeID, generatorPlugin);
		if(qlgeneratorFactories && CFArrayGetCount(qlgeneratorFactories))
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
		}
		
		// NOTE:  We don't release the plugin;  we never release the plugin since we'll keep the interface statically
		// in memory so we don't need to relocate it.  As we continue to use the code, we need to keep the plugin
		// in memory.
	}
	
	CFRelease(pluginURL);
	return(interface);
}