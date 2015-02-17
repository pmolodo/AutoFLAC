This is the ReadMe file for AutoFLAC v1.2.  Additional details may be found on the
AutoFLAC home page: http://www.legroom.net/mysoft


|-------------------|
| EAC Configuration |
|-------------------|

Before attempting to use AutoFLAC, EAC must be configured as detailed below.  Any other EAC
options may be adjusted according to your preference, but the following settings are required.

EAC Options
 -> General
     -> Enable "On unknown CDs, automatically access online freedb database"
        Enable "Show status dialog after extraction"
        Disable "Beep after extraction finished"
        Disable "Eject CD after extraction finished"
 -> Tools
     -> Enable "Automatically write status report after extraction"
        Enable "On extraction, start external compressors queues in the background"
        Enable "Do not open external compressor window"
 -> Filename
     -> Set "Naming scheme" to: %I\%A\%C\%N-%T
        Enable "Use various artist naming scheme"
        Set various artist naming scheme to: %I\Various Artists\%C\%N-%A - %T
 -> Directories
     -> Set "Use this directory" and specify a permanent directory
        This directory must match the AutoFLAC "Output base" option 

Compression Options
 -> External Compression
     -> Enable "Use external program for compression"
	    Set "Parameter passing scheme" to: User Defined Encoder
        Set "Use file extension" to: .flac
        Set "Program used for compression" to the full path for flac.exe
        Set "Additional command line options to: --best -T "ARTIST=%a" -T "TITLE=%t" -T "ALBUM=%g" -T "DATE=%y" -T "TRACKNUMBER=%n" -T "GENRE=%m" %s
        Disable "Add ID3 tag"
freedb / Database Options
 -> freedb
     -> Set "Your E-Mail address" to an e-mail address


|---------------------------------|
| AutoFLAC Rip-mode Configuration |
|---------------------------------|

Each option in the AutoFLAC GUI will display tooltip help when the mouse cursor is placed over the option.

For reference, the following list explains all AutoFLAC Options.

Extract Options
 -> Individual Tracks - Only rip tracks currently selected in EAC
	All Tracks - Rip all tracks from the CD
     -> Rip to image - Rip album to single image file rather than individual tracks
    Create cue sheet - Create a CUE sheet for the CD, which can be used to burn a duplicate backup copy
     -> Embed in image - Embed cue sheet in album image rather than saving separately
        Delete ext cue - Delete the external cue sheet after embedding

Disc Options
 -> Write log file - Save EAC's ripping output to a logfile
	 -> Test and Copy - Rip using EAC's "Test and Copy" mode
    Copy data files - If the CD is a multi-session disc with a "data track",
                      copy all data files after ripping the CD
    Enable ReplayGain - Calculates and stores the Track and Album ReplayGain values
    Multi-disc set - If the CD is part of a multi-disc set, this option will instruct
                     AutoFlac to renumber/retag the ripped files to the format Nxx
                     where N is the Disc number and xx is the track number
     -> Disc _ of the set - Specifies the current disc number in a multi-disc set
        Indiv ReplayGain - Calculates ReplayGain for each album of a multi-disc set individually

AutoFLAC Rip Options
 -> Use Encoder - Specifies the encoder to be used by AutoFLAC
	USE CD-ROM Drive - Specifies the CD-ROM drive from which AutoFLAC will copy data
                       This option should match the drive used by EAC
    Low priority encoding - Set flac and metaflac to run with low system priority
    Eject on complete - Ejects the disc after ripping process is complete
    Notify on complete - Plays a WAVE file after ripping process is complete;
                         If this option is set, the next input box specifies
                         the WAVE file that should be played after ripping process is complete

Output Options
 -> Base directory - All tracks will be ripped to this root directory
                  in the format Base\Genre\Artist\Album\
                  This directory must match the EAC "Use this directory" option
	Name scheme - Directory naming scheme for ripped tracks;
                  This must match the naming scheme used by EAC
                  Click the ? button for detailed information
	Image scheme - Directory and file naming scheme for ripped images;
                   Click the ? button for detailed information

Binary Options
    Flac binary - Location of flac.exe
    Metaflac binary - Location of metaflac.exe


|-------------------------|
| AutoFLAC Rip-mode Usage |
|-------------------------|

Upon initially starting AutoFLAC, you may be prompted to provide the full path to EAC.exe.
This will only be asked if AutoFLAC cannot automatically locate an installed copy of EAC.
If you are prompted, please enter the full path and click OK to continue.  This path will
be remembered the next time you run AutoFLAC.

When AutoFLAC is started, it will first check for any existing instances of EAC.
If no running instances are found, it will start EAC automatically.

Once EAC is running, EAC will check to see if an audio CD is currently in the drive.
If no CD is currently loaded, it will prompt you to insert a CD.  Please do so and click OK.

After a CD has been recognized, the AutoFLAC GUI will be displayed.  The GUI will allow you
to set various ripping options.  Certain options will be preset by default on the first run,
but after that all options will be saved and restored when the next CD is ripped.  Help for
each option will be displayed if you hold the mouse cursor over the item.

Before continuing, be sure to verify that the CD Artist, Title, Genre, and year, and track
titles are correct as shown in EAC.  You'll also need to make sure that the "Output base"
directory in the AutoFLAC GUI is set to the same directory chosen for EAC's "Use this
directory" option.  All other options can be set at your discretion.

When you are ready to begin ripping, click OK.  AutoFLAC close the GUI and send the
appropriate commands to EAC to begin the ripping process.  After EAC completes ripping all
tracks, AutoFLAC will complete any additional tasks such as converting cue sheets,
calculating ReplayGain, copying data files, etc.

After all operations have been completed, AutoFLAC will notify you that extraction has
completed.  AutoFLAC will notify you if any errors were detected in the ripped tracks.  You
should review the log file for additional details if you wish to review and attempt to
manually repair the errors.

At this point, you may click Cancel to exit AutoFLAC, or click OK to repeat the process
and rip another CD.


|-----------------------------------|
| AutoFLAC Write-mode Configuration |
|-----------------------------------|

Each option in the AutoFLAC GUI will display tooltip help when the mouse cursor is placed over the option.

For reference, the following list explains all AutoFLAC Options.

CUE Sheet Selection - The CUE sheet for the album that AutoFLAC will burn;
                      This will be automatically filled in if a .cue file is passed to AutoFLAC.exe

Directory Options
 -> Use Album dir for temp files - Decompress files to Album directory when preparing for writing
    Specify temporary directory - Specify which directory to use for decompressed files

Binary Options
    Flac binary - Location of flac.exe


|---------------------------|
| AutoFLAC Write-mode Usage |
|---------------------------|

You can use AutoFLAC to write a previously ripped CD using one of three methods:
    Run 'autoflac.exe /write' from the command line.  You must then select the CUE sheet in the AutoFLAC GUI.
    Run 'autoflac.exe /write "Path\To\Cuesheet.cue"'.  This will automatically populate the CUE sheet field in the GUI.
    Drag-and-drop a cue sheet on AutoFLAC.exe.  This will automatically populate the CUE sheet field in the GUI.

After the cue sheet is selected, the AutoFLAC write-mode GUI will be displayed.
The CUE Sheet Selection field must contain the CUE sheet of the album that you
wish to burn.  All other options can be set to your discretion.

When you are ready to begin ripping, click OK.  AutoFLAC will begin converting all FLAC
files to WAV files.  All files will be saved to a temporary subdirectory of the CD folder.
During this process, the cue sheet will also be converted to reference the WAVE files.
A progress bar will be displayed to show the status of the conversion.

Once all files have been converted, the new cue sheet will be loaded into EAC's CD Layout Editor.
Verify that EAC did not display any error messages and that the Layout is correct, then click
CD-R, Write CD.

After the EAC has completed writing the CD, please close EAC.  AutoFLAC will delete the
temporary WAVE files, then exit.