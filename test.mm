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