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
 *  Edward Peterlin, 2005
 *
 *  GNU General Public License Version 2.1
 *  =============================================
 *  Copyright 2005 by Edward Peterlin (OPENSTEP@neooffice.org)
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

///// constants ////

/**
 * Command used by popen() to construct a file handle extracting a given
 * file out of a zip archive
 */
#define kOpenSubfileCmd		"/usr/bin/unzip -p \"%s\" \"%s\""

/**
 * Path to the thumnail preview in OpenDocument formatted files
 */
#define kODThumbnailPath	"Thumbnails/thumbnail.png"

///// prototypes /////

static OSErr ExtractZipArchiveContent(CFStringRef pathToArchive, const char *fileToExtract, CFMutableDataRef fileContents);

///// functions /////

/**
 * Extract the thumbnail image from an OpenDocument text file into a CGImage
 */
extern "C" CGImageRef GetPreviewImageForOD(CFURLRef docURL)
{
	fprintf(stderr, "NeoPeek: GetPreviewImageForOD invoked\n");
	
	// check if the URL is a local file
	
	CFStringRef filePath=CFURLCopyPath(docURL);
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