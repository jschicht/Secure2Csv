#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Res_Comment=Decode NTFS $Secure information ($SDS)
#AutoIt3Wrapper_Res_Description=Decode NTFS $Secure information ($SDS)
#AutoIt3Wrapper_Res_Fileversion=1.0.0.5
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;https://technet.microsoft.com/en-us/library/cc781716(v=ws.10).aspx
;http://www.ntfs.com/ntfs-permissions-file-structure.htm
;http://0cch.net/ntfsdoc/attributes/security_descriptor.html
;https://msdn.microsoft.com/en-us/library/windows/hardware/ff556610(v=vs.85).aspx
;https://msdn.microsoft.com/en-us/library/cc230286.aspx
;https://msdn.microsoft.com/en-us/library/cc230371.aspx
;https://msdn.microsoft.com/en-us/library/gg465313.aspx
;https://msdn.microsoft.com/en-us/library/dd302645.aspx
;https://msdn.microsoft.com/en-us/library/cc980032.aspx
#Include "SecureConstants.au3"
#Include <String.au3>
#Include <WinAPIEx.au3>
#Include <Array.au3>
#include <GuiEdit.au3>

Global $SDHArray[1][1],$SIIArray[1][1]
Global $de="|",$de2=":",$SecureCsvFile,$hSecureCsv,$WithQuotes=0,$EncodingWhenOpen=2;34=unicode,2=ansi
Global $TargetSDSOffsetHex,$SecurityDescriptorHash,$SecurityId,$ControlText,$SidOwner,$SidGroup
Global $SAclRevision,$SAceCount,$SAceTypeText,$SAceFlagsText,$SAceMask,$SAceObjectType,$SAceInheritedObjectType,$SAceSIDString,$SAceObjectFlagsText
Global $DAclRevision,$DAceCount,$DAceTypeText,$DAceFlagsText,$DAceMask,$DAceObjectType,$DAceInheritedObjectType,$DAceSIDString,$DAceObjectFlagsText
Global $SDSFile,$SDHFile,$SIIFile,$DoSDH=0,$DoSII=0,$OnlySDS=0
Global $ProgressSDS, $ProgressSDH, $ProgressSII, $CurrentProgress=-1, $ProgressStatus, $ProgressSize
Global $begin, $ElapsedTime, $CurrentDescriptor, $MaxDescriptors

Global Const $GUI_EVENT_CLOSE = -3
Global Const $GUI_CHECKED = 1
Global Const $GUI_UNCHECKED = 4
;Global Const $ES_AUTOVSCROLL = 64
Global Const $WS_VSCROLL = 0x00200000
Global Const $DT_END_ELLIPSIS = 0x8000
Global Const $GUI_DISABLE = 128

Opt("GUICloseOnESC", 1)
$Form = GUICreate("NTFS $Secure Parser - Secure2Csv - 1.0.0.5", 540, 460, -1, -1)

$LabelSDS = GUICtrlCreateLabel("$SDS:",20,10,80,20)
$SDSField = GUICtrlCreateInput("mandatory",70,10,350,20)
GUICtrlSetState($SDSField, $GUI_DISABLE)
$ButtonSDS = GUICtrlCreateButton("Select $SDS", 430, 10, 100, 20)

$LabelSDH = GUICtrlCreateLabel("$SDH:",20,35,80,20)
$SDHField = GUICtrlCreateInput("optional",70,35,350,20)
GUICtrlSetState($SDHField, $GUI_DISABLE)
$ButtonSDH = GUICtrlCreateButton("Select $SDH", 430, 35, 100, 20)
;GUICtrlSetState($ButtonSDH, $GUI_DISABLE)

$LabelSII = GUICtrlCreateLabel("$SII:",20,60,80,20)
$SIIField = GUICtrlCreateInput("optional",70,60,350,20)
GUICtrlSetState($SIIField, $GUI_DISABLE)
$ButtonSII = GUICtrlCreateButton("Select $SII", 430, 60, 100, 20)

$LabelSeparator = GUICtrlCreateLabel("Set output field separator:",20,100,130,20)
$SeparatorInput = GUICtrlCreateInput($de,150,100,20,20)
$SeparatorInput2 = GUICtrlCreateInput($de,180,100,30,20)
GUICtrlSetState($SeparatorInput2, $GUI_DISABLE)

$LabelAceSeparator = GUICtrlCreateLabel("Set Ace separator:",20,125,130,20)
$AceSeparatorInput = GUICtrlCreateInput($de2,150,125,20,20)
$AceSeparatorInput2 = GUICtrlCreateInput($de2,180,125,30,20)
GUICtrlSetState($AceSeparatorInput2, $GUI_DISABLE)

$ButtonStart = GUICtrlCreateButton("Start", 430, 115, 100, 30)
$myctredit = GUICtrlCreateEdit("", 0, 150, 540, 120, BitOr($ES_AUTOVSCROLL,$WS_VSCROLL))
_GUICtrlEdit_SetLimitText($myctredit, 128000)
GUISetState(@SW_SHOW)

While 1
	$nMsg = GUIGetMsg()
	Sleep(100)
	_TranslateSeparator()
	_TranslateSeparatorAce()

	Select
		Case $nMsg = $ButtonSDS
			_SelectSDS()
		Case $nMsg = $ButtonSDH
			_SelectSDH()
		Case $nMsg = $ButtonSII
			_SelectSII()
		Case $nMsg = $ButtonStart
			_Main()
		Case $nMsg = $GUI_EVENT_CLOSE
			Exit
	EndSelect
WEnd

Func _Main()
	Local $nBytes
	GUICtrlSetData($ProgressSDS, 0)
	GUICtrlSetData($ProgressSDH, 0)
	GUICtrlSetData($ProgressSII, 0)

	If $SDSFile = "" Then
		_DisplayInfo("Error: $SDS must be set" & @crlf)
		Return
	EndIf

	If StringLen(GUICtrlRead($SeparatorInput)) <> 1 Then
		_DisplayInfo("Error: Separator not set properly" & @crlf)
		ConsoleWrite("Error: Separator not set properly: " & GUICtrlRead($SeparatorInput) & @crlf)
		Return
	Else
		$de = GUICtrlRead($SeparatorInput)
		ConsoleWrite("Using separator: " & $de & @crlf)
	EndIf

	If StringLen(GUICtrlRead($AceSeparatorInput)) <> 1 Then
		_DisplayInfo("Error: Ace separator not set properly" & @crlf)
		ConsoleWrite("Error: Ace separator not set properly: " & GUICtrlRead($AceSeparatorInput) & @crlf)
		Return
	Else
		$de2 = GUICtrlRead($AceSeparatorInput)
		ConsoleWrite("Using Ace separator: " & $de2 & @crlf)
	EndIf

	If $DoSDH=0 And $DoSII=0 Then
		$OnlySDS=1
;		_DisplayInfo("Error: Must have either $SII or $SDH" & @CRLF)
;		Return
	EndIf
	$hSDS = _WinAPI_CreateFile("\\.\" & $SDSFile,2,2,7)
	If $hSDS = 0 Then
		ConsoleWrite("Error in CreateFile for " & $SDSFile & " : " & _WinAPI_GetLastErrorMessage())
		_DisplayInfo("Error in CreateFile for " & $SDSFile & " : " & _WinAPI_GetLastErrorMessage())
		Return
	EndIf
	$SizeSDS = _WinAPI_GetFileSizeEx($hSDS)
	ConsoleWrite("$SizeSDS: " & $SizeSDS & @CRLF)
	_DisplayInfo("Using $SDS: " & $SDSFile & @crlf)

	$TimestampStart = @YEAR & "-" & @MON & "-" & @MDAY & "_" & @HOUR & "-" & @MIN & "-" & @SEC
	$SecureCsvFile = @ScriptDir & "\"&$TimestampStart&"_Secure"&".csv"
	$hSecureCsv = FileOpen($SecureCsvFile, $EncodingWhenOpen)
	If @error Then
		ConsoleWrite("Error creating: " & $SecureCsvFile & @CRLF)
		Return
	EndIf
	_WriteCSVHeader()

	$Progress = GUICtrlCreateLabel("Decoding security descriptors in $SDS", 10, 280,540,20)
	GUICtrlSetFont($Progress, 12)
	$ProgressStatus = GUICtrlCreateLabel("", 10, 310, 520, 20)
	$ElapsedTime = GUICtrlCreateLabel("", 10, 325, 520, 20)
	$ProgressSDH = GUICtrlCreateProgress(10, 350, 520, 30)
	$ProgressSII = GUICtrlCreateProgress(10,  385, 520, 30)
	$ProgressSDS = GUICtrlCreateProgress(10, 420, 520, 30)

	Select
		Case $DoSII
			$hSII = _WinAPI_CreateFile("\\.\" & $SIIFile,2,2,7)
			If $hSII = 0 Then
				ConsoleWrite("Error in CreateFile for " & $SIIFile & " : " & _WinAPI_GetLastErrorMessage())
				_DisplayInfo("Error in CreateFile for " & $SIIFile & " : " & _WinAPI_GetLastErrorMessage())
				Return
			EndIf
			$SizeSII = _WinAPI_GetFileSizeEx($hSII)
			ConsoleWrite("$SizeSII: " & $SizeSII & @CRLF)
			_DisplayInfo("Using $SII: " & $SIIFile & @crlf)
			$FixedSIIEntries = @ScriptDir & "\"&$TimestampStart&"_FixedSII"&".bin"
			$hFixedSII = FileOpen($FixedSIIEntries,16+2)
			$tBuffer3 = DllStructCreate("byte["&$SizeSII&"]")
			_WinAPI_ReadFile($hSII, DllStructGetPtr($tBuffer3), $SizeSII, $nBytes)
			$RawContentSII = DllStructGetData($tBuffer3, 1)
			If Not StringMid($RawContentSII,3,8) = "494E4458" Then
				$CoreSII = StringMid($RawContentSII,3)
			Else
				$CoreSII = _GetIndx($RawContentSII)
			EndIf
			FileWrite($hFixedSII,"0x"&$CoreSII)
			ConsoleWrite("Starting decode of $SII" & @CRLF)
			_DecodeIndxEntriesSII($CoreSII)
			ConsoleWrite("Security descriptors referenced in $SII: " & UBound($SIIArray)-1 & @CRLF)
			;_ArrayDisplay($SIIArray,"$SIIArray")
			;SDS
			$tBuffer = DllStructCreate("byte["&$SizeSDS&"]")
			_WinAPI_ReadFile($hSDS, DllStructGetPtr($tBuffer), $SizeSDS, $nBytes)
			$RawContentSDS = DllStructGetData($tBuffer, 1)
			ConsoleWrite("Starting decode of $SDS" & @CRLF)

			$begin = TimerInit()
			AdlibRegister("_SDSProgress", 500)
			$MaxDescriptors=Ubound($SIIArray)-1
			For $i = 1 To Ubound($SIIArray)-1
				$CurrentDescriptor=$i
				;Retrieve information about where security descriptor is stored within $SDS
				$TargetSDSOffset = Dec($SIIArray[$i][0])
				$TargetSDSSize = Dec($SIIArray[$i][1])
				$TargetSDSChunk = StringMid($RawContentSDS,3+($TargetSDSOffset*2),$TargetSDSSize*2)
				$TargetSDSOffsetHex = "0x"&Hex($TargetSDSOffset,8)
				;Parse a given security descriptor
				_DecodeSDSChunk($TargetSDSChunk, $SIIArray[$i][3])
				;Write information to csv
				_WriteCsv()
				;Make sure all global variables for csv are cleared
				_ClearVar()
			Next
			AdlibUnRegister("_SDSProgress")
			GUICtrlSetData($ProgressStatus, "[$SDS] Processing security descriptor " & $CurrentDescriptor & " of " & $MaxDescriptors)
			GUICtrlSetData($ElapsedTime, "Elapsed time = " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)))
			GUICtrlSetData($ProgressSDS, 100 * $CurrentDescriptor / $MaxDescriptors)
			_DisplayInfo("$SDS processing finished in " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)) & @CRLF)

			_WinAPI_CloseHandle($hSDS)
			_WinAPI_CloseHandle($hSII)
			FileClose($hSecureCsv)
			FileClose($hFixedSII)


		Case $DoSDH
			$hSDH = _WinAPI_CreateFile("\\.\" & $SDHFile,2,2,7)
			If $hSDH = 0 Then
				ConsoleWrite("Error in CreateFile for " & $SDHFile & " : " & _WinAPI_GetLastErrorMessage())
				_DisplayInfo("Error in CreateFile for " & $SDHFile & " : " & _WinAPI_GetLastErrorMessage())
				Return
			EndIf
			$SizeSDH = _WinAPI_GetFileSizeEx($hSDH)
			ConsoleWrite("$SizeSDH: " & $SizeSDH & @CRLF)
			_DisplayInfo("Using $SDH: " & $SDHFile & @crlf)
			$FixedSDHEntries = @ScriptDir & "\"&$TimestampStart&"_FixedSDH"&".bin"
			$hFixedSDH = FileOpen($FixedSDHEntries,16+2)
			$tBuffer2 = DllStructCreate("byte["&$SizeSDH&"]")
			_WinAPI_ReadFile($hSDH, DllStructGetPtr($tBuffer2), $SizeSDH, $nBytes)
			$RawContentSDH = DllStructGetData($tBuffer2, 1)
			If Not StringMid($RawContentSDH,3,8) = "494E4458" Then
				$CoreSDH = StringMid($RawContentSDH,3)
			Else
				$CoreSDH = _GetIndx($RawContentSDH)
			EndIf
			FileWrite($hFixedSDH,"0x"&$CoreSDH)
			ConsoleWrite("Starting decode of $SDH" & @CRLF)
			_DecodeIndxEntriesSDH($CoreSDH)
			ConsoleWrite("Security descriptors referenced in $SDH: " & UBound($SDHArray)-1 & @CRLF)
			;_ArrayDisplay($SDHArray,"$SDHArray")
			;SDS
			$tBuffer = DllStructCreate("byte["&$SizeSDS&"]")
			_WinAPI_ReadFile($hSDS, DllStructGetPtr($tBuffer), $SizeSDS, $nBytes)
			$RawContentSDS = DllStructGetData($tBuffer, 1)
			ConsoleWrite("Starting decode of $SDS" & @CRLF)

			$begin = TimerInit()
			AdlibRegister("_SDSProgress", 500)
			$MaxDescriptors=Ubound($SDHArray)-1
			For $i = 1 To Ubound($SDHArray)-1
				$CurrentDescriptor=$i
				;Retrieve information about where security descriptor is stored within $SDS
				$TargetSDSOffset = Dec($SDHArray[$i][0])
				$TargetSDSSize = Dec($SDHArray[$i][1])
				$TargetSDSChunk = StringMid($RawContentSDS,3+($TargetSDSOffset*2),$TargetSDSSize*2)
				$TargetSDSOffsetHex = "0x"&Hex($TargetSDSOffset,8)
				;Parse a given security descriptor
				_DecodeSDSChunk($TargetSDSChunk, $SDHArray[$i][4])
				;Write information to csv
				_WriteCsv()
				;Make sure all global variables for csv are cleared
				_ClearVar()
			Next
			AdlibUnRegister("_SDSProgress")
			GUICtrlSetData($ProgressStatus, "[$SDS] Processing security descriptor " & $CurrentDescriptor & " of " & $MaxDescriptors)
			GUICtrlSetData($ElapsedTime, "Elapsed time = " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)))
			GUICtrlSetData($ProgressSDS, 100 * $CurrentDescriptor / $MaxDescriptors)
			_DisplayInfo("$SDS processing finished in " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)) & @CRLF)

			_WinAPI_CloseHandle($hSDS)
			_WinAPI_CloseHandle($hSDH)
			FileClose($hSecureCsv)
			FileClose($hFixedSDH)
			#cs
			$SizeAcc=0
			For $i = 1 To Ubound($SDHArray)-1
				$SizeAcc += Dec($SDHArray[$i][1])
			Next
			$SizeAverage = $SizeAcc/Ubound($SDHArray)-1
			ConsoleWrite("Average size of security descriptor: " & $SizeAverage & @CRLF)
			#ce

		Case $OnlySDS
			;Average size is 268 bytes
			$tBuffer = DllStructCreate("byte["&$SizeSDS&"]")
			_WinAPI_ReadFile($hSDS, DllStructGetPtr($tBuffer), $SizeSDS, $nBytes)
			$RawContentSDS = DllStructGetData($tBuffer, 1)
			ConsoleWrite("Starting decode of $SDS" & @CRLF)
			$EstimatedDescriptors = Round($SizeSDS/268)
			$StartOffset = 3
			$BytesProcessed = 0
			$CurrentDescriptor = 0
			$begin = TimerInit()
			AdlibRegister("_SDSProgress", 500)
			$MaxDescriptors=$EstimatedDescriptors
			$BigChunks = Ceiling($SizeSDS/262144)
			While 1
				$CurrentDescriptor += 1
;				ConsoleWrite("$CurrentDescriptor: " & $CurrentDescriptor & @CRLF)
				If $BytesProcessed >= $SizeSDS Then
					ConsoleWrite("End of $SDS reached" & @CRLF)
					ExitLoop
				EndIf
				$TargetSDSOffset = StringMid($RawContentSDS,$StartOffset + 16, 16)
				$TargetSDSOffset = Dec(_SwapEndian($TargetSDSOffset),2)

				$TargetSDSSize = StringMid($RawContentSDS,$StartOffset + 32, 8)
				$TargetSDSSize = Dec(_SwapEndian($TargetSDSSize),2)

				If $TargetSDSOffset >= $SizeSDS Then
					ConsoleWrite("End of $SDS reached" & @CRLF)
					ExitLoop
				EndIf

				$TargetSDSOffsetHex = "0x"&Hex(Int(($StartOffset-3)/2),8)
;				ConsoleWrite("$TargetSDSOffsetHex: " & $TargetSDSOffsetHex & @CRLF)

				If $TargetSDSOffset = 0 And $TargetSDSSize = 0 Then
					If Mod(($StartOffset-3)/2,262144) Then ; Align 0x40000
						Do
							$StartOffset+=2
						Until Mod(($StartOffset-3)/2,262144)=0
						ContinueLoop ;Move to next block
					Else
						ExitLoop ;We are at end
					EndIf
				EndIf

				If Mod($TargetSDSSize,16) Then ; Align SDS size to 16 bytes
					Do
						$TargetSDSSize+=1
					Until Mod($TargetSDSSize,16)=0
				EndIf
				$TargetSDSHash = StringMid($RawContentSDS,$StartOffset, 8)
				$TargetSDSChunk = StringMid($RawContentSDS,3+($TargetSDSOffset*2), $TargetSDSSize*2)
;				ConsoleWrite("$TargetSDSSize: " & $TargetSDSSize & @CRLF)
				_DecodeSDSChunk($TargetSDSChunk, $TargetSDSHash)
				;Write information to csv
				_WriteCsv()
				;Make sure all global variables for csv are cleared
				_ClearVar()
				$BytesProcessed+=$TargetSDSSize
				$StartOffset+=$TargetSDSSize*2
			WEnd
			$MaxDescriptors = $CurrentDescriptor
			AdlibUnRegister("_SDSProgress")
			GUICtrlSetData($ProgressStatus, "[$SDS] Processing security descriptor " & $CurrentDescriptor & " of " & $MaxDescriptors)
			GUICtrlSetData($ElapsedTime, "Elapsed time = " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)))
			GUICtrlSetData($ProgressSDS, 100 * $CurrentDescriptor / $MaxDescriptors)
			_DisplayInfo("$SDS processing finished in " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)) & @CRLF)

	EndSelect
	_DisplayInfo("Done! " & @crlf)
	GUICtrlSetData($SDSField,"")
	GUICtrlSetData($SIIField,"")
	GUICtrlSetData($SDHField,"")
	$DoSDH=0
	$DoSII=0
EndFunc

Func _DecodeSDSChunk($InputData, $Hash)
	;https://msdn.microsoft.com/en-us/library/cc230366.aspx
	Local $StartOffset = 1
	Global $SecurityDescriptorHash,$SecurityId,$ControlText,$SidOwner,$SidGroup
;	ConsoleWrite("_DecodeSDSChunk() " & @CRLF)
;	ConsoleWrite(_HexEncode("0x"&$InputData))
	$SecurityDescriptorHash = StringMid($InputData, $StartOffset, 8)
;	$SecurityDescriptorHash = _SwapEndian($SecurityDescriptorHash)
	If $SecurityDescriptorHash <> $Hash Then
		ConsoleWrite("Error: Hash mismatch" & @CRLF)
		Return
	EndIf
	$SecurityDescriptorHash = "0x" & $SecurityDescriptorHash

	$SecurityId = StringMid($InputData, $StartOffset + 8, 8)
	$SecurityId = _SwapEndian($SecurityId)
	$SecurityId = Dec($SecurityId,2)

	$EntryOffset = StringMid($InputData, $StartOffset + 16, 16)
	$EntryOffset = _SwapEndian($EntryOffset)

	$EntrySize = StringMid($InputData, $StartOffset + 32, 8)
	$EntrySize = _SwapEndian($EntrySize)

;	Start SelfrelativeSecurityDescriptor
	$Revision = StringMid($InputData, $StartOffset + 40, 2)

	$Revision = Dec($Revision)
	If $Revision <> 1 Then
		ConsoleWrite("Error: Revision invalid: " & $Revision & @CRLF)
;		Return
	EndIf
	$Sbz1 = StringMid($InputData, $StartOffset + 42, 2)

	$SECURITY_DESCRIPTOR_CONTROL = StringMid($InputData, $StartOffset + 44, 4)
	$SECURITY_DESCRIPTOR_CONTROL = _SwapEndian($SECURITY_DESCRIPTOR_CONTROL)

	$ControlText = _SecurityDescriptorControl("0x"&$SECURITY_DESCRIPTOR_CONTROL)

	If Not BitAND("0x"&$SECURITY_DESCRIPTOR_CONTROL, $SE_SELF_RELATIVE) Then
		ConsoleWrite("Error: Descriptor not self relative. Nothing to do" & @CRLF)
		Return
	EndIf
	$PSidOwner = StringMid($InputData, $StartOffset + 48, 8)
	$PSidOwner = _SwapEndian($PSidOwner)

	$PSidOwner = Dec($PSidOwner)
	$PSidGroup = StringMid($InputData, $StartOffset + 56, 8)
	$PSidGroup = _SwapEndian($PSidGroup)

	$PSidGroup = Dec($PSidGroup)
	$PSacl = StringMid($InputData, $StartOffset + 64, 8)
	$PSacl = _SwapEndian($PSacl)

	$PSacl = Dec($PSacl)
	$PDacl = StringMid($InputData, $StartOffset + 72, 8)
	$PDacl = _SwapEndian($PDacl)

	$PDacl = Dec($PDacl)
	If $PSidOwner > 0 Then
		$SidOwner = _DecodeSID(StringMid($InputData,$StartOffset+40+$PSidOwner*2))
	EndIf
	If $PSidGroup > 0 Then
		$SidGroup = _DecodeSID(StringMid($InputData,$StartOffset+40+$PSidGroup*2))
	EndIf
	If $PSacl > 0 Then
		_DecodeAcl_S(StringMid($InputData,$StartOffset+40+$PSacl*2))
	EndIf
	If $PDacl > 0 Then
		_DecodeAcl_D(StringMid($InputData,$StartOffset+40+$PDacl*2))
	EndIf
	#cs
	ConsoleWrite("$SecurityDescriptorHash: " & $SecurityDescriptorHash & @CRLF)
	ConsoleWrite("$SecurityId: " & $SecurityId & @CRLF)
	ConsoleWrite("$EntryOffset: " & $EntryOffset & @CRLF)
	ConsoleWrite("$EntrySize: " & $EntrySize & @CRLF)
	ConsoleWrite("$Revision: " & $Revision & @CRLF)
	ConsoleWrite("$Sbz1: " & $Sbz1 & @CRLF)
	ConsoleWrite("$SECURITY_DESCRIPTOR_CONTROL: " & $SECURITY_DESCRIPTOR_CONTROL & @CRLF)
	ConsoleWrite("$ControlText: " & $ControlText & @CRLF)
	ConsoleWrite("$PSidOwner: " & $PSidOwner & @CRLF)
	ConsoleWrite("$PSidGroup: " & $PSidGroup & @CRLF)
	ConsoleWrite("$PSacl: " & $PSacl & @CRLF)
	ConsoleWrite("$PDacl: " & $PDacl & @CRLF)
	#ce
EndFunc

Func _DecodeAcl_S($InputData)
	;https://msdn.microsoft.com/en-us/library/cc230297.aspx
	Local $StartOffset = 1, $AceDataCounter = 0
	Global $SAclRevision,$SAceCount,$SAceTypeText,$SAceFlagsText,$SAceMask,$SAceObjectFlagsText,$SAceObjectType,$SAceInheritedObjectType,$SAceSIDString
;	ConsoleWrite("_DecodeAcl_S() " & @CRLF)
;	ConsoleWrite(_HexEncode("0x"&$InputData))
	; ACL header 8 bytes
	$SAclRevision = StringMid($InputData, $StartOffset, 2)

	If $SAclRevision <> "02" And $SAclRevision <> "04" Then
		ConsoleWrite("Error: Invalid SAclRevision: " & $SAclRevision & @CRLF)
	EndIf
	$Sbz1 = StringMid($InputData, $StartOffset + 2, 2)

	$AclSize = StringMid($InputData, $StartOffset + 4, 4)
	$AclSize = _SwapEndian($AclSize)

	$AclSize = Dec($AclSize)
	$SAceCount = StringMid($InputData, $StartOffset + 8, 4)
	$SAceCount = _SwapEndian($SAceCount)

	$SAceCount = Dec($SAceCount)
	$Sbz2 = StringMid($InputData, $StartOffset + 12, 4)
	#cs
	ConsoleWrite("$SAclRevision: " & $SAclRevision & @CRLF)
	ConsoleWrite("$Sbz1: " & $Sbz1 & @CRLF)
	ConsoleWrite("$AclSize: " & $AclSize & @CRLF)
	ConsoleWrite("$SAceCount: " & $SAceCount & @CRLF)
	ConsoleWrite("$Sbz2: " & $Sbz2 & @CRLF)
	#ce
	If $SAceCount < 1 Then Return
	For $j = 1 To $SAceCount

		;ACE_HEADER 4 bytes
		;https://msdn.microsoft.com/en-us/library/cc230296.aspx
		$AceType = StringMid($InputData, $StartOffset + $AceDataCounter + 16, 2)

		$AceTypeText = _DecodeAceType(Number("0x"&$AceType))
		If $AceTypeText = "" Then
			ConsoleWrite("Error: AceType invalid" & @CRLF)
;			ContinueLoop
		EndIf
		If $AceTypeText = "UNKNOWN" Then ConsoleWrite("Unknown ace flags: " & $AceType & @CRLF)

		$AceFlags = StringMid($InputData, $StartOffset + $AceDataCounter + 18, 2)

		$AceFlagsText = _DecodeAceFlags(Number("0x"&$AceFlags))

		If $j > 1 Then
			$SAceTypeText &= $de2 & $AceTypeText
			$SAceFlagsText &= $de2 & $AceFlagsText
		Else
			$SAceTypeText = $AceTypeText
			$SAceFlagsText = $AceFlagsText
		EndIf
		$AceSize = StringMid($InputData, $StartOffset + $AceDataCounter + 20, 4)
		$AceSize = _SwapEndian($AceSize)

		$AceSize = Dec($AceSize)
		;Remaining bytes of ACE depends on AceType
		$Mask=""
		$Flags=""
		$ObjectType=""
		$InheritedObjectType=""
		$SIDString=""
		If _IsSmallAceStruct("0x"&$AceType) Then
;			ConsoleWrite("Small struct " & @CRLF)
			;"dword Mask;dword SidStart"
			;https://msdn.microsoft.com/en-us/library/windows/desktop/aa374902(v=vs.85).aspx
			$Mask = StringMid($InputData, $StartOffset + $AceDataCounter + 24, 8)
			$Mask = "0x"&_SwapEndian($Mask)

			$SIDString = _DecodeSID(StringMid($InputData,$StartOffset + $AceDataCounter + 32, $AceSize*2))
			If $j > 1 Then
				$SAceMask &= $de2 & $Mask
				$SAceSIDString &= $de2 & $SIDString
			Else
				$SAceMask = $Mask
				$SAceSIDString = $SIDString
			EndIf
		Else
;			ConsoleWrite("Big struct " & @CRLF)
			;"dword Mask;dword Flags;GUID ObjectType;GUID InheritedObjectType;dword SidStart"
			$Mask = StringMid($InputData, $StartOffset + $AceDataCounter + 24, 8)
			$Mask = "0x"&_SwapEndian($Mask)

			$ObjectFlags = StringMid($InputData, $StartOffset + $AceDataCounter + 32, 8)
			$ObjectFlags = _SwapEndian($ObjectFlags)
			$ObjectFlagsText = _DecodeAceObjectFlag($ObjectFlags)

			$ObjectType = StringMid($InputData, $StartOffset + $AceDataCounter + 40, 32)
			$ObjectType = _HexToGuidStr($ObjectType)
			$InheritedObjectType = StringMid($InputData, $StartOffset + $AceDataCounter + 72, 32)
			$InheritedObjectType = _HexToGuidStr($InheritedObjectType)

			$SIDString = _DecodeSID(StringMid($InputData,$StartOffset + $AceDataCounter + 104, $AceSize*2))
			If $j > 1 Then
				$SAceMask &= $de2 & $Mask
				$SAceObjectFlagsText &= $de2 & $ObjectFlagsText
				$SAceObjectType &= $de2 & $ObjectType
				$SAceInheritedObjectType &= $de2 & $InheritedObjectType
				$SAceSIDString &= $de2 & $SIDString
			Else
				$SAceMask = $Mask
				$SAceObjectFlagsText = $ObjectFlagsText
				$SAceObjectType = $ObjectType
				$SAceInheritedObjectType = $InheritedObjectType
				$SAceSIDString = $SIDString
			EndIf
		EndIf
		#cs
		ConsoleWrite(@CRLF & "Ace number: " & $j & @CRLF)
		ConsoleWrite("$AceType: " & $AceType & @CRLF)
		ConsoleWrite("$AceTypeText: " & $AceTypeText & @CRLF)
		ConsoleWrite("$AceFlags: " & $AceFlags & @CRLF)
		ConsoleWrite("$AceFlagsText: " & $AceFlagsText & @CRLF)
		ConsoleWrite("$AceSize: " & $AceSize & @CRLF)
		ConsoleWrite("$Mask: " & $Mask & @CRLF)
		ConsoleWrite("$Flags: " & $Flags & @CRLF)
		ConsoleWrite("$ObjectType: " & $ObjectType & @CRLF)
		ConsoleWrite("$InheritedObjectType: " & $InheritedObjectType & @CRLF)
		ConsoleWrite("$SIDString: " & $SIDString & @CRLF)
		#ce
		$AceDataCounter += $AceSize*2
	Next
EndFunc

Func _DecodeAcl_D($InputData)
	;https://msdn.microsoft.com/en-us/library/cc230297.aspx
	Local $StartOffset = 1, $AceDataCounter = 0
	Global $DAclRevision,$DAceCount,$DAceTypeText,$DAceFlagsText,$DAceMask,$DAceObjectFlagsText,$DAceObjectType,$DAceInheritedObjectType,$DAceSIDString
;	ConsoleWrite("_DecodeAcl_D() " & @CRLF)
;	ConsoleWrite(_HexEncode("0x"&$InputData))
	; ACL header 8 bytes
	$DAclRevision = StringMid($InputData, $StartOffset, 2)

	If $DAclRevision <> "02" And $DAclRevision <> "04" Then
		ConsoleWrite("Error: Invalid DAclRevision: " & $DAclRevision & @CRLF)
	EndIf
	$Sbz1 = StringMid($InputData, $StartOffset + 2, 2)

	$AclSize = StringMid($InputData, $StartOffset + 4, 4)
	$AclSize = _SwapEndian($AclSize)

	$AclSize = Dec($AclSize)
	$DAceCount = StringMid($InputData, $StartOffset + 8, 4)
	$DAceCount = _SwapEndian($DAceCount)

	$DAceCount = Dec($DAceCount)
	$Sbz2 = StringMid($InputData, $StartOffset + 12, 4)
	#cs
	ConsoleWrite("$DAclRevision: " & $DAclRevision & @CRLF)
	ConsoleWrite("$Sbz1: " & $Sbz1 & @CRLF)
	ConsoleWrite("$AclSize: " & $AclSize & @CRLF)
	ConsoleWrite("$DAceCount: " & $DAceCount & @CRLF)
	ConsoleWrite("$Sbz2: " & $Sbz2 & @CRLF)
	#ce
	If $DAceCount < 1 Then Return
	For $j = 1 To $DAceCount

		;ACE_HEADER 4 bytes
		;https://msdn.microsoft.com/en-us/library/cc230296.aspx
		$AceType = StringMid($InputData, $StartOffset + $AceDataCounter + 16, 2)

		$AceTypeText = _DecodeAceType(Number("0x"&$AceType))
		If $AceTypeText = "" Then
			ConsoleWrite("Error: AceType invalid" & @CRLF)
;			ContinueLoop
		EndIf

		$AceFlags = StringMid($InputData, $StartOffset + $AceDataCounter + 18, 2)

		$AceFlagsText = _DecodeAceFlags(Number("0x"&$AceFlags))

		If $j > 1 Then
			$DAceTypeText &= $de2 & $AceTypeText
			$DAceFlagsText &= $de2 & $AceFlagsText
		Else
			$DAceTypeText = $AceTypeText
			$DAceFlagsText = $AceFlagsText
		EndIf
		$AceSize = StringMid($InputData, $StartOffset + $AceDataCounter + 20, 4)
		$AceSize = _SwapEndian($AceSize)

		$AceSize = Dec($AceSize)
		;Remaining bytes of ACE depends on AceType
		$Mask=""
		$Flags=""
		$ObjectType=""
		$InheritedObjectType=""
		$SIDString=""
		If _IsSmallAceStruct("0x"&$AceType) Then
;			ConsoleWrite("Small struct " & @CRLF)
			;"dword Mask;dword SidStart"
			;https://msdn.microsoft.com/en-us/library/windows/desktop/aa374902(v=vs.85).aspx
			$Mask = StringMid($InputData, $StartOffset + $AceDataCounter + 24, 8)
			$Mask = "0x"&_SwapEndian($Mask)

			$SIDString = _DecodeSID(StringMid($InputData,$StartOffset + $AceDataCounter + 32, $AceSize*2))

			If $j > 1 Then
				$DAceMask &= $de2 & $Mask
				$DAceSIDString &= $de2 & $SIDString
			Else
				$DAceMask = $Mask
				$DAceSIDString = $SIDString
			EndIf
		Else
;			ConsoleWrite("Big struct " & @CRLF)
			;"dword Mask;dword Flags;GUID ObjectType;GUID InheritedObjectType;dword SidStart"
			$Mask = StringMid($InputData, $StartOffset + $AceDataCounter + 24, 8)
			$Mask = "0x"&_SwapEndian($Mask)

			$ObjectFlags = StringMid($InputData, $StartOffset + $AceDataCounter + 32, 8)
			$ObjectFlags = _SwapEndian($ObjectFlags)
			$ObjectFlagsText = _DecodeAceObjectFlag($ObjectFlags)

			$ObjectType = StringMid($InputData, $StartOffset + $AceDataCounter + 40, 32)
			$ObjectType = _HexToGuidStr($ObjectType)
			$InheritedObjectType = StringMid($InputData, $StartOffset + $AceDataCounter + 72, 32)
			$InheritedObjectType = _HexToGuidStr($InheritedObjectType)

			$SIDString = _DecodeSID(StringMid($InputData,$StartOffset + $AceDataCounter + 104, $AceSize*2))

			If $j > 1 Then
				$DAceMask &= $de2 & $Mask
				$DAceObjectFlagsText &= $de2 & $ObjectFlagsText
				$DAceObjectType &= $de2 & $ObjectType
				$DAceInheritedObjectType &= $de2 & $InheritedObjectType
				$DAceSIDString &= $de2 & $SIDString
			Else
				$DAceMask = $Mask
				$DAceObjectFlagsText = $ObjectFlagsText
				$DAceObjectType = $ObjectType
				$DAceInheritedObjectType = $InheritedObjectType
				$DAceSIDString = $SIDString
			EndIf
		EndIf
		#cs
		ConsoleWrite(@CRLF & "Ace number: " & $j & @CRLF)
		ConsoleWrite("$AceType: " & $AceType & @CRLF)
		ConsoleWrite("$AceTypeText: " & $AceTypeText & @CRLF)
		ConsoleWrite("$AceFlags: " & $AceFlags & @CRLF)
		ConsoleWrite("$AceFlagsText: " & $AceFlagsText & @CRLF)
		ConsoleWrite("$AceSize: " & $AceSize & @CRLF)
		ConsoleWrite("$Mask: " & $Mask & @CRLF)
		ConsoleWrite("$Flags: " & $Flags & @CRLF)
		ConsoleWrite("$ObjectType: " & $ObjectType & @CRLF)
		ConsoleWrite("$InheritedObjectType: " & $InheritedObjectType & @CRLF)
		ConsoleWrite("$SIDString: " & $SIDString & @CRLF)
		#ce
		$AceDataCounter += $AceSize*2
	Next
EndFunc

Func _DecodeSID($InputData)
	;https://msdn.microsoft.com/en-us/library/cc230371.aspx
	Local $StartOffset = 1, $SIDString = "S"
;	ConsoleWrite("_DecodeSID() " & @CRLF)
	$Revision = StringMid($InputData, $StartOffset, 2)
	$Revision = Dec($Revision)
	If $Revision <> 1 Then
		ConsoleWrite("Error: Revision invalid: " & $Revision & @CRLF)
		Return SetError(1,0,0)
	EndIf
	$SIDString &= "-" & $Revision
	$SubAuthorityCount = StringMid($InputData, $StartOffset + 2, 2)
	$SubAuthorityCount = Dec($SubAuthorityCount)
	If $SubAuthorityCount > 15 Then
		ConsoleWrite("Error: SubAuthorityCount invalid: " & $SubAuthorityCount & @CRLF)
		Return SetError(1,0,0)
	EndIf
	;SID_IDENTIFIER_AUTHORITY
	$IdentifierAuthority = StringMid($InputData, $StartOffset + 4, 12)
;	ConsoleWrite("$IdentifierAuthority: " & $IdentifierAuthority & @CRLF)
	$IdentifierAuthorityString = _DecodeSidIdentifierAuthorityString($IdentifierAuthority)

	$IdentifierAuthority = _DecodeSidIdentifierAuthority($IdentifierAuthority)

	$SIDString &= "-" & $IdentifierAuthority
	;SubAuthority (variable)
	If $SubAuthorityCount < 1 Or $SubAuthorityCount > 15 Then
		ConsoleWrite("Error: $SubAuthorityCount seems invalid: " & $SubAuthorityCount & @CRLF)
		Return SetError(1,0,0)
	EndIf
	For $j = 1 To $SubAuthorityCount
		$SubAuthority = StringMid($InputData, $StartOffset + (($j-1)*8) + 16, 8)
;		ConsoleWrite("$SubAuthority: " & $SubAuthority & @CRLF)
		$SIDString &= "-" & Dec(_SwapEndian($SubAuthority),2)
	Next
	#cs
	ConsoleWrite("$Revision: " & $Revision & @CRLF)
	ConsoleWrite("$SubAuthorityCount: " & $SubAuthorityCount & @CRLF)
	ConsoleWrite("$IdentifierAuthorityString: " & $IdentifierAuthorityString & @CRLF)
	ConsoleWrite("$IdentifierAuthority: " & $IdentifierAuthority & @CRLF)
	ConsoleWrite("$SIDString: " & $SIDString & @CRLF)
	#ce
	Return $SIDString
EndFunc

Func _DecodeSidIdentifierAuthority($InputData)
;	ConsoleWrite("_DecodeSidIdentifierAuthority() " & @CRLF)
	Select
		Case $InputData = "000000000000"
			Return Dec($InputData)
;			Return "0"
		Case $InputData = "000000000001"
			Return Dec($InputData)
;			Return "1"
		Case $InputData = "000000000002"
			Return Dec($InputData)
;			Return "2"
		Case $InputData = "000000000003"
			Return Dec($InputData)
;			Return "3"
		Case $InputData = "000000000004"
			Return Dec($InputData)
;			Return "4"
		Case $InputData = "000000000005"
			Return Dec($InputData)
;			Return "5"
		Case $InputData = "00000000000F"
			Return Dec($InputData)
;			Return "F"
		Case $InputData = "000000000010"
			Return Dec($InputData)
;			Return "10"
		Case $InputData = "000000000011"
			Return Dec($InputData)
;			Return "11"
		Case $InputData = "000000000012"
			Return Dec($InputData)
;			Return "12"
		Case $InputData = "000000000013"
			Return Dec($InputData)
;			Return "13"
		Case Else
			Return "UNKNOWN"
	EndSelect
EndFunc

Func _DecodeSidIdentifierAuthorityString($InputData)
;	ConsoleWrite("_DecodeSidIdentifierAuthorityString() " & @CRLF)
	Select
		Case $InputData = "000000000000"
			Return "NULL_SID_AUTHORITY"
		Case $InputData = "000000000001"
			Return "WORLD_SID_AUTHORITY"
		Case $InputData = "000000000002"
			Return "LOCAL_SID_AUTHORITY"
		Case $InputData = "000000000003"
			Return "CREATOR_SID_AUTHORITY"
		Case $InputData = "000000000004"
			Return "NON_UNIQUE_AUTHORITY"
		Case $InputData = "000000000005"
			Return "SECURITY_NT_AUTHORITY"
		Case $InputData = "00000000000F"
			Return "SECURITY_APP_PACKAGE_AUTHORITY"
		Case $InputData = "000000000010"
			Return "SECURITY_MANDATORY_LABEL_AUTHORITY"
		Case $InputData = "000000000011"
			Return "SECURITY_SCOPED_POLICY_ID_AUTHORITY"
		Case $InputData = "000000000012"
			Return "SECURITY_AUTHENTICATION_AUTHORITY"
		Case $InputData = "000000000013"
			Return "SECURITY_PROCESS_TRUST_AUTHORITY"
		Case Else
			Return "UNKNOWN"
	EndSelect
EndFunc

Func _DecodeIndxEntriesSDH($InputData)
	Local $StartOffset = 1, $Counter = 0
	Local $InputDataSize = BinaryLen("0x"&$InputData)
	ReDim $SDHArray[100+1+$InputDataSize/48][6]
	$SDHArray[0][0] = "OffsetInSDS"
	$SDHArray[0][1] = "SizeInSDS"
	$SDHArray[0][2] = "SecurityDescriptorHashKey"
	$SDHArray[0][3] = "SecurityIdKey"
	$SDHArray[0][4] = "SecurityDescriptorHashData"
	$SDHArray[0][5] = "SecurityIdData"

;	_ArrayDisplay($SDHArray,"$SDHArray")
;	ConsoleWrite("_DecodeIndxEntriesSDH() " & @CRLF)
;	ConsoleWrite("Input size: " & $InputDataSize & @CRLF)
;	ConsoleWrite("$InputData: " & @CRLF)
;	ConsoleWrite(_HexEncode("0x"&$InputData))

	$MaxDescriptors=UBound($SDHArray)-101
	$begin = TimerInit()
	AdlibRegister("_SDHProgress", 500)
	While 1
		If $StartOffset >= $InputDataSize*2 Then ExitLoop
		$Counter+=1
		$CurrentDescriptor=$Counter

		$DataOffset = StringMid($InputData, $StartOffset, 4)
		$DataOffset = _SwapEndian($DataOffset)

		$DataSize = StringMid($InputData, $StartOffset + 4, 4)
		$DataSize = _SwapEndian($DataSize)

		If $DataOffset = 0 Or $DataSize = 0 Then $StartOffset+=16

		;Padding 4 bytes
		$IndexEntrySize = StringMid($InputData, $StartOffset + 16, 4)
		$IndexEntrySize = _SwapEndian($IndexEntrySize)

		$IndexKeySize = StringMid($InputData, $StartOffset + 20, 4)
		$IndexKeySize = _SwapEndian($IndexKeySize)

		$Flags = StringMid($InputData, $StartOffset + 24, 4)
		$Flags = _SwapEndian($Flags)

		;Padding 2 bytes
		;Start of SDH index entry
	;	$StartOffset = $StartOffset+24
		$SecurityDescriptorHashKey = StringMid($InputData, $StartOffset + 32, 8)
;		$SecurityDescriptorHashKey = _SwapEndian($SecurityDescriptorHashKey)

		$SecurityIdKey = StringMid($InputData, $StartOffset + 40, 8)
		$SecurityIdKey = _SwapEndian($SecurityIdKey)

		$SecurityDescriptorHashData = StringMid($InputData, $StartOffset + 48, 8)
;		$SecurityDescriptorHashData = _SwapEndian($SecurityDescriptorHashData)

		$SecurityIdData = StringMid($InputData, $StartOffset + 56, 8)
		$SecurityIdData = _SwapEndian($SecurityIdData)

		$OffsetInSDS = StringMid($InputData, $StartOffset + 64, 16)
		$OffsetInSDS = _SwapEndian($OffsetInSDS)

		$SizeInSDS = StringMid($InputData, $StartOffset + 80, 8)
		$SizeInSDS = _SwapEndian($SizeInSDS)

		$EndPadding = StringMid($InputData, $StartOffset + 88, 8)
		If $EndPadding <> "49004900" Then
			ConsoleWrite("Wrong end padding (49004900): " & $EndPadding & @CRLF)
;			Return
		EndIf
		$SDHArray[$Counter][0] = $OffsetInSDS
		$SDHArray[$Counter][1] = $SizeInSDS
		$SDHArray[$Counter][2] = $SecurityDescriptorHashKey
		$SDHArray[$Counter][3] = $SecurityIdKey
		$SDHArray[$Counter][4] = $SecurityDescriptorHashData
		$SDHArray[$Counter][5] = $SecurityIdData
		#cs
		ConsoleWrite(@CRLF)
		ConsoleWrite("$DataOffset: " & $DataOffset & @CRLF)
		ConsoleWrite("$DataSize: " & $DataSize & @CRLF)
		ConsoleWrite("$IndexEntrySize: " & $IndexEntrySize & @CRLF)
		ConsoleWrite("$IndexKeySize: " & $IndexKeySize & @CRLF)
		ConsoleWrite("$Flags: " & $Flags & @CRLF)
		ConsoleWrite("$SecurityDescriptorHashKey: " & $SecurityDescriptorHashKey & @CRLF)
		ConsoleWrite("$SecurityIdKey: " & $SecurityIdKey & @CRLF)
		ConsoleWrite("$SecurityDescriptorHashData: " & $SecurityDescriptorHashData & @CRLF)
		ConsoleWrite("$SecurityIdData: " & $SecurityIdData & @CRLF)
		ConsoleWrite("$OffsetInSDS: " & $OffsetInSDS & @CRLF)
		ConsoleWrite("$SizeInSDS: " & $SizeInSDS & @CRLF)
		#ce
		$StartOffset += 96
	WEnd
	$MaxDescriptors = $CurrentDescriptor
	AdlibUnRegister("_SDHProgress")
	GUICtrlSetData($ProgressStatus, "[$SDH] Processing security descriptor index entry " & $CurrentDescriptor & " of " & $MaxDescriptors)
	GUICtrlSetData($ElapsedTime, "Elapsed time = " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)))
	GUICtrlSetData($ProgressSDH, 100 * $CurrentDescriptor / $MaxDescriptors)
	_DisplayInfo("$SDH processing finished in " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)) & @CRLF)
	ReDim $SDHArray[$Counter+1][6]
EndFunc

Func _DecodeIndxEntriesSII($InputData)
	Local $StartOffset = 1, $Counter = 0
	Local $InputDataSize = BinaryLen("0x"&$InputData)
	ReDim $SIIArray[100+1+$InputDataSize/40][5]
	$SIIArray[0][0] = "OffsetInSDS"
	$SIIArray[0][1] = "SizeInSDS"
	$SIIArray[0][2] = "SecurityIdKey"
	$SIIArray[0][3] = "SecurityDescriptorHashData"
	$SIIArray[0][4] = "SecurityIdData"
;	ConsoleWrite("_DecodeIndxEntriesSII() " & @CRLF)
;	ConsoleWrite("Input size: " & BinaryLen("0x"&$InputData) & @CRLF)
;	ConsoleWrite("$InputData: " & @CRLF)
;	ConsoleWrite(_HexEncode("0x"&$InputData))

	$MaxDescriptors=UBound($SIIArray)-101
	$begin = TimerInit()
	AdlibRegister("_SIIProgress", 500)
	While 1
		If $StartOffset >= BinaryLen("0x"&$InputData)*2 Then ExitLoop
		$Counter+=1
		$CurrentDescriptor=$Counter

		$DataOffset = StringMid($InputData, $StartOffset, 4)
		$DataOffset = _SwapEndian($DataOffset)

		$DataSize = StringMid($InputData, $StartOffset + 4, 4)
		$DataSize = _SwapEndian($DataSize)

		If $DataOffset = 0 Or $DataSize = 0 Then $StartOffset+=16

		;Padding 4 bytes
		$IndexEntrySize = StringMid($InputData, $StartOffset + 16, 4)
		$IndexEntrySize = _SwapEndian($IndexEntrySize)

		$IndexKeySize = StringMid($InputData, $StartOffset + 20, 4)
		$IndexKeySize = _SwapEndian($IndexKeySize)

		$Flags = StringMid($InputData, $StartOffset + 24, 4)
		$Flags = _SwapEndian($Flags)

		;Padding 2 bytes
		$SecurityIdKey = StringMid($InputData, $StartOffset + 32, 8)
		$SecurityIdKey = _SwapEndian($SecurityIdKey)

		$SecurityDescriptorHashData = StringMid($InputData, $StartOffset + 40, 8)
;		$SecurityDescriptorHashData = _SwapEndian($SecurityDescriptorHashData)

		$SecurityIdData = StringMid($InputData, $StartOffset + 48, 8)
		$SecurityIdData = _SwapEndian($SecurityIdData)

		$OffsetInSDS = StringMid($InputData, $StartOffset + 56, 16)
		$OffsetInSDS = _SwapEndian($OffsetInSDS)

		$SizeInSDS = StringMid($InputData, $StartOffset + 72, 8)
		$SizeInSDS = _SwapEndian($SizeInSDS)

		$SIIArray[$Counter][0] = $OffsetInSDS
		$SIIArray[$Counter][1] = $SizeInSDS
		$SIIArray[$Counter][2] = $SecurityIdKey
		$SIIArray[$Counter][3] = $SecurityDescriptorHashData
		$SIIArray[$Counter][4] = $SecurityIdData
		#cs
		ConsoleWrite(@CRLF)
		ConsoleWrite("$DataOffset: " & $DataOffset & @CRLF)
		ConsoleWrite("$DataSize: " & $DataSize & @CRLF)
		ConsoleWrite("$IndexEntrySize: " & $IndexEntrySize & @CRLF)
		ConsoleWrite("$IndexKeySize: " & $IndexKeySize & @CRLF)
		ConsoleWrite("$Flags: " & $Flags & @CRLF)
		ConsoleWrite("$SecurityIdKey: " & $SecurityIdKey & @CRLF)
		ConsoleWrite("$SecurityDescriptorHashData: " & $SecurityDescriptorHashData & @CRLF)
		ConsoleWrite("$SecurityIdData: " & $SecurityIdData & @CRLF)
		ConsoleWrite("$OffsetInSDS: " & $OffsetInSDS & @CRLF)
		ConsoleWrite("$SizeInSDS: " & $SizeInSDS & @CRLF)
		#ce
		$StartOffset += 80
	WEnd
	$MaxDescriptors = $CurrentDescriptor
	AdlibUnRegister("_SIIProgress")
	GUICtrlSetData($ProgressStatus, "[$SII] Processing security descriptor index entry " & $CurrentDescriptor & " of " & $MaxDescriptors)
	GUICtrlSetData($ElapsedTime, "Elapsed time = " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)))
	GUICtrlSetData($ProgressSII, 100 * $CurrentDescriptor / $MaxDescriptors)
	_DisplayInfo("$SII processing finished in " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)) & @CRLF)
	ReDim $SIIArray[$Counter+1][5]
EndFunc

Func _SwapEndian($iHex)
	Return StringMid(Binary(Dec($iHex,2)),3, StringLen($iHex))
EndFunc

Func _HexEncode($bInput)
   Local $tInput = DllStructCreate("byte[" & BinaryLen($bInput) & "]")
   DllStructSetData($tInput, 1, $bInput)
   Local $a_iCall = DllCall("crypt32.dll", "int", "CryptBinaryToString", _
	  "ptr", DllStructGetPtr($tInput), _
	  "dword", DllStructGetSize($tInput), _
	  "dword", 11, _
	  "ptr", 0, _
	  "dword*", 0)

   If @error Or Not $a_iCall[0] Then
	  Return SetError(1, 0, "")
   EndIf
   Local $iSize = $a_iCall[5]
   Local $tOut = DllStructCreate("char[" & $iSize & "]")
   $a_iCall = DllCall("crypt32.dll", "int", "CryptBinaryToString", _
	  "ptr", DllStructGetPtr($tInput), _
	  "dword", DllStructGetSize($tInput), _
	  "dword", 11, _
	  "ptr", DllStructGetPtr($tOut), _
	  "dword*", $iSize)

   If @error Or Not $a_iCall[0] Then
	  Return SetError(2, 0, "")
   EndIf

   Return SetError(0, 0, DllStructGetData($tOut, 1))
EndFunc

Func _GetIndx($Entry)
;	ConsoleWrite("Starting function _Get_IndexAllocation()" & @crlf)
	Local $NextPosition = 3,$IndxHdrMagic,$IndxEntries,$TotalIndxEntries
;	ConsoleWrite("StringLen of chunk = " & StringLen($Entry) & @crlf)
;	ConsoleWrite("Expected records = " & StringLen($Entry)/8192 & @crlf)
;	$NextPosition = 1
	Do
		$IndxHdrMagic = StringMid($Entry,$NextPosition,8)
;		ConsoleWrite("$IndxHdrMagic = " & $IndxHdrMagic & @crlf)
		$IndxHdrMagic = _HexToString($IndxHdrMagic)
;		ConsoleWrite("$IndxHdrMagic = " & $IndxHdrMagic & @crlf)
		If $IndxHdrMagic <> "INDX" Then
;			ConsoleWrite("$IndxHdrMagic: " & $IndxHdrMagic & @crlf)
			ConsoleWrite("Error: Record is not of type INDX, and this was not expected.." & @crlf)
			$NextPosition += 8192
			ContinueLoop
		EndIf
		$IndxEntries = _StripIndxRecord(StringMid($Entry,$NextPosition,8192))
		$TotalIndxEntries &= $IndxEntries
		$NextPosition += 8192
	Until $NextPosition >= StringLen($Entry)+32
;	ConsoleWrite("INDX record:" & @crlf)
;	ConsoleWrite(_HexEncode("0x"& StringMid($Entry,1)) & @crlf)
;	ConsoleWrite("Total chunk of stripped INDX entries:" & @crlf)
;	ConsoleWrite(_HexEncode("0x"& StringMid($TotalIndxEntries,1)) & @crlf)
;	_DecodeIndxEntriesSDH($TotalIndxEntries)
	Return $TotalIndxEntries
EndFunc

Func _StripIndxRecord($Entry)
;	ConsoleWrite("Starting function _StripIndxRecord()" & @crlf)
	Local $LocalAttributeOffset = 1,$IndxHdrUpdateSeqArrOffset,$IndxHdrUpdateSeqArrSize,$IndxHdrUpdSeqArr,$IndxHdrUpdSeqArrPart0,$IndxHdrUpdSeqArrPart1,$IndxHdrUpdSeqArrPart2,$IndxHdrUpdSeqArrPart3,$IndxHdrUpdSeqArrPart4,$IndxHdrUpdSeqArrPart5,$IndxHdrUpdSeqArrPart6,$IndxHdrUpdSeqArrPart7,$IndxHdrUpdSeqArrPart8
	Local $IndxRecordEnd1,$IndxRecordEnd2,$IndxRecordEnd3,$IndxRecordEnd4,$IndxRecordEnd5,$IndxRecordEnd6,$IndxRecordEnd7,$IndxRecordEnd8,$IndxRecordSize,$IndxHeaderSize,$IsNotLeafNode
;	ConsoleWrite("Unfixed INDX record:" & @crlf)
;	ConsoleWrite(_HexEncode("0x"&$Entry) & @crlf)
;	ConsoleWrite(_HexEncode("0x" & StringMid($Entry,1,4096)) & @crlf)
	$IndxHdrUpdateSeqArrOffset = Dec(_SwapEndian(StringMid($Entry,$LocalAttributeOffset+8,4)))
;	ConsoleWrite("$IndxHdrUpdateSeqArrOffset = " & $IndxHdrUpdateSeqArrOffset & @crlf)
	$IndxHdrUpdateSeqArrSize = Dec(_SwapEndian(StringMid($Entry,$LocalAttributeOffset+12,4)))
;	ConsoleWrite("$IndxHdrUpdateSeqArrSize = " & $IndxHdrUpdateSeqArrSize & @crlf)
	$IndxHdrUpdSeqArr = StringMid($Entry,1+($IndxHdrUpdateSeqArrOffset*2),$IndxHdrUpdateSeqArrSize*2*2)
;	ConsoleWrite("$IndxHdrUpdSeqArr = " & $IndxHdrUpdSeqArr & @crlf)
	$IndxHdrUpdSeqArrPart0 = StringMid($IndxHdrUpdSeqArr,1,4)
	$IndxHdrUpdSeqArrPart1 = StringMid($IndxHdrUpdSeqArr,5,4)
	$IndxHdrUpdSeqArrPart2 = StringMid($IndxHdrUpdSeqArr,9,4)
	$IndxHdrUpdSeqArrPart3 = StringMid($IndxHdrUpdSeqArr,13,4)
	$IndxHdrUpdSeqArrPart4 = StringMid($IndxHdrUpdSeqArr,17,4)
	$IndxHdrUpdSeqArrPart5 = StringMid($IndxHdrUpdSeqArr,21,4)
	$IndxHdrUpdSeqArrPart6 = StringMid($IndxHdrUpdSeqArr,25,4)
	$IndxHdrUpdSeqArrPart7 = StringMid($IndxHdrUpdSeqArr,29,4)
	$IndxHdrUpdSeqArrPart8 = StringMid($IndxHdrUpdSeqArr,33,4)
	$IndxRecordEnd1 = StringMid($Entry,1021,4)
	$IndxRecordEnd2 = StringMid($Entry,2045,4)
	$IndxRecordEnd3 = StringMid($Entry,3069,4)
	$IndxRecordEnd4 = StringMid($Entry,4093,4)
	$IndxRecordEnd5 = StringMid($Entry,5117,4)
	$IndxRecordEnd6 = StringMid($Entry,6141,4)
	$IndxRecordEnd7 = StringMid($Entry,7165,4)
	$IndxRecordEnd8 = StringMid($Entry,8189,4)
	If $IndxHdrUpdSeqArrPart0 <> $IndxRecordEnd1 OR $IndxHdrUpdSeqArrPart0 <> $IndxRecordEnd2 OR $IndxHdrUpdSeqArrPart0 <> $IndxRecordEnd3 OR $IndxHdrUpdSeqArrPart0 <> $IndxRecordEnd4 OR $IndxHdrUpdSeqArrPart0 <> $IndxRecordEnd5 OR $IndxHdrUpdSeqArrPart0 <> $IndxRecordEnd6 OR $IndxHdrUpdSeqArrPart0 <> $IndxRecordEnd7 OR $IndxHdrUpdSeqArrPart0 <> $IndxRecordEnd8 Then
		ConsoleWrite("Error the INDX record is corrupt" & @CRLF)
		Return ; Not really correct because I think in theory chunks of 1024 bytes can be invalid and not just everything or nothing for the given INDX record.
	Else
		$Entry = StringMid($Entry,1,1020) & $IndxHdrUpdSeqArrPart1 & StringMid($Entry,1025,1020) & $IndxHdrUpdSeqArrPart2 & StringMid($Entry,2049,1020) & $IndxHdrUpdSeqArrPart3 & StringMid($Entry,3073,1020) & $IndxHdrUpdSeqArrPart4 & StringMid($Entry,4097,1020) & $IndxHdrUpdSeqArrPart5 & StringMid($Entry,5121,1020) & $IndxHdrUpdSeqArrPart6 & StringMid($Entry,6145,1020) & $IndxHdrUpdSeqArrPart7 & StringMid($Entry,7169,1020)
	EndIf
	$IndxRecordSize = Dec(_SwapEndian(StringMid($Entry,$LocalAttributeOffset+56,8)),2)
;	ConsoleWrite("$IndxRecordSize = " & $IndxRecordSize & @crlf)
	$IndxHeaderSize = Dec(_SwapEndian(StringMid($Entry,$LocalAttributeOffset+48,8)),2)
;	ConsoleWrite("$IndxHeaderSize = " & $IndxHeaderSize & @crlf)
	$IsNotLeafNode = StringMid($Entry,$LocalAttributeOffset+72,2) ;1 if not leaf node
	$Entry = StringMid($Entry,$LocalAttributeOffset+48+($IndxHeaderSize*2),($IndxRecordSize-$IndxHeaderSize-16)*2)
	If $IsNotLeafNode = "01" Then  ; This flag leads to the entry being 8 bytes of 00's longer than the others. Can be stripped I think.
		$Entry = StringTrimRight($Entry,16)
;		ConsoleWrite("Is not leaf node..." & @crlf)
	EndIf
	Return $Entry
EndFunc

Func _WriteCSVHeader()
	$Secure_Csv_Header = "Offset"&$de&"SecurityDescriptorHash"&$de&"SecurityId"&$de&"Control"&$de&"SidOwner"&$de&"SidGroup"&$de&"SAclRevision"&$de&"SAceCount"&$de&"SAceType"&$de&"SAceFlags"&$de&"SAceMask"&$de&"SAceObjectFlags"&$de&"SAceObjectType"&$de&"SAceInheritedObjectType"&$de&"SAceSIDofTrustee"&$de&"DAclRevision"&$de&"DAceCount"&$de&"DAceType"&$de&"DAceFlags"&$de&"DAceMask"&$de&"DAceObjectFlags"&$de&"DAceObjectType"&$de&"DAceInheritedObjectType"&$de&"DAceSIDofTrustee"
	FileWriteLine($hSecureCsv, $Secure_Csv_Header & @CRLF)
EndFunc

Func _WriteCsv()
	If $WithQuotes Then
		FileWriteLine($hSecureCsv, '"'&$TargetSDSOffsetHex&'"'&$de&'"'&$SecurityDescriptorHash&'"'&$de&'"'&$SecurityId&'"'&$de&'"'&$ControlText&'"'&$de&'"'&$SidOwner&'"'&$de&'"'&$SidGroup&'"'&$de&'"'&$SAclRevision&'"'&$de&'"'&$SAceCount&'"'&$de&'"'&$SAceTypeText&'"'&$de&'"'&$SAceFlagsText&'"'&$de&'"'&$SAceMask&'"'&$de&'"'&$SAceObjectFlagsText&'"'&$de&'"'&$SAceObjectType&'"'&$de&'"'&$SAceInheritedObjectType&'"'&$de&'"'&$SAceSIDString&'"'&$de&'"'&$DAclRevision&'"'&$de&'"'&$DAceCount&'"'&$de&'"'&$DAceTypeText&'"'&$de&'"'&$DAceFlagsText&'"'&$de&'"'&$DAceMask&'"'&$de&'"'&$DAceObjectFlagsText&'"'&$de&'"'&$DAceObjectType&'"'&$de&'"'&$DAceInheritedObjectType&'"'&$de&'"'&$DAceSIDString&'"'&@CRLF)
	Else
		FileWriteLine($hSecureCsv, $TargetSDSOffsetHex&$de&$SecurityDescriptorHash&$de&$SecurityId&$de&$ControlText&$de&$SidOwner&$de&$SidGroup&$de&$SAclRevision&$de&$SAceCount&$de&$SAceTypeText&$de&$SAceFlagsText&$de&$SAceMask&$de&$SAceObjectFlagsText&$de&$SAceObjectType&$de&$SAceInheritedObjectType&$de&$SAceSIDString&$de&$DAclRevision&$de&$DAceCount&$de&$DAceTypeText&$de&$DAceFlagsText&$de&$DAceMask&$de&$DAceObjectFlagsText&$de&$DAceObjectType&$de&$DAceInheritedObjectType&$de&$DAceSIDString&@crlf)
	EndIf
EndFunc

Func _ClearVar()
	$TargetSDSOffsetHex = ""
	$SecurityDescriptorHash = ""
	$SecurityId = ""
	$ControlText = ""
	$SidOwner = ""
	$SidGroup = ""
	$SAclRevision = ""
	$SAceCount = ""
	$SAceTypeText = ""
	$SAceFlagsText = ""
	$SAceMask = ""
	$SAceObjectType = ""
	$SAceInheritedObjectType = ""
	$SAceSIDString = ""
	$SAceObjectFlagsText = ""
	$DAclRevision = ""
	$DAceCount = ""
	$DAceTypeText = ""
	$DAceFlagsText = ""
	$DAceMask = ""
	$DAceObjectType = ""
	$DAceInheritedObjectType = ""
	$DAceSIDString = ""
	$DAceObjectFlagsText = ""
EndFunc

Func _TranslateSeparator()
	; Or do it the other way around to allow setting other trickier separators, like specifying it in hex
	GUICtrlSetData($SeparatorInput,StringLeft(GUICtrlRead($SeparatorInput),1))
	GUICtrlSetData($SeparatorInput2,"0x"&Hex(Asc(GUICtrlRead($SeparatorInput)),2))
EndFunc

Func _TranslateSeparatorAce()
	; Or do it the other way around to allow setting other trickier separators, like specifying it in hex
	GUICtrlSetData($AceSeparatorInput,StringLeft(GUICtrlRead($AceSeparatorInput),1))
	GUICtrlSetData($AceSeparatorInput2,"0x"&Hex(Asc(GUICtrlRead($AceSeparatorInput)),2))
EndFunc

Func _SelectSDS()
	$SDSFile = FileOpenDialog("Select $SDS",@ScriptDir,"All (*.*)")
	If @error Then
		_DisplayInfo("Error getting $SDS: " & $SDSFile & @CRLF)
		GUICtrlSetData($SDSField,"Error getting $SDS")
	Else
;		_DisplayInfo("Selected $SDS: " & $SDSFile & @CRLF)
		GUICtrlSetData($SDSField,$SDSFile)
	EndIf
EndFunc

Func _SelectSDH()
	$SDHFile = FileOpenDialog("Select $SDH",@ScriptDir,"All (*.*)")
	If @error Then
		_DisplayInfo("Error getting $SDH: " & $SDHFile & @CRLF)
		GUICtrlSetData($SDHField,"Error getting $SDH")
		$DoSDH=0
	Else
;		_DisplayInfo("Selected $SDH: " & $SDHFile & @CRLF)
		GUICtrlSetData($SDHField,$SDHFile)
		$DoSDH=1
	EndIf
EndFunc

Func _SelectSII()
	$SIIFile = FileOpenDialog("Select $SII",@ScriptDir,"All (*.*)")
	If @error Then
		_DisplayInfo("Error getting $SII: " & $SIIFile & @CRLF)
		GUICtrlSetData($SIIField,"Error getting $SII")
		$DoSII=0
	Else
;		_DisplayInfo("Selected $SII: " & $SIIFile & @CRLF)
		GUICtrlSetData($SIIField,$SIIFile)
		$DoSII=1
	EndIf
EndFunc

Func _DisplayInfo($DebugInfo)
	GUICtrlSetData($myctredit, $DebugInfo, 1)
EndFunc

Func _SDSProgress()
    GUICtrlSetData($ProgressStatus, "[$SDS] Processing security descriptor " & $CurrentDescriptor & " of " & $MaxDescriptors)
    GUICtrlSetData($ElapsedTime, "Elapsed time = " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)))
	GUICtrlSetData($ProgressSDS, 100 * $CurrentDescriptor / $MaxDescriptors)
EndFunc

Func _SDHProgress()
    GUICtrlSetData($ProgressStatus, "[$SDH] Processing security descriptor index entry " & $CurrentDescriptor & " of " & $MaxDescriptors)
    GUICtrlSetData($ElapsedTime, "Elapsed time = " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)))
	GUICtrlSetData($ProgressSDH, 100 * $CurrentDescriptor / $MaxDescriptors)
EndFunc

Func _SIIProgress()
    GUICtrlSetData($ProgressStatus, "[$SII] Processing security descriptor index entry " & $CurrentDescriptor & " of " & $MaxDescriptors)
    GUICtrlSetData($ElapsedTime, "Elapsed time = " & _WinAPI_StrFromTimeInterval(TimerDiff($begin)))
	GUICtrlSetData($ProgressSII, 100 * $CurrentDescriptor / $MaxDescriptors)
EndFunc

Func _HexToGuidStr($input)
	;{4b-2b-2b-2b-6b}
	Local $OutStr
	If Not StringLen($input) = 32 Then Return $input
	$OutStr = "{"
	$OutStr &= _SwapEndian(StringMid($input,1,8)) & "-"
	$OutStr &= _SwapEndian(StringMid($input,9,4)) & "-"
	$OutStr &= _SwapEndian(StringMid($input,13,4)) & "-"
	$OutStr &= StringMid($input,17,4) & "-"
	$OutStr &= StringMid($input,21,12)
	$OutStr &= "}"
	Return $OutStr
EndFunc
