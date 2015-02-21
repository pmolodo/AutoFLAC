; ----------------------------------------------------------------------------
;
; AutoFLAC v1.2
; Author:	Jared Breland <jbreland@legroom.net>
; Homepage:	http://www.legroom.net/mysoft
; Language:	AutoIt v3.2.0.1
; License:	GNU General Public License (http://www.gnu.org/copyleft/gpl.html)
;
; Script Function:
;	Automate ripping and burning of flac files with EAC
;
; ----------------------------------------------------------------------------

; Setup environment
#include <GUIConstants.au3>
global $name = "AutoFLAC"
global $version = "1.2"
global $title = $name & ' ' & $version
global $eactitle = "Exact Audio Copy"
global $regprefs = "HKCU\Software\" & $name
global $write = 0
global $album, $artist, $performer, $year, $genre, $dbtype, $cdcomposer, $comment
global $cuefile, $warning, $tcwarning

; Extract options
global $extractmethod = 'all'
global $ripimage = 0
global $createcue = 1
global $embedcue = 0
global $deletecue = 0

; Disc options
global $createlog = 1
global $testandcopy = 0
global $copydata = 1
global $replaygain = 1
global $indiv_replaygain = 1
global $multidisc = 0
global $discnum = 1
;global $checksums = 0

; Rip options
global $outputenc = 'FLAC'
global $cdromdrive = "D:"
global $lowpriority = 0
global $ejectcomplete = 1
global $notifycomplete = 1
global $notifywav = "notify.wav"
global $skiprip = 0

; Write options
global $writetemptype = 'album'
global $writetempdir = @tempdir

; Program options
global $eac = regread("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\EAC.exe", "")
$eac = "c:\test.exe"
$regvalue = regread("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", "My Music")
if not @error then
	global $outputdir = $regvalue
else
	global $outputdir = @mydocumentsdir & "\Music"
endif
global $sepscheme = "%genre%\%albumartist%\%albumtitle%"
global $imgscheme = "%albumartist% - %albumtitle%"
global $flac = "flac.exe"
global $metaflac = "metaflac.exe"
;global $md5sum = "md5sum.exe"

; Validate EAC binary exists
ReadPrefs()
if NOT fileexists($eac) AND NOT SearchPath($eac) then SelectEAC()

; Check for command line arguments
if $cmdline[0] > 0 then
	$write = 1
	if $cmdline[1] = "/write" then
		if $cmdline[0] > 1 then
			$cuefile = $cmdline[2]
		endif
	else
		$cuefile = $cmdline[1]
	endif

	; Validate cue file
	if $cuefile <> '' then
		; Must be a cue file
		if stringtrimleft($cuefile, stringinstr($cuefile, '.', 0, -1)) <> "cue" then
			msgbox(64, $title, "Usage:" & @CRLF & @scriptname & " [/write [album.cue]]")
			exit
		endif

		; Qualify full path
		if stringmid($cuefile, 2, 1) <> ":" then
			if stringleft($cuefile, 1) == "\" then
				$cuefile = stringleft(@workingdir, 2) & $cuefile
			else
				$cuefile = @workingdir & "\" & $cuefile
			endif
		endif

		; make sure cue file exists
		if NOT fileexists($cuefile) then
			msgbox(64, $title, "Usage:" & @CRLF & @scriptname & " [/write [album.cue]]")
			exit
		endif
	endif
endif

; If /write passed, decompress tracks and load cue sheet for burning
if $write then

	; Set write options and set CUE sheet
	WriteSetup()

	; Setup paths and file names
	progresson($title, "Preparing files for writing", "Converting cue sheet", -1, -1, 16)
	$cuedir = stringleft($cuefile, stringinstr($cuefile, '\', 0, -1)-1)
	$cueext = stringtrimleft($cuefile, stringinstr($cuefile, '.', 0, -1))
	$cuename = stringtrimright(stringtrimleft($cuefile, stringlen($cuedir)+1), stringlen($cueext)+1)
	if $writetemptype == 'album' then
		$tempdir = $cuedir & "\" & $name
	else
		$tempdir = $writetempdir & "\" & $name
	endif
	dircreate($tempdir)
	$infile = fileopen($cuefile, 0)
	$outfile = fileopen($tempdir & "\" & $cuename & ".wav.cue", 2)

	; Create new cue file, save track filenames
	$i = 0
	dim $wavs[$i+1]
	while 1
		$line = filereadline($infile)
		if @error then exitloop
		if stringleft(stringstripws($line, 1), 5) = "FILE " then
			$wavs[$i] = stringmid($line, stringinstr($line, '"') + 1, stringinstr($line, '.', 0, -1) - stringinstr($line, '"')-1)
			$i = $i + 1
			redim $wavs[$i+1]
			$line = stringreplace($line, ".flac", ".wav", 0, 0)
		endif
		if stringinstr($line, "TRACK", 1) AND stringinstr($line, "MODE", 1) then
			exitloop
		endif
		filewriteline($outfile, $line)
	wend
	redim $wavs[$i]
	fileclose($outfile)
	fileclose($infile)

	; Verify checksums
	;$md5file = $cuename & '.md5'
	;if fileexists($cuedir & '\' & $md5file) then
	;	progressset(0, "Verifying MD5 checksums")
	;	runwait(@comspec & ' /c ' & filegetshortname($md5sum) & ' -c "' & $md5file & '" >"' & $tempdir & '\' & $cuename & '.md5.txt"', $cuedir, @SW_HIDE)
	;	$infile = fileopen($tempdir & "\" & $cuename & ".md5.txt", 0)
	;	$warning = ''
	;	$line = filereadline($infile)
	;	do
	;		if not stringinstr($line, ": OK", 1) then
	;			$warning &= stringleft($line, stringinstr($line, '-')-1) & ', '
	;		endif
	;		$line = filereadline($infile)
	;	until @error
	;	fileclose($infile)
	;	if $warning <> '' then
	;		$warning = stringtrimright($warning, 2)
	;		progressoff()
	;		$prompt = msgbox(49, $title, "Warning: The following tracks could not be verified:" & @CRLF & $warning & @CRLF & @CRLF & "Click OK to continue writing this CD, or Cancel to abort.")
	;		if $prompt <> 1 then exit
	;		progresson($title, "Preparing files for writing", "Verifying MD5 checksums", -1, -1, 16)
	;	endif
	;endif

	; Begin decompression
	;$debug = fileopen("c:\autoflac_write.txt", 2); debug
	;filewriteline($debug, "$cuedir = " & $cuedir); debug
	for $i = 0 to ubound($wavs) - 1
		progressset(round($i/ubound($wavs), 2)*100, "Converting " & $wavs[$i] & ".wav")
		;filewriteline($debug, $flac & ' -d -o "' & $tempdir & '\' & $wavs[$i] & '.wav" "' & $cuedir & '\' & $wavs[$i] & '.flac"'); debug
		runwait('"' & $flac & '" -d -o "' & $tempdir & '\' & $wavs[$i] & '.wav" "' & $cuedir & '\' & $wavs[$i] & '.flac"', $cuedir, @SW_HIDE)
	next
	;fileclose($debug); debug
	progressoff()
endif

; Run EAC
if $write then
	$pid = runwait('"' & $eac & '" "' & $tempdir & '\' & $cuename & '.wav.cue"')
	dirremove($tempdir, 1)
	exit
else
	if NOT processexists("eac.exe") then run($eac)
endif
if winwait($eactitle, '', 15) then
	winactivate($eactitle)
else
	msgbox(48, $title, "Error: EAC could not be started.")
	exit
endif

; Otherwise, begine extract process
$extract = 1
while $extract
	$extract = ExtractCD()
wend
exit

; main function to extract CD contents
func ExtractCD()

	; Prompt to insert disc if necessary
	winactivate($eactitle)
	$album = controlgettext($eactitle, '', 'myedit1')
	if $album == '' then
		$prompt = msgbox(49, $title, "Please insert the CD you'd like to extract and click OK.")
		if $prompt <> 1 then exit
		while $album == ''
			$album = controlgettext($eactitle, '', 'myedit1')
		wend
	endif

	; If unknown disc is loaded, query FreeDB and prompt to edit
	;winactivate($eactitle)
	;if stringinstr($album, "Unknown") then
	;	send("!g")
	;	if winwait("Warning", "All data of the current CD", 1) then
	;		winactivate("Warning", "All data of the current CD")
	;		send("!y")
	;	endif
	;	sleep(500)
	;	while 1
	;		if winexists("Transfer", "CD Identification") then
	;			continueloop
	;		elseif winexists("Select CD", "Several exact matches") then
	;			continueloop
	;		else
	;			exitloop
	;		endif
	;	wend
	;endif

	; Prompt for CD info edit
	ExtractSetup()
	;$debug = fileopen("c:\autoflac_rip.txt", 2) ;debug
	winactivate($eactitle)

	; Get CD info
	$album = SanitizeChars(controlgettext($eactitle, '', 'myedit2'))
	$artist = SanitizeChars(controlgettext($eactitle, '', 'myedit3'))
	;if $artist == "Various" then $artist = "Various Artists"
	$performer = SanitizeChars(controlgettext($eactitle, '', 'myedit4'))
	$year = SanitizeChars(controlgettext($eactitle, '', 'myedit5'))
	$genre = SanitizeChars(controlgettext($eactitle, '', 'Edit1'))
	$dbtype = SanitizeChars(controlgettext($eactitle, '', 'mycombo2'))
	$cdcomposer = SanitizeChars(controlgettext($eactitle, '', 'myedit6'))
	$comment = SanitizeChars(controlgettext($eactitle, '', 'myedit7'))
	if $multidisc then
		$metapre = $discnum & "00-"
		$metapost = " (Disc " & $discnum & ')'
	else
		$metapre = "00-"
		$metapost = ""
	endif

	; Setup output naming scheme
	;$ripdir = $outputdir & "\" & $genre & "\" & $artist & "\" & $album
	$ripdir = $outputdir
	if $ripimage then
		if stringinstr($imgscheme, '\') then
			$ripdir &= '\' & stringleft($imgscheme, stringinstr($imgscheme, '\', 0, -1)-1)
			$imgname = stringtrimleft($imgscheme, stringinstr($imgscheme, '\', 0, -1))
		else
			$imgname = $imgscheme
		endif
		$imgname = VarNameReplace($imgname)
	else
		$ripdir &= '\' & $sepscheme
	endif
	if stringright($ripdir, 1) == '\' then $ripdir = stringtrimright($ripdir, 1)
	$ripdir = VarNameReplace($ripdir)
	;filewriteline($debug, "$ripdir = " & $ripdir) ;debug
	;filewriteline($debug, "$metapre = " & $metapre) ;debug

   if NOT $skiprip then
	   ; Select all tracks
	   if $extractmethod == "all" then send("^a")

	   ; Rip complete image if selected
	   if $ripimage then
		   send("!aic")
		   winwait("Save Waveform")
		   send('!n' & $outputdir & '\' & $artist & ' - ' & $album & ' (AutoFLAC)' & '!s')
		   winwait("Analyzing", "", 10)
		   while winexists("Analyzing")
			   sleep(500)
		   wend
		   winactivate($eactitle)

	   ; Otherwise rip to individual tracks
	   else
		   if $createcue then
			   send("!as{DOWN 2}{ENTER}")
			   winwait("Analyzing", "", 10)
			   while winexists("Analyzing")
				   sleep(500)
			   wend
			   winactivate($eactitle)
		   endif

		   ; Rip tracks
		   opt("WinTitleMatchMode", 2)
		   if $testandcopy then
			   send("+{F6}")
		   else
			   send("+{F5}")
		   endif
	   endif

	   ; Wait for ripping to complete
	   local $extractWin = winwait("Extracting Audio Data", "", 5)
	   if NOT $extractWin then
		   msgbox(48, $title, "Error: Audio extraction not started")
		   exit
	   endif
	   if $ripimage then
		   local $button = 2
		   dircreate($ripdir)
	   else
		   local $button = 3
	   endif

	   ; For some reason, this loop seems to sometimes exit even though ripping not finished
	   ; yet - usually seems to be after the first track finishes...?
	   while controlgettext($extractWin, '', 'Button' & $button) == "Cancel"
		   if $lowpriority then
			   if processexists("flac.exe") then processsetpriority("flac.exe", 0)
		   endif
		   sleep(500)
	   wend

	   ; Check status for erros
	   controlclick($extractWin, '', 'Button' & $button)
	   sleep(200)
	   winactivate("Status and Error Messages")
	   sleep(200)
	   dim $i, $track, $past
	   while 1
		   controlcommand("Status and Error Messages", '', 'ListBox1', 'SetCurrentSelection', $i)
		   if @error then exitloop
		   $line = controlcommand("Status and Error Messages", '', 'ListBox1', 'GetCurrentSelection')
		   if stringleft($line, 5) == "Track" then
			   $track = stringtrimleft($line, stringinstr($line, " ", 0, -1))
		   endif
		   if stringinstr($line, "Suspicious") then
			   if $track <> $past then
				   $warning &= $track & ", "
				   $past = $track
			   endif
		   endif
		   $i = $i + 1
	   wend
	   controlclick("Status and Error Messages", '', 'Button1')
	   winactivate($eactitle)

	   ; Update cue sheet for compressed tracks
	   if $createcue then
		   if $ripimage then
			   $old = fileopen($outputdir & "\" & $artist & " - " & $album & " (AutoFLAC).cue", 0)
			   $new = fileopen($ripdir & "\" & $imgname & $metapost & ".cue", 2)
		   else
			   $old = fileopen($outputdir & "\" & $album & ".cue", 0)
			   $new = fileopen($ripdir & "\" & $metapre & $album & ".cue", 2)
		   endif
		   $line = filereadline($old)
		   do
			   if stringleft($line, 5) == "TITLE" then
				   $line = 'TITLE "' & $album & $metapost & '"'
			   elseif stringinstr($line, "FILE ", 1) AND NOT $ripimage then
				   $temp = stringtrimleft($line, stringinstr($line, '\', 0, -1))
				   $tracknum = stringleft($temp, stringinstr($temp, '-')-1)
				   $temp = stringleft($temp, stringinstr($temp, '.', 0, -1)-1)
				   $trackname = stringtrimleft($temp, stringlen($tracknum)+1)
				   if $multidisc then $tracknum = $discnum & $tracknum
				   $line = 'FILE "' & $tracknum & '-' & $trackname & '.flac" WAVE'
			   elseif stringinstr($line, "FILE ", 1) AND $ripimage then
				   $line = 'FILE "' & $imgname & $metapost & '.flac" WAVE'
			   endif
			   filewriteline($new, $line)
			   $line = filereadline($old)
		   until @error
		   fileclose($new)
		   fileclose($old)
		   if $ripimage then
			   filerecycle($outputdir & "\" & $artist & " - " & $album & " (AutoFLAC).cue")
		   else
			   filerecycle($outputdir & "\" & $album & ".cue")
		   endif
	   endif

	   ; Process log file
	   if $createlog then
		   if $ripimage then
			   filemove($outputdir & "\" & $album & ".log", $ripdir & "\" & $imgname & $metapost & ".log", 1)
		   else
			   filemove($outputdir & "\" & $album & ".log", $ripdir & "\" & $metapre & $album & $metapost & ".log", 1)

			   ; Check for Test and Copy errors
			   if $testandcopy then
				   dim $track, $testcrc, $copycrc
				   $infile = fileopen($ripdir & '\' & $metapre & $album & $metapost & '.log', 0)
				   $line = filereadline($infile)
				   do
					   ; Compare Test and Copy CRCs; flag if mismatch found
					   if stringleft($line, 5) = "Track" then
						   $track = stringtrimleft($line, stringinstr($line, ' ', 0, -1))
					   endif
					   if stringinstr($line, "Test CRC") then
						   $testcrc = stringtrimleft($line, stringinstr($line, ' ', 0, -1))
					   endif
					   if stringinstr($line, "Copy CRC") then
						   $copycrc = stringtrimleft($line, stringinstr($line, ' ', 0, -1))
						   if $copycrc <> $testcrc then $tcwarning &= $track & ", "
						   dim $track, $testcrc, $copycrc
					   endif
					   $line = filereadline($infile)
				   until @error
				   fileclose($infile)
			   endif
		   endif
	   else
		   filerecycle($outputdir & "\" & $album & ".log")
	   endif

	   ; Wait for track compression to complete
	   while processexists("flac.exe")
		   sleep(1000)
		   if processexists("flac.exe") then
			   if $lowpriority then processsetpriority("flac.exe", 0)
		   else
			   sleep(4000)
		   endif
		wend
   endif

	; Move image to correct directory, fix tags, and import cuesheet
	if $ripimage then
		filemove($outputdir & '\' & $artist & ' - ' & $album & ' (AutoFLAC).wav.flac', $ripdir & '\' & $imgname & $metapost & '.flac')
		runwait('"' & $metaflac & '" --remove-tag=TITLE --remove-tag=TRACKNUMBER "' & $ripdir & '\' & $imgname & $metapost & '.flac"', $ripdir, @SW_HIDE)
		if $multidisc then
			runwait('"' & $metaflac & '" --set-tag="DISCNUMBER=' & $discnum & '" "' & $ripdir & '\' & $imgname & $metapost & '.flac"', $ripdir, @SW_HIDE)
		endif
		if $embedcue then
			$infile = fileopen($ripdir & '\' & $imgname & $metapost & '.cue', 0)
			$tag = '"CUESHEET='
			$line = filereadline($infile)
			do
				if stringleft($line, 4) <> "REM " then
					$line = stringreplace($line, '"', "'")
					if stringleft($line, 5) = "FILE " then
						$line = "FILE 'DUMMY' WAVE"
					endif
					$tag &= $line & @CRLF
				endif
				$line = filereadline($infile)
			until @error
			fileclose($infile)
			$tag = stringtrimright($tag, 2) & $line & '"'
			runwait('"' & $metaflac & '" --set-tag=' & $tag & ' "' & $ripdir & '\' & $imgname & $metapost & '.flac"', $ripdir, @SW_HIDE)
			runwait('"' & $metaflac & '" --import-cuesheet-from="' & $ripdir & '\' & $imgname & $metapost & '.cue" "' & $ripdir & '\' & $imgname & $metapost & '.flac"', $ripdir, @SW_HIDE)
			if $deletecue then
				filerecycle($ripdir & '\' & $imgname & $metapost & '.cue')
			endif
		endif
	endif

	; Update tracknumbers
	if $multidisc AND NOT $ripimage then
		$files = filefindfirstfile($ripdir & "\*.flac")
		$file = filefindnextfile($files)
		do
			if stringlen(stringleft($file, stringinstr($file, '-')-1)) == 2 then
				$tracknum = stringleft($file, stringinstr($file, "-")-1)
				runwait('"' & $metaflac & '" --remove-first-tag=TRACKNUMBER --set-tag=TRACKNUMBER=' & $discnum & $tracknum & ' --set-tag=DISCNUMBER=' & $discnum & ' "' & $ripdir & '\' & $file & '"', $ripdir, @SW_HIDE)
				filemove($ripdir & '\' & $file, $ripdir & '\' & $discnum & $file, 1)
			endif
			$file = filefindnextfile($files)
		until @error
		fileclose($files)
	endif

	; Add ReplayGain data
	if $replaygain then
		$files = filefindfirstfile($ripdir & "\*.flac")
		$file = filefindnextfile($files)
		$list = ''
		do
			if NOT ($multidisc AND $indiv_replaygain) OR (stringisint(stringleft($file, 3)) AND stringleft($file, 1) == $discnum) then
				$list &= '"' & $file & '" '
			endif
			$file = filefindnextfile($files)
		until @error
		fileclose($files)
		;filewriteline($debug, "$ripdir = " & $ripdir) ;debug
		;filewriteline('"' & $metaflac & '" --add-replay-gain ' & $list) ;debug
		;fileclose($debug) ;debug
		$pid = run('"' & $metaflac & '" --add-replay-gain ' & $list, $ripdir, @SW_HIDE)
		if $lowpriority then processsetpriority($pid, 0)
	endif

	; Add MD5 checksums
	;if $checksums then
	;	if $replaygain then processwaitclose('metaflac.exe')
	;	runwait(@comspec & ' /c ' & filegetshortname($md5sum) & ' -b *.flac >"' & $metapre & $album & '.md5"', $ripdir, @SW_HIDE)
	;endif

	; Copy data
	if $copydata then
		local $datatrack = 0
		; first check - EAC track list
		$items = controllistview($eactitle, '', 'SysListView321', "GetItemCount")
		$firsttrack = controllistview($eactitle, '', 'SysListView321', "GetText", 0, 0)
		if stringleft($firsttrack, 4) = "DATA" then $datatrack = 1
		$lasttrack = controllistview($eactitle, '', 'SysListView321', "GetText", $items - 1, 0)
		if stringleft($lasttrack, 4) = "DATA" then $datatrack = 1
		; second check - CUE sheet
		if $ripimage then
			$infile = fileopen($ripdir & "\" & $imgname & $metapost & ".cue", 0)
		else
			$infile = fileopen($ripdir & "\" & $metapre & $album & ".cue", 0)
		endif
		$line = filereadline($infile)
		do
			if stringinstr($line, "TRACK", 1) AND stringinstr($line, "MODE", 1) then $datatrack = 1
			$line = filereadline($infile)
		until @error
		fileclose($infile)
		; Copy data if available
		if $datatrack then
			$copyfailed = 0
			processclose("eac.exe")
			cdtray($cdromdrive, "open")
			sleep(1000)
			cdtray($cdromdrive, "closed")
			sleep(1000)
			dircreate($ripdir & "\Data" & $metapost)
			dircopy($cdromdrive, $ripdir & "\Data" & $metapost, 1)
			if dirgetsize($cdromdrive) <> dirgetsize($ripdir & "\Data" & $metapost) then $copyfailed = 1
			run($eac)
			winwait($eactitle)
			if $copyfailed then
				msgbox(48, $title, "Error: Not all data files were copied." & @CRLF & "One or more files could not be read from the CD.")
			endif
		endif
	endif

	; Notify that extraction is complete
	if $replaygain then processwaitclose('metaflac.exe')
	if $notifycomplete then
		if fileexists($notifywav) then
			soundplay($notifywav)
		else
			soundplay(@windowsdir & "\media\" & $notifywav)
		endif
	endif

	; Eject the disc
	if $ejectcomplete then
		cdtray($cdromdrive, "open")
	endif

	; Prompt to extract next CD
	if $warning OR $tcwarning then
		dim $message
		if $warning then
			$warning = stringtrimright($warning, 2)
			$message = "EAC detected possible errors in track(s): " & $warning & @CRLF & @CRLF
		endif
		if $tcwarning then
			$tcwarning = stringtrimright($tcwarning, 2)
			$message &= "Test and Copy CRCs revealed possible errors in track(s): " & $tcwarning & @CRLF & @CRLF
		endif
		$tcwarning = stringtrimright($tcwarning, 2)
		$prompt = msgbox(49, $title, $message & "Click OK to extract another CD, or Cancel to manually validate and repair the errors.")
	else
		$prompt = msgbox(33, $title, "Extraction complete with 0 detected errors." & @CRLF & @CRLF & "Would you like to extract another CD?")
	endif
	if $prompt <> 1 then
		; processclose("eac.exe")
		return 0
	else
		return 1
	endif
endfunc

; Function to display write options prompt
func WriteSetup()
	; Create GUI
	ReadPrefs()
	GUICreate($title, 355, 175)

	; AutoFLAC Write options
	; CUE sheet selection
	GUICtrlCreateGroup("CUE Sheet Selection", 5, 5, 345, 45)
	local $cuesheet = GUICtrlCreateInput($cuefile, 10, 25, 305, 20)
	GUICtrlSetTip(-1, "The CUE sheet for the album that " & $name & " will burn")
	local $cuebut = GUICtrlCreateButton("...", 320, 25, 25, 20)

	; Directory Options
	GUICtrlCreateGroup("Directory Options", 5, 55, 160, 85)
	local $tempalbum = GUICtrlCreateRadio("Use &Album dir for temp files", 10, 75, -1, 20)
	GUICtrlSetTip(-1, "Decompress files to Album dirwhen preparing for writing")
	local $tempspec = GUICtrlCreateRadio("Specify &temporary directory", 10, 95, -1, 20)
	GUICtrlSetTip(-1, "Specify which directory to use for decompressed files")
	local $tempdir = GUICtrlCreateInput($writetempdir, 30, 115, 100, 20)
	GUICtrlSetTip(-1, "Specify which directory to use for decompressed files")
	local $tempbut = GUICtrlCreateButton("...", 135, 115, 25, 20)
	GUICtrlSetTip(-1, "The directory to use for decompressed files")
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; Binary Options
	GUICtrlCreateGroup("Binary Options", 170, 55, 180, 45)
	GUICtrlCreateLabel("&Flac:", 175, 77, 25, 15, $SS_RIGHT)
	local $flacbin = GUICtrlCreateInput($flac, 205, 75, 110, 20)
	GUICtrlSetTip(-1, "Location of flac.exe")
	local $flacbut = GUICtrlCreateButton("...", 320, 75, 25, 20)

	; Buttons
	local $ok = GUICtrlCreateButton("&OK", 85, 150, 80, 20)
	local $cancel = GUICtrlCreateButton("Cancel", 190, 150, 80, 20)

	; Set properties
	if $writetemptype = 'specify' then
		GUICtrlSetState($tempspec, $GUI_CHECKED)
	else
		GUICtrlSetState($tempalbum, $GUI_CHECKED)
		GUICtrlSetState($tempdir, $GUI_DISABLE)
		GUICtrlSetState($tempbut, $GUI_DISABLE)
	endif
	GUICtrlSetState($ok, $GUI_DEFBUTTON)

	; Display GUI and wait for action
	GUISetState(@SW_SHOW)
	while 1
		$action = GUIGetMsg()
		select

			; Enable tempdir field if specify directory option selected
			case $action == $tempspec
				GUICtrlSetState($tempdir, $GUI_ENABLE)
				GUICtrlSetState($tempbut, $GUI_ENABLE)
			case $action == $tempalbum
				GUICtrlSetState($tempdir, $GUI_DISABLE)
				GUICtrlSetState($tempbut, $GUI_DISABLE)

			; Process flac binary selection
			case $action == $cuebut
				$file = fileopendialog("Select cuesheet", "", "CUE file (*.cue)", 1)
				if not @error then GUICtrlSetData($cuesheet, $file)
				GUICtrlSetState($cuesheet, $GUI_FOCUS)

			; Process tempdir selection
			case $action == $tempbut
				$dir = fileselectfolder("Select directory", "", 7, GUICtrlRead($basedir))
				if not @error then GUICtrlSetData($tempdir, $dir)
				GUICtrlSetState($tempdir, $GUI_FOCUS)

			; Process flac binary selection
			case $action == $flacbut
				$file = fileopendialog("Select file", "", "EXE file (*.exe)", 1)
				if not @error then GUICtrlSetData($flacbin, $file)
				GUICtrlSetState($flacbin, $GUI_FOCUS)

			; Begin processing options
			case $action == $ok

				; Validate cuesheet extension
				if NOT fileexists(GUICtrlRead($cuesheet)) OR stringright(GUICtrlRead($cuesheet), 3) <> "cue" then
					msgbox(48, $title, "Error: You must select a valid CUE sheet to write.")
					GUICtrlSetState($cuesheet, $GUI_FOCUS)
					continueloop
				else
					$cuefile = GUICtrlRead($cuesheet)
				endif

				; Validate tempdir
				if NOT fileexists(GUICtrlRead($tempdir)) then
					msgbox(48, $title, "Error: You must select a valid temporary directory for writing.")
					GUICtrlSetState($tempdir, $GUI_FOCUS)
					continueloop
				endif

				; Validate flac binary
				if NOT fileexists(GUICtrlRead($flacbin)) AND NOT SearchPath(GUICtrlRead($flacbin)) then
					msgbox(48, $title, "Error: You must select the flac binary to use for decoding.")
					GUICtrlSetState($flacbin, $GUI_FOCUS)
					continueloop
				endif

				; Update global variables
				if GUICtrlRead($tempalbum) == $GUI_CHECKED then
					$writetemptype = 'album'
				elseif GUICtrlRead($tempspec) == $GUI_CHECKED then
					$writetemptype = 'specify'
					$writetempdir = GUICtrlRead($tempdir)
				endif
				$flac = GUICtrlRead($flacbin)

				; Save preferences and begin extraction
				SavePrefs()
				GUIDelete()
				return

			; Exit if Cancel clicked or window closed
			case $action == $GUI_EVENT_CLOSE OR $action == $cancel
				exit
		endselect
	wend
endfunc

; Function to display extraction method prompt
func ExtractSetup()
	local $options = "You may use the following parameters to customize your output directory and filename."
	$options &= @CRLF & "Anything not included in the following list of options will be treated as static text."
	$options &= @CRLF
	$options &= @CRLF & "%albumtitle%" & @TAB & "Album Title"
	$options &= @CRLF & "%albumartist%" & @TAB & "Album Artist"
	$options &= @CRLF & "%albuminterpret%" & @TAB & "Album Performer"
	$options &= @CRLF & "%year%" & @TAB & @TAB & "Album Year"
	$options &= @CRLF & "%genre%" & @TAB & @TAB & "Album Genre"
	$options &= @CRLF & "%cddbtype%" & @TAB & "FreeDB Category"
	$options &= @CRLF & "%albumcomposer%" & @TAB & "Album Composer"
	$options &= @CRLF & "%comment%" & @TAB & "Comment"

	; Create GUI
	ReadPrefs()
	GUICreate($title, 445, 370)
	GUICtrlCreateLabel("Please make any changes you would like to the CD information before continuing.", 5, 5, -1, 20)
	GUICtrlCreateLabel("If you would like to extract individual tracks rather than the entire album,", 5, 20, -1, 20)
	GUICtrlCreateLabel("select each individual track in EAC, then select ""Individual Tracks"" below.", 5, 35, -1, 20)
	GUICtrlCreateLabel("Click OK when you are ready to begin extraction.", 5, 55, -1, 20)

	; Extract options
	GUICtrlCreateGroup("Extract Options", 5, 80, 125, 145)
	local $sel = GUICtrlCreateRadio("&Individual Tracks", 10, 100, -1, 20)
	GUICtrlSetTip(-1, "Only rip tracks currently selected in EAC")
	local $all = GUICtrlCreateRadio("&All Tracks", 10, 120, -1, 20)
	GUICtrlSetTip(-1, "Rip all tracks from the CD")
	local $image = GUICtrlCreateCheckBox("Rip to &image", 30, 140, -1, 20)
	GUICtrlSetTip(-1, "Rip album to single image file rather than individual tracks")
	local $cue = GUICtrlCreateCheckBox("Create &cue sheet", 10, 160, -1, 20)
	GUICtrlSetTip(-1, "Create a CUE sheet for the CD, which can be used to burn a duplicate backup copy")
	local $store = GUICtrlCreateCheckBox("&Embed in image", 30, 180, 95, 20)
	GUICtrlSetTip(-1, "Embed cue sheet in album image rather than saving separately")
	local $delcue = GUICtrlCreateCheckBox("Delete e&xt cue", 30, 200, -1, 20)
	GUICtrlSetTip(-1, "Delete the external cue sheet after embedding")
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; Disc options
	GUICtrlCreateGroup("Disc Options", 145, 80, 130, 165)
	local $log = GUICtrlCreateCheckBox("Write &log file", 150, 100, -1, 20)
	GUICtrlSetTip(-1, "Save EAC's ripping output to a logfile")
	local $test = GUICtrlCreateCheckBox("T&est and Copy", 170, 120, -1, 20)
	GUICtrlSetTip(-1, "Rip using EAC's ""Test and Copy"" mode")
	local $data = GUICtrlCreateCheckBox("Copy &data files", 150, 140, -1, 20)
	GUICtrlSetTip(-1, "If the CD is a multi-session disc with a ""data track""," & @CRLF & "copy all data files after ripping the CD")
	local $gain = GUICtrlCreateCheckBox("Enable &ReplayGain", 150, 160, -1, 20)
	GUICtrlSetTip(-1, "Calculates and stores the Track and Album ReplayGain values")
	local $multi = GUICtrlCreateCheckBox("&Multi-disc set", 150, 180, -1, 20)
	GUICtrlSetTip(-1, "If the CD is part of a multi-disc set, this option will instruct" & @CRLF & $name & " to renumber/retag the ripped files to the format Nxx" & @CRLF & "where N is the Disc number and xx is the track number")
	GUICtrlCreateLabel("Disc", 170, 202, -1, 15)
	local $disc = GUICtrlCreateInput("", 195, 200, 15, 20)
	GUICtrlSetTip(-1, "Specifies the current disc number in a multi-disc set")
	GUICtrlCreateLabel("of the set", 215, 202, -1, 15)
	local $indiv = GUICtrlCreateCheckBox("Indiv Replay&Gain", 170, 220, 103, 20)
	GUICtrlSetTip(-1, "Calculates ReplayGain for each album of a multi-disc set individually")
	;local $verify = GUICtrlCreateCheckBox("Write c&hecksums", 280, 100, 110, 20)
	;GUICtrlSetTip(-1, "Calculates and stores the MD5 checksums for each track;" & @CRLF & "Can be used to verify track integrity before creating backup copy")
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; Rip options
	GUICtrlCreateGroup($name & " Rip Options", 290, 80, 150, 165)
	GUICtrlCreateLabel("Use Encoder: ", 295, 101, -1, 15)
	local $enc = GUICtrlCreateCombo("", 365, 97, 70, 20, $CBS_DROPDOWNLIST)
	GUICtrlSetTip(-1, "Specifies the encoder to be used by AutoFLAC")
	GUICtrlCreateLabel("Use CD-ROM drive:", 295, 123, -1, 15)
	local $cdrom = GUICtrlCreateCombo("", 400, 119, 35, 20, $CBS_DROPDOWNLIST)
	GUICtrlSetTip(-1, "Specifies the CD-ROM drive from which " & $name & "will copy data;" & @CRLF & "This option should match the drive used by EAC")
	local $priority = GUICtrlCreateCheckBox("Low &priority encoding", 295, 140, -1, 20)
	GUICtrlSetTip(-1, "Set flac and metaflac to run with low system priority")
	local $eject = GUICtrlCreateCheckBox("E&ject on complete", 295, 160, -1, 20)
	GUICtrlSetTip(-1, "Ejects the disc after ripping process is complete")
	local $notify = GUICtrlCreateCheckBox("&Notify on complete", 295, 180, -1, 20)
	GUICtrlSetTip(-1, "Plays a WAVE file after ripping process is complete")
	local $wave = GUICtrlCreateInput($notifywav, 315, 200, 90, 20)
	GUICtrlSetTip(-1, "The WAVE file that should be played after ripping process is complete")
	local $wavebut = GUICtrlCreateButton("...", 410, 200, 25, 20)
	local $skipbut = GUICtrlCreateCheckBox("S&kip ripping", 295, 220, -1, 20)
	GUICtrlSetTip(-1, "Check this if you wish to disable/skip the actual ripping, and only run AutoFLAC's extra processing." & @CRLF & "Handy if you've already ripped a cd 'normally'")
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; Output Options
	GUICtrlCreateGroup("Output Options", 5, 250, 230, 85)
	GUICtrlCreateLabel("&Base directory:", 10, 272, 75, 15, $SS_RIGHT)
	local $basedir = GUICtrlCreateInput($outputdir, 90, 270, 110, 20)
	GUICtrlSetTip(-1, "All tracks will be ripped to this root directory" & @CRLF & "in the format Base\Genre\Artist\Album\")
	local $basebut = GUICtrlCreateButton("...", 205, 270, 25, 20)
	GUICtrlCreateLabel("Name &scheme:", 10, 292, 75, 15, $SS_RIGHT)
	local $sepschemefield = GUICtrlCreateInput($sepscheme, 90, 290, 110, 20)
	GUICtrlSetTip(-1, "Directory naming scheme for ripped tracks;" & @CRLF & "This must match the naming scheme used by EAC")
	local $sepschemebut = GUICtrlCreateButton("?", 205, 290, 25, 20)
	GUICtrlCreateLabel("Image sc&heme:", 10, 312, 75, 15, $SS_RIGHT)
	local $imgschemefield = GUICtrlCreateInput($imgscheme, 90, 310, 110, 20)
	GUICtrlSetTip(-1, "Directory and file naming scheme for ripped images")
	local $imgschemebut = GUICtrlCreateButton("?", 205, 310, 25, 20)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; Binary Options
	GUICtrlCreateGroup("Binary Options", 240, 250, 200, 65)
	GUICtrlCreateLabel("&Flac:", 245, 272, 45, 15, $SS_RIGHT)
	local $flacbin = GUICtrlCreateInput($flac, 295, 270, 110, 20)
	GUICtrlSetTip(-1, "Location of flac.exe")
	local $flacbut = GUICtrlCreateButton("...", 410, 270, 25, 20)
	GUICtrlCreateLabel("Me&taflac:", 245, 292, 45, 15, $SS_RIGHT)
	local $metaflacbin = GUICtrlCreateInput($metaflac, 295, 290, 110, 20)
	GUICtrlSetTip(-1, "Location of metaflac.exe")
	local $metaflacbut = GUICtrlCreateButton("...", 410, 290, 25, 20)
	;GUICtrlCreateLabel("MD5sum binary:", 10, 292, 80, 15, $SS_RIGHT)
	;local $md5bin = GUICtrlCreateInput($md5sum, 95, 290, 100, 20)
	;GUICtrlSetTip(-1, "Location of md5sum.exe")
	;local $md5but = GUICtrlCreateButton("...", 200, 290, 25, 20)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; Buttons
	local $ok = GUICtrlCreateButton("&OK", 130, 345, 80, 20)
	local $cancel = GUICtrlCreateButton("Cancel", 235, 345, 80, 20)

	; Set properties
	if $extractmethod == 'all' then
		GUICtrlSetState($all, $GUI_CHECKED)
	elseif $extractmethod == 'sel' then
		GUICtrlSetState($sel, $GUI_CHECKED)
		GUICtrlSetState($image, $GUI_DISABLE)
		GUICtrlSetState($cue, $GUI_DISABLE)
		GUICtrlSetState($store, $GUI_DISABLE)
		GUICtrlSetState($delcue, $GUI_DISABLE)
	endif
	if $ripimage then
		GUICtrlSetState($image, $GUI_CHECKED)
	else
		GUICtrlSetState($store, $GUI_DISABLE)
		GUICtrlSetState($delcue, $GUI_DISABLE)
	endif
	if $createcue then
		GUICtrlSetState($cue, $GUI_CHECKED)
	else
		GUICtrlSetState($store, $GUI_DISABLE)
		GUICtrlSetState($delcue, $GUI_DISABLE)
	endif
	if $embedcue then
		GUICtrlSetState($store, $GUI_CHECKED)
		if $deletecue then GUICtrlSetState($delcue, $GUI_CHECKED)
	else
		GUICtrlSetState($delcue, $GUI_DISABLE)
	endif
	GUICtrlSetData($enc, 'FLAC', $outputenc)
	if $createlog then
		GUICtrlSetState($log, $GUI_CHECKED)
		GUICtrlSetState($test, $GUI_ENABLE)
	else
		GUICtrlSetState($log, $GUI_UNCHECKED)
		GUICtrlSetState($test, $GUI_DISABLE)
	endif
	if $testandcopy then GUICtrlSetState($test, $GUI_CHECKED)
	if $replaygain then GUICtrlSetState($gain, $GUI_CHECKED)
	if $copydata then GUICtrlSetState($data, $GUI_CHECKED)
	if $multidisc then
		GUICtrlSetState($multi, $GUI_CHECKED)
		GUICtrlSetData($disc, $discnum)
	else
		GUICtrlSetState($disc, $GUI_DISABLE)
		GUICtrlSetState($indiv, $GUI_DISABLE)
	endif
	if $indiv_replaygain then GUICtrlSetState($indiv, $GUI_CHECKED)
	;if $checksums then GUICtrlSetState($verify, $GUI_CHECKED)
	if stringinstr(GetCDROMs(), $cdromdrive, 0) then
		GUICtrlSetData($cdrom, GetCDROMs(), $cdromdrive)
	else
		GUICtrlSetData($cdrom, GetCDROMs(), stringleft(GetCDROMs(), stringinstr(GetCDROMs(), '|')-1))
	endif
	if $lowpriority then GUICtrlSetState($priority, $GUI_CHECKED)
	if $ejectcomplete then GUICtrlSetState($eject, $GUI_CHECKED)
	if $notifycomplete then
		GUICtrlSetState($notify, $GUI_CHECKED)
	else
		GUICtrlSetState($wave, $GUI_DISABLE)
		GUICtrlSetState($wavebut, $GUI_DISABLE)
	endif
	if $skiprip then
		GUICtrlSetState($skipbut, $GUI_CHECKED)
	endif
	GUICtrlSetState($ok, $GUI_DEFBUTTON)

	; Display GUI and wait for action
	GUISetState(@SW_SHOW)
	while 1
		$action = GUIGetMsg()
		select
			; Enable/Disable cue sheet creation depending on track selection
			case $action == $all
				GUICtrlSetState($image, $GUI_ENABLE)
				GUICtrlSetState($cue, $GUI_ENABLE)
				GUICtrlSetState($cue, $GUI_CHECKED)
				if GUICtrlRead($cue) == $GUI_CHECKED AND GUICtrlRead($image) == $GUI_CHECKED then
					GUICtrlSetState($store, $GUI_ENABLE)
					if GUICtrlRead($store) == $GUI_CHECKED then GUICtrlSetState($delcue, $GUI_ENABLE)
				endif
			case $action == $sel
				GUICtrlSetState($image, $GUI_DISABLE)
				GUICtrlSetState($cue, $GUI_UNCHECKED)
				GUICtrlSetState($cue, $GUI_DISABLE)
				GUICtrlSetState($store, $GUI_DISABLE)
				GUICtrlSetState($delcue, $GUI_DISABLE)

			; Enable/Disable embedded cue options
			case $action == $cue OR $action == $image OR $action == $store
				if GUICtrlRead($cue) == $GUI_CHECKED AND GUICtrlRead($image) == $GUI_CHECKED then
					GUICtrlSetState($store, $GUI_ENABLE)
					if GUICtrlRead($store) == $GUI_CHECKED then
						GUICtrlSetState($delcue, $GUI_ENABLE)
					else
						GUICtrlSetState($delcue, $GUI_DISABLE)
					endif
				else
					GUICtrlSetState($store, $GUI_DISABLE)
					GUICtrlSetState($delcue, $GUI_DISABLE)
				endif

			; Enable Test and Copy if createlog is checked
			case $action == $log
				if GUICtrlRead($log) == $GUI_CHECKED then
					GUICtrlSetState($test, $GUI_ENABLE)
				else
					GUICtrlSetState($test, $GUI_DISABLE)
				endif

			; Enable Disc field if Multi-disc option checked
			case $action == $multi OR $action == $gain
				if GUICtrlRead($multi) == $GUI_CHECKED then
					GUICtrlSetState($disc, $GUI_ENABLE)
					GUICtrlSetState($disc, $GUI_FOCUS)
					if GUICtrlRead($gain) == $GUI_CHECKED then
						GUICtrlSetState($indiv, $GUI_ENABLE)
					else
						GUICtrlSetState($indiv, $GUI_DISABLE)
					endif
				else
					GUICtrlSetState($disc, $GUI_DISABLE)
					GUICtrlSetState($indiv, $GUI_DISABLE)
				endif

			; Enable Wave field if notify option checked
			case $action == $notify
				if GUICtrlRead($notify) == $GUI_CHECKED then
					GUICtrlSetState($wave, $GUI_ENABLE)
					GUICtrlSetState($wavebut, $GUI_ENABLE)
				else
					GUICtrlSetState($wave, $GUI_DISABLE)
					GUICtrlSetState($wavebut, $GUI_DISABLE)
				endif

			; Process output dir selection
			case $action == $basebut
				$dir = fileselectfolder("Select directory", "", 7, GUICtrlRead($basedir))
				if not @error then GUICtrlSetData($basedir, $dir)
				GUICtrlSetState($basedir, $GUI_FOCUS)

			; Process directory naming scheme selection
			case $action == $sepschemebut
				local $message = "The ""Output scheme"" field sets the directory structure for ripped tracks."
				$message &= @CRLF & "This directory structure will be created below the ""Output base"", and is"
				$message &= @CRLF & "modelled after EAC's variable naming scheme.  Unlike EAC, however,"
				$message &= @CRLF & "you should only specify the directory structure, excluding file names."
				$message &= @CRLF & @CRLF & "The default scheme is ""%genre%\%albumartist%\%albumtitle%"""
				$message &= @CRLF & @CRLF & "Note: This MUST match EAC's naming scheme, minus the filename portion."
				$message &= @CRLF & @CRLF & $options
				msgbox(64, $title, $message)
				GUICtrlSetState($sepschemefield, $GUI_FOCUS)

			; Process image naming scheme selection
			case $action == $imgschemebut
				local $message = "The ""Image scheme"" field is used instead of ""Output scheme"" when ripping to an image."
				$message &= @CRLF & "The same options are available, but this field requires that the filename be set as well."
				$message &= @CRLF & @CRLF & "The default image scheme is ""%albumartist% - %albumtitle%"""
				$message &= @CRLF & @CRLF & $options
				msgbox(64, $title, $message)
				GUICtrlSetState($imgschemefield, $GUI_FOCUS)

			; Process flac binary selection
			case $action == $flacbut
				$file = fileopendialog("Select file", "", "EXE file (*.exe)", 1)
				if not @error then GUICtrlSetData($flacbin, $file)
				GUICtrlSetState($flacbin, $GUI_FOCUS)

			; Process metaflac binary selection
			case $action == $metaflacbut
				$file = fileopendialog("Select file", "", "EXE file (*.exe)", 1)
				if not @error then GUICtrlSetData($metaflacbin, $file)
				GUICtrlSetState($metaflacbin, $GUI_FOCUS)

			; Process md5sum binary selection
			;case $action == $md5but
			;	$file = fileopendialog("Select file", "", "EXE file (*.exe)", 1)
			;	if not @error then GUICtrlSetData($md5bin, $file)

			; Process wave file selection
			case $action == $wavebut
				$file = fileopendialog("Select file", @windowsdir & "\media", "Wave file (*.wav)", 1)
				if not @error then GUICtrlSetData($wave, $file)
				GUICtrlSetState($wave, $GUI_FOCUS)

			; Begin processing options
			case $action == $ok

				; Validate output dir
				if NOT fileexists(GUICtrlRead($basedir)) then
					msgbox(48, $title, "Error: You must select a valid output base directory.")
					GUICtrlSetState($basedir, $GUI_FOCUS)
					continueloop
				endif

				; Validate flac binary
				if NOT fileexists(GUICtrlRead($flacbin)) AND NOT SearchPath(GUICtrlRead($flacbin)) then
					msgbox(48, $title, "Error: You must select the flac binary to use for encoding.")
					GUICtrlSetState($flacbin, $GUI_FOCUS)
					continueloop
				endif

				; Validate metaflac binary
				if NOT fileexists(GUICtrlRead($metaflacbin)) AND NOT SearchPath(GUICtrlRead($metaflacbin)) then
					msgbox(48, $title, "Error: You must select the metaflac binary to use for encoding.")
					GUICtrlSetState($metaflacbin, $GUI_FOCUS)
					continueloop
				endif

				; Validate md5sum binary
				;if NOT fileexists(GUICtrlRead($md5bin)) AND NOT SearchPath(GUICtrlRead($md5bin)) then
				;	msgbox(48, $title, "Error: You must select the md5sum binary to use for encoding.")
				;	GUICtrlSetState($md5bin, $GUI_FOCUS)
				;	continueloop
				;endif

				; Validate wave file
				if GUICtrlRead($notify) == $GUI_CHECKED AND NOT fileexists(GUICtrlRead($wave)) AND NOT fileexists(@windowsdir & "\media\" & GUICtrlRead($wave)) then
					msgbox(48, $title, "Error: You must select the wave file to use for notification.")
					GUICtrlSetState($wave, $GUI_FOCUS)
					continueloop
				endif

				; Validate disc input
				if GUICtrlRead($multi) == $GUI_CHECKED AND NOT stringisint(GUICtrlRead($disc)) then
					msgbox(48, $title, "Error: You must enter the disc number.")
					GUICtrlSetState($disc, $GUI_FOCUS)
					continueloop
				endif

				; Update global variables
				$outputdir = GUICtrlRead($basedir)
				$sepscheme = GUICtrlRead($sepschemefield)
				$imgscheme = GUICtrlRead($imgschemefield)
				$flac = GUICtrlRead($flacbin)
				$metaflac = GUICtrlRead($metaflacbin)
				;$md5sum = GUICtrlRead($md5bin)
				$cdromdrive = GUICtrlRead($cdrom)
				if GUICtrlRead($priority) == $GUI_CHECKED then
					$lowpriority = 1
				else
					$lowpriority = 0
				endif
				if GUICtrlRead($eject) == $GUI_CHECKED then
					$ejectcomplete = 1
				else
					$ejectcomplete = 0
				endif
				if GUICtrlRead($notify) == $GUI_CHECKED then
					$notifycomplete = 1
					$notifywav = GUICtrlRead($wave)
				else
					$notifycomplete = 0
				endif
				if GUICtrlRead($log) == $GUI_CHECKED then
					$createlog = 1
				else
					$createlog = 0
				endif
				if GUICtrlRead($test) == $GUI_CHECKED then
					$testandcopy = 1
				else
					$testandcopy = 0
				endif
				if GUICtrlRead($gain) == $GUI_CHECKED then
					$replaygain = 1
				else
					$replaygain = 0
				endif
				if GUICtrlRead($data) == $GUI_CHECKED then
					$copydata = 1
				else
					$copydata = 0
				endif
				if GUICtrlRead($multi) == $GUI_CHECKED then
					$multidisc = 1
					$discnum = GUICtrlRead($disc)
					if GUICtrlRead($indiv) == $GUI_CHECKED then
						$indiv_replaygain = 1
					else
						$indiv_replaygain = 0
					endif
				else
					$multidisc = 0
				endif
				;if GUICtrlRead($verify) == $GUI_CHECKED then
				;	$checksums = 1
				;else
				;	$checksums = 0
				;endif
				if GUICtrlRead($all) == $GUI_CHECKED then
					$extractmethod = 'all'
				else
					$extractmethod = 'sel'
				endif
				if GUICtrlRead($image) == $GUI_CHECKED AND $extractmethod == 'all' then
					$ripimage = 1
				else
					$ripimage = 0
				endif
				if GUICtrlRead($cue) == $GUI_CHECKED AND $extractmethod == 'all' then
					$createcue = 1
				else
					$createcue = 0
				endif
				if GUICtrlRead($store) == $GUI_CHECKED AND $ripimage AND $createcue then
					$embedcue = 1
				else
					$embedcue = 0
				endif
				if GUICtrlRead($delcue) == $GUI_CHECKED AND $ripimage AND $createcue then
					$deletecue = 1
				else
					$deletecue = 0
				endif
				if GUICtrlRead($skipbut) == $GUI_CHECKED then
					$skiprip = 1
				else
					$skiprip = 0
				endif

				; Save preferences and begin extraction
				SavePrefs()
				GUIDelete()
				return

			; Exit if Cancel clicked or window closed
			case $action == $GUI_EVENT_CLOSE OR $action == $cancel
				exit
		endselect
	wend
endfunc

; Function to read AutoFLAC preferences
func ReadPrefs()
	$value = regread($regprefs, "extractmethod")
	if $value <> '' then $extractmethod = $value
	$value = regread($regprefs, "ripimage")
	if $value <> '' then $ripimage = int($value)
	$value = regread($regprefs, "createcue")
	if $value <> '' then $createcue = int($value)
	$value = regread($regprefs, "embedcue")
	if $value <> '' then $embedcue = int($value)
	$value = regread($regprefs, "deletecue")
	if $value <> '' then $deletecue = int($value)
	$value = regread($regprefs, "createlog")
	if $value <> '' then $createlog = int($value)
	$value = regread($regprefs, "testandcopy")
	if $value <> '' then $testandcopy = int($value)
	$value = regread($regprefs, "replaygain")
	if $value <> '' then $replaygain = int($value)
	$value = regread($regprefs, "indiv_replaygain")
	if $value <> '' then $indiv_replaygain = int($value)
	$value = regread($regprefs, "copydata")
	if $value <> '' then $copydata = int($value)
	;$value = regread($regprefs, "checksums")
	;if $value <> '' then $checksums = int($value)
	$value = regread($regprefs, "outputdir")
	if $value <> '' then $outputdir = $value
	$value = regread($regprefs, "sepscheme")
	if $value <> '' then $sepscheme = $value
	$value = regread($regprefs, "imgscheme")
	if $value <> '' then $imgscheme = $value
	$value = regread($regprefs, "eac")
	if $value <> '' then $eac = $value
	$value = regread($regprefs, "flac")
	if $value <> '' then $flac = $value
	$value = regread($regprefs, "metaflac")
	if $value <> '' then $metaflac = $value
	;$value = regread($regprefs, "md5sum")
	;if $value <> '' then $md5sum = $value
	$value = regread($regprefs, "cdromdrive")
	if $value <> '' then $cdromdrive = $value
	$value = regread($regprefs, "lowpriority")
	if $value <> '' then $lowpriority = int($value)
	$value = regread($regprefs, "ejectcomplete")
	if $value <> '' then $ejectcomplete = int($value)
	$value = regread($regprefs, "notifycomplete")
	if $value <> '' then $notifycomplete = int($value)
	$value = regread($regprefs, "notifywav")
	if $value <> '' then $notifywav = $value
	$value = regread($regprefs, "writetemptype")
	if $value <> '' then $writetemptype = $value
	$value = regread($regprefs, "writetempdir")
	if $value <> '' then $writetempdir = $value
	$multidisc = 0
	$skiprip = 0
endfunc

; Function to save AutoFLAC preferences
func SavePrefs()
	regwrite($regprefs, "extractmethod", "REG_SZ", $extractmethod)
	regwrite($regprefs, "ripimage", "REG_SZ", $ripimage)
	regwrite($regprefs, "createcue", "REG_SZ", $createcue)
	regwrite($regprefs, "embedcue", "REG_SZ", $embedcue)
	regwrite($regprefs, "deletecue", "REG_SZ", $deletecue)
	regwrite($regprefs, "createlog", "REG_SZ", $createlog)
	regwrite($regprefs, "testandcopy", "REG_SZ", $testandcopy)
	regwrite($regprefs, "replaygain", "REG_SZ", $replaygain)
	regwrite($regprefs, "indiv_replaygain", "REG_SZ", $indiv_replaygain)
	regwrite($regprefs, "copydata", "REG_SZ", $copydata)
	;regwrite($regprefs, "checksums", "REG_SZ", $checksums)
	regwrite($regprefs, "outputdir", "REG_SZ", $outputdir)
	regwrite($regprefs, "sepscheme", "REG_SZ", $sepscheme)
	regwrite($regprefs, "imgscheme", "REG_SZ", $imgscheme)
	regwrite($regprefs, "eac", "REG_SZ", $eac)
	regwrite($regprefs, "flac", "REG_SZ", $flac)
	regwrite($regprefs, "metaflac", "REG_SZ", $metaflac)
	;regwrite($regprefs, "md5sum", "REG_SZ", $md5sum)
	regwrite($regprefs, "cdromdrive", "REG_SZ", $cdromdrive)
	regwrite($regprefs, "lowpriority", "REG_SZ", $lowpriority)
	regwrite($regprefs, "ejectcomplete", "REG_SZ", $ejectcomplete)
	regwrite($regprefs, "notifycomplete", "REG_SZ", $notifycomplete)
	regwrite($regprefs, "notifywav", "REG_SZ", $notifywav)
	regwrite($regprefs, "writetemptype", "REG_SZ", $writetemptype)
	regwrite($regprefs, "writetempdir", "REG_SZ", $writetempdir)
endfunc

; Function to search %path% for executable
func SearchPath($file)
	; Search DOS path directories
	$dir = stringsplit(envget("path"), ';')
	redim $dir[$dir[0]+1]
	$dir[$dir[0]] = @scriptdir
	for $i = 1 to $dir[0]
		$exefiles = filefindfirstfile($dir[$i] & "\*.exe")
		if $exefiles == -1 then continueloop
		$exename = filefindnextfile($exefiles)
		do
			if $exename = $file then
				fileclose($exefiles)
				return 1
			endif
			$exename = filefindnextfile($exefiles)
		until @error
		fileclose($exefiles)
	next

	; Search Windows registered applications
	;$apppaths = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths"
	;$i = 1
	;$exefile = regenumkey($apppaths, $i)
	;do
	;	if $exefile = $file then
	;		$exepath = regread($apppaths & '\' & $exefile, '')
	;		if fileexists($exepath) then
	;			return 1
	;		else
	;			return 0
	;		endif
	;	endif
	;	$i = $i + 1
	;	$exefile = regenumkey($apppaths, $i)
	;until @error
	return 0
endfunc

; Function to select location of EAC.exe
func SelectEAC()
	; Create GUI
	GUICreate($title, 250, 100)
	GUICtrlCreateLabel("EAC.exe could not be automatically located.", 5, 5, -1, 15)
	GUICtrlCreateLabel("Please enter the full path for EAC.exe and click OK.", 5, 20, -1, 20)
	local $eacbin = GUICtrlCreateInput($eac, 5, 40, 210, 20)
	GUICtrlSetTip(-1, "Location of EAC.exe")
	local $eacbut = GUICtrlCreateButton("...", 220, 40, 25, 20)
	local $ok = GUICtrlCreateButton("&OK", 35, 70, 80, 20)
	local $cancel = GUICtrlCreateButton("Cancel", 135, 70, 80, 20)

	; Set properties
	GUICtrlSetState($eacbin, $GUI_FOCUS)
	GUICtrlSetState($ok, $GUI_DEFBUTTON)

	; Display GUI and wait for action
	GUISetState(@SW_SHOW)
	while 1
		$action = GUIGetMsg()
		select
			; Process EAC binary selection
			case $action == $eacbut
				$file = fileopendialog("Select file", "", "EXE file (*.exe)", 1)
				if not @error then
					GUICtrlSetData($eacbin, $file)
					GUICtrlSetState($eacbin, $GUI_FOCUS)
				endif

			; Validate file and return to caller
			case $action == $ok
				if NOT fileexists(GUICtrlRead($eacbin)) AND NOT SearchPath(GUICtrlRead($eacbin)) then
					msgbox(48, $title, "Error: You must select the EAC binary before continuing.")
					GUICtrlSetState($eacbin, $GUI_FOCUS)
					continueloop
				else
					$eac = GUICtrlRead($eacbin)
					SavePrefs()
					GUIDelete()
					return
				endif

			; Exit if Cancel clicked or window closed
			case $action == $GUI_EVENT_CLOSE OR $action == $cancel
				exit
		endselect
	wend
endfunc

; Function to return list of CD-ROM drives
func GetCDROMs()
	$cdarr = drivegetdrive("CDROM")
	$cdlist = ""
	for $i = 1 to $cdarr[0]
		$cdlist &= stringupper($cdarr[$i]) & "|"
	next
	stringtrimright($cdlist, 1)
	return $cdlist
endfunc

; Function to replace variables in naming scheme
func VarNameReplace($str)
	$str = stringreplace($str, "%albumtitle%", $album)
	$str = stringreplace($str, "%albumartist%", $artist)
	$str = stringreplace($str, "%albuminterpret%", $performer)
	$str = stringreplace($str, "%year%", $year)
	$str = stringreplace($str, "%genre%", $genre)
	$str = stringreplace($str, "%cddbtype%", $dbtype)
	$str = stringreplace($str, "%albumcomposer%", $cdcomposer)
	$str = stringreplace($str, "%comment%", $comment)
	return $str
endfunc

; Function to replace invalid Windows characters
;   This should match EAC's conversion scheme - thanks to Paul (masterofimages)
func SanitizeChars($string)
	$string = stringreplace($string, "/", ",")
	$string = stringreplace($string, ":", "-")
	$string = stringreplace($string, "*", "x")
	$string = stringreplace($string, "?", " ")
	$string = stringreplace($string, '"', "'")
	$string = stringreplace($string, "<", "[")
	$string = stringreplace($string, ">", "]")
	$string = stringreplace($string, "|", "!")
	return stringstripws($string, 3)
endfunc
