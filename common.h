/**
 * @file common.h
 *
 * Common function and class prototypes for the NeoPeek QuickView plugin.
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

#pragma once

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Query if the specified document contains a preview image.
 *
 * @param docURL	URL to document to query.
 * @return true if document contains a PNG preview image, false if not
 */
bool ODHasPreviewImage(CFURLRef docURL);

/**
 * Extract the thumbnail image from an OpenDocument file into a CGImage
 *
 * @param docURL	URL to document to generate preview.  Must be a local file.
 * @return CGImage with preview contents, or NULL on failure.  Ownership
 *	follows the Create rule.
 */
CGImageRef GetPreviewImageForOD(CFURLRef docURL);

/**
 * Query if the specified document contains a PDF preview data representation.
 *
 * @param docURL	URL of document to query
 * @return true if document contains a PDF preview image, false if not
 */
bool ODHasPreviewPDF(CFURLRef docURL);

/**
 * Extract the thumbnail PDF data from an OpenDocument file into a CFDataRef.
 *
 * @param docURL	URL of document to query.
 * @return PDF image, or NULL if document does not contain a valid PDF image.
 */
CFDataRef GetPreviewPDFForOD(CFURLRef docURL);

#ifdef __cplusplus
}
#endif
