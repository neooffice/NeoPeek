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

#pragma once

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <QuickLook/QuickLook.h>

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
CGImageRef CreatePreviewImageForOD(CFURLRef docURL);

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
CFDataRef CreatePreviewPDFForOD(CFURLRef docURL);

/**
 * Draw the first page of a PDF into a thumbnail CG context.
 *
 * @param docURL				URL of document to query
 * @param thumbRequest			request where teh thunbmail should be output
 * @param drawWhiteBackground	true to draw a white background, false to suppress
 * @return true if thumbnail was drawn, false if not
 */
bool DrawThumbnailPDFPageOneForOD(CFURLRef docURL, QLThumbnailRequestRef thumbRequest, bool drawWhiteBackground);

/**
 * Get a reference to the QuickLook plugin interface for the Apple Text.qlgenerator
 * plugin.
 *
 * @return interface handle, or NULL if the generator could not be loaded.
 */
QLGeneratorInterfaceStruct ** GetAppleTextQLGenerator(void);

#ifdef __cplusplus
}
#endif
