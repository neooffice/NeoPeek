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
#include "common.h"
#include <CoreFoundation/CoreFoundation.h>
#include <Carbon/Carbon.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
	FSRef theRef;
	Boolean ignore;
	if(FSPathMakeRef((UInt8 *)argv[1], &theRef, &ignore)!=noErr)
	{
		fprintf(stderr, "You lose, hoser!\n");
		exit(1);
	}
	
	CFURLRef theURL=CFURLCreateFromFSRef(NULL, &theRef);
	
	CGImageRef testImage=GetPreviewImageForOD(theURL);
	if(testImage==NULL)
	{
		fprintf(stderr, "You lose again, hoser!\n");
		exit(1);
	}
	
	exit(0);
}