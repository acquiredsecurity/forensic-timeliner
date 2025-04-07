Sub ColorRowsByArtifactName_Simple()
    Dim ws As Worksheet
    Dim lastRow As Long
    Dim i As Long
    Dim colorMap As Object, fontColorMap As Object
    Dim artifactName As String, infoValue As String
    Dim infoColumn As Long
    
    ' Set the active worksheet
    Set ws = ActiveSheet
    
    ' Find the last used row in column C
    lastRow = ws.Cells(ws.Rows.Count, 3).End(xlUp).Row
    
    ' Exit if no data
    If lastRow < 3 Then Exit Sub
    
    ' Find the Info column
    infoColumn = 0
    For col = 1 To 10 ' Search first 10 columns
        If ws.Cells(1, col).Value = "Info" Then
            infoColumn = col
            Exit For
        End If
    Next col
    
    ' If Info column not found, assume it's column 4 (D)
    If infoColumn = 0 Then infoColumn = 4
    
    ' Disable screen updating & calculations to speed up processing
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    
    ' Create dictionaries for artifact colors
    Set colorMap = CreateObject("Scripting.Dictionary")
    Set fontColorMap = CreateObject("Scripting.Dictionary")

    ' Assign background colors to each artifact name (sorted alphabetically)
    If Not colorMap.Exists("Amcache") Then colorMap.Add "Amcache", RGB(135, 206, 235) ' Sky Blue
    If Not colorMap.Exists("AppCompatCache") Then colorMap.Add "AppCompatCache", RGB(255, 223, 186) ' Peach
    If Not colorMap.Exists("ChromeHistory") Then colorMap.Add "ChromeHistory", RGB(64, 64, 64) ' Dark Gray
    If Not colorMap.Exists("EdgeIEHistory") Then colorMap.Add "EdgeIEHistory", RGB(0, 255, 255) ' Cyan
    If Not colorMap.Exists("EventLogs") Then colorMap.Add "EventLogs", RGB(184, 134, 11) ' Earthy Gold
    If Not colorMap.Exists("FileDeletion") Then colorMap.Add "FileDeletion", RGB(139, 0, 0) ' Dark Red
    If Not colorMap.Exists("JumpLists") Then colorMap.Add "JumpLists", RGB(64, 224, 208) ' Turquoise
    If Not colorMap.Exists("LNKFiles") Then colorMap.Add "LNKFiles", RGB(0, 128, 128) ' Teal
    If Not colorMap.Exists("MFT") Then colorMap.Add "MFT", RGB(65, 105, 225) ' Royal Blue
    If Not colorMap.Exists("mft") Then colorMap.Add "mft", RGB(255, 0, 0) ' Bright red
    If Not colorMap.Exists("PrefetchFiles") Then colorMap.Add "PrefetchFiles", RGB(255, 140, 0) ' Dark Orange
    If Not colorMap.Exists("Registry") Then colorMap.Add "Registry", RGB(0, 100, 0) ' Dark Green
    If Not colorMap.Exists("Registry - AutoRun Items") Then colorMap.Add "Registry - AutoRun Items", RGB(139, 0, 0) ' Dark Red
    If Not colorMap.Exists("Registry - MRU Folder Access") Then colorMap.Add "Registry - MRU Folder Access", RGB(255, 223, 186) ' Peach
    If Not colorMap.Exists("Registry - MRU Opened-Saved Files") Then colorMap.Add "Registry - MRU Opened-Saved Files", RGB(70, 130, 180) ' Steel Blue
    If Not colorMap.Exists("Registry - MRU Recent Files & Folders") Then colorMap.Add "Registry - MRU Recent Files & Folders", RGB(255, 102, 102) ' Light Red
    If Not colorMap.Exists("Registry - UserAssist") Then colorMap.Add "Registry - UserAssist", RGB(135, 206, 250) ' Light Sky Blue
    If Not colorMap.Exists("RecycleBin") Then colorMap.Add "RecycleBin", RGB(0, 0, 255) ' Blue
    If Not colorMap.Exists("Shellbags") Then colorMap.Add "Shellbags", RGB(255, 99, 0) ' Vivid Orange
    If Not colorMap.Exists("sigma") Then colorMap.Add "sigma", RGB(153, 50, 204) ' Dark Orchid (Purple)
    If Not colorMap.Exists("WebHistory - Brave") Then colorMap.Add "WebHistory - Brave", RGB(255, 165, 0) ' Orange
    If Not colorMap.Exists("WebHistory - Edge (Chromium-based)") Then colorMap.Add "WebHistory - Edge (Chromium-based)", RGB(144, 238, 144) ' Light Green
    If Not colorMap.Exists("WebHistory - Internet Explorer 10/11 / Edge") Then colorMap.Add "WebHistory - Internet Explorer 10/11 / Edge", RGB(173, 216, 230) ' Light Blue
    If Not colorMap.Exists("microsoft_rds_events_-_user_profile_disk") Then colorMap.Add "microsoft_rds_events_-_user_profile_disk", RGB(0, 255, 127) ' Spring Green
    If Not colorMap.Exists("powershell_engine_state") Then colorMap.Add "powershell_engine_state", RGB(255, 192, 203) ' Pink
    If Not colorMap.Exists("powershell_script") Then colorMap.Add "powershell_script", RGB(165, 42, 42) ' Brown
    If Not colorMap.Exists("persistence") Then colorMap.Add "persistence", RGB(255, 99, 71) ' Tomato Red
    If Not colorMap.Exists("rdp_events") Then colorMap.Add "rdp_events", RGB(0, 255, 0) ' Lime
    If Not colorMap.Exists("indicator_removal") Then colorMap.Add "indicator_removal", RGB(255, 0, 255) ' Magenta
    If Not colorMap.Exists("Hayabusa") Then colorMap.Add "Hayabusa", RGB(99, 100, 0)  ' Dark Green (for Hayabusa tool)

    ' Assign contrasting font colors to each artifact name (sorted alphabetically)
    If Not fontColorMap.Exists("Amcache") Then fontColorMap.Add "Amcache", RGB(0, 0, 0) ' Black
    If Not fontColorMap.Exists("AppCompatCache") Then fontColorMap.Add "AppCompatCache", RGB(0, 0, 0) ' Black
    If Not fontColorMap.Exists("EdgeIEHistory") Then fontColorMap.Add "EdgeIEHistory", RGB(0, 0, 0) ' Black
    If Not fontColorMap.Exists("ChromeHistory") Then fontColorMap.Add "ChromeHistory", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("EventLogs") Then fontColorMap.Add "EventLogs", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("FileDeletion") Then fontColorMap.Add "FileDeletion", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("JumpLists") Then fontColorMap.Add "JumpLists", RGB(0, 0, 0) ' Black
    If Not fontColorMap.Exists("LNKFiles") Then fontColorMap.Add "LNKFiles", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("MFT") Then fontColorMap.Add "MFT", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("mft") Then fontColorMap.Add "mft", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("PrefetchFiles") Then fontColorMap.Add "PrefetchFiles", RGB(0, 0, 0) ' Black
    If Not fontColorMap.Exists("powershell_script") Then fontColorMap.Add "powershell_script)", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("Registry") Then fontColorMap.Add "Registry", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("Registry - AutoRun Items") Then fontColorMap.Add "Registry - AutoRun Items", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("Registry - MRU Folder Access") Then fontColorMap.Add "Registry - MRU Folder Access", RGB(0, 0, 0) ' Black
    If Not fontColorMap.Exists("Registry - MRU Opened-Saved Files") Then fontColorMap.Add "Registry - MRU Opened-Saved Files", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("Registry - MRU Recent Files & Folders") Then fontColorMap.Add "Registry - MRU Recent Files & Folders", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("Registry - UserAssist") Then fontColorMap.Add "Registry - UserAssist", RGB(0, 0, 0) ' Black
    If Not fontColorMap.Exists("RecycleBin") Then fontColorMap.Add "RecycleBin", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("Shellbags") Then fontColorMap.Add "Shellbags", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("sigma") Then fontColorMap.Add "sigma", RGB(255, 255, 255) ' White
    If Not fontColorMap.Exists("WebHistory - Brave") Then fontColorMap.Add "WebHistory - Brave", RGB(0, 0, 0) ' Black
    If Not fontColorMap.Exists("WebHistory - Edge (Chromium-based)") Then fontColorMap.Add "WebHistory - Edge (Chromium-based)", RGB(0, 0, 0) ' Black
    If Not fontColorMap.Exists("WebHistory - Internet Explorer 10/11 / Edge") Then fontColorMap.Add "WebHistory - Internet Explorer 10/11 / Edge", RGB(0, 0, 0) ' Black
    If Not fontColorMap.Exists("microsoft_rds_events_-_user_profile_disk") Then fontColorMap.Add "microsoft_rds_events_-_user_profile_disk", RGB(0, 0, 0)

 ' Process each row
For i = 3 To lastRow
    artifactName = ws.Cells(i, 3).Value
    infoValue = ws.Cells(i, infoColumn).Value
    toolName = ws.Cells(i, 4).Value  ' Assuming column D (4) contains the tool name (EZ Tools, Axiom, Hayabusa, etc.)

    Dim matchedColorKey As String
    Dim foundColorMatch As Boolean
    foundColorMatch = False

    ' Match exactly with artifact names in colorMap
    For Each key In colorMap.Keys
        If artifactName = key Then
            matchedColorKey = key
            foundColorMatch = True
            Exit For
        End If
    Next

    Dim rowColor As Long
    Dim rowFontColor As Long
    If foundColorMatch Then
        rowColor = colorMap(matchedColorKey)
        rowFontColor = fontColorMap(matchedColorKey)
    Else
        ' Default color if no match found (e.g., light gray or any color you prefer)
        rowColor = RGB(240, 240, 240) ' Light Gray for unmatched artifacts
        rowFontColor = RGB(0, 0, 0) ' Black font color for unmatched rows
    End If

    ' If the tool is "EZ Tools", light the color slightly
    If toolName = "EZ Tools" Then
        rowColor = AdjustColor(rowColor, 30) ' Lighten the color by 30 units
    End If

    ' If the tool is "Hayabusa", light the color slightly (or apply different adjustment)
    If toolName = "Hayabusa" Then
        rowColor = AdjustColor(rowColor, 20) ' Lighten the color by 20 units for Hayabusa (can adjust the value)
    End If

    ' Apply color variations for LNKFiles
    If artifactName = "LNKFiles" Then
        If infoValue = "Source Created" Or infoValue = "Sourced Created" Then
            rowColor = AdjustColor(rowColor, 20)
        ElseIf infoValue = "Target Modified" Then
            rowColor = AdjustColor(rowColor, -20)
        End If
    End If

    ' Apply color variations for Shellbags
    If artifactName = "Shellbags" Then
        If infoValue = "First Interacted" Then
            rowColor = AdjustColor(rowColor, 20)
        ElseIf infoValue = "Last Interacted" Then
            rowColor = AdjustColor(rowColor, -20)
        End If
    End If

    ' Format the entire row
    With ws.Range("A" & i & ":X" & i)
        .Interior.Color = rowColor
        .Font.Color = rowFontColor
    End With

    ' Allow Excel to breathe every 1000 rows
    If i Mod 1000 = 0 Then
        DoEvents
    End If
Next i
 
    ' NEW: Color Hayabusa rows with dark green after initial coloring
    For i = 3 To lastRow
    ' Check if the text "Hayabusa" is found in column 4 (Tool)
    If InStr(1, ws.Cells(i, 4).Value, "Hayabusa", vbTextCompare) > 0 Then
        With ws.Range("A" & i & ":X" & i)
            .Interior.color = RGB(99, 100, 0)  ' Dark Green background
            .Font.color = RGB(255, 255, 255)  ' White text
        End With
    End If
Next i
    
    ' Restore Excel performance settings
    Application.ScreenUpdating = True
    Application.Calculation = xlCalculationAutomatic
    
    ' Format header row with black background and white text
    With ws.Range("A1:X1")
        .Interior.color = RGB(0, 0, 0)
        .Font.color = RGB(255, 255, 255)
        .Font.Bold = True
    End With

    MsgBox "Row coloring complete!", vbInformation
End Sub

' Helper function to adjust color brightness
Function AdjustColor(baseColor As Long, adjustment As Integer) As Long
    ' Extract RGB components
    Dim r As Integer, g As Integer, b As Integer
    r = baseColor Mod 256
    g = (baseColor \ 256) Mod 256
    b = (baseColor \ 65536)
    
    ' Apply adjustment
    r = Application.Max(0, Application.Min(255, r + adjustment))
    g = Application.Max(0, Application.Min(255, g + adjustment))
    b = Application.Max(0, Application.Min(255, b + adjustment))
    
    ' Return adjusted color
    AdjustColor = RGB(r, g, b)
End Function
