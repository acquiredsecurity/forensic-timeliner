Sub ColorRowsByArtifactName_Simple()
    Dim ws As Worksheet
    Dim lastRow As Long
    Dim i As Long
    Dim colorMap As Object, fontColorMap As Object
    Dim artifactName As String, infoValue As String
    Dim infoColumn As Long
    
    ' Set the active worksheet
    Set ws = ActiveSheet
    
    ' Find the last used row in column B
    lastRow = ws.Cells(ws.Rows.Count, 2).End(xlUp).Row
    
    ' Exit if no data
    If lastRow < 2 Then Exit Sub
    
    ' Find the Info column (normally column D, but let's verify)
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

    ' Assign background colors - SORTED ALPHABETICALLY
    colorMap.Add "account_tampering", RGB(0, 0, 255) ' Blue
    colorMap.Add "Amcache", RGB(135, 206, 235) ' Sky Blue
    colorMap.Add "antivirus", RGB(0, 128, 0) ' Green
    colorMap.Add "AppCompatCache", RGB(176, 224, 230) ' Powder Blue
    colorMap.Add "EventLogs", RGB(153, 50, 204) ' Dark Orchid
    colorMap.Add "FileDeletion", RGB(139, 0, 0) ' Dark Red
    colorMap.Add "indicator_removal", RGB(255, 0, 0) ' Red
    colorMap.Add "Jump Lists", RGB(230, 230, 250) ' Lavender
    colorMap.Add "lateral_movement", RGB(255, 165, 0) ' Orange
    colorMap.Add "LNKFiles", RGB(211, 211, 211) ' Light Gray
    colorMap.Add "login_attacks", RGB(255, 255, 0) ' Yellow
    colorMap.Add "MFT", RGB(65, 105, 225) ' Royal Blue
    colorMap.Add "mft", RGB(70, 130, 180) ' Steel Blue
    colorMap.Add "microsoft_rds_events_-_user_profile_disk", RGB(0, 255, 255) ' Cyan
    colorMap.Add "persistence", RGB(128, 128, 0) ' Olive
    colorMap.Add "powershell_engine_state", RGB(255, 192, 203) ' Pink
    colorMap.Add "powershell_script", RGB(165, 42, 42) ' Brown
    colorMap.Add "Prefetch Files", RGB(255, 140, 0) ' Dark Orange
    colorMap.Add "rdp_events", RGB(0, 255, 0) ' Lime
    colorMap.Add "Registry", RGB(0, 100, 0) ' Dark Green
    colorMap.Add "service_installation", RGB(0, 128, 128) ' Teal
    colorMap.Add "Shellbags", RGB(255, 165, 0) ' Orange
    colorMap.Add "sigma", RGB(153, 50, 204) ' Dark Orchid (Purple)
    colorMap.Add "WebHistory", RGB(173, 216, 230) ' Light Blue

    ' Assign contrasting font colors - SORTED ALPHABETICALLY
    fontColorMap.Add "account_tampering", RGB(255, 255, 255) ' White
    fontColorMap.Add "Amcache", RGB(0, 0, 0) ' Black
    fontColorMap.Add "antivirus", RGB(255, 255, 255) ' White
    fontColorMap.Add "AppCompatCache", RGB(0, 0, 0) ' Black
    fontColorMap.Add "EventLogs", RGB(255, 255, 255) ' White
    fontColorMap.Add "FileDeletion", RGB(255, 255, 255) ' White
    fontColorMap.Add "indicator_removal", RGB(255, 255, 255) ' White
    fontColorMap.Add "Jump Lists", RGB(0, 0, 0) ' Black
    fontColorMap.Add "lateral_movement", RGB(0, 0, 0) ' Black
    fontColorMap.Add "LNKFiles", RGB(0, 0, 0) ' Black
    fontColorMap.Add "login_attacks", RGB(0, 0, 0) ' Black
    fontColorMap.Add "MFT", RGB(255, 255, 255) ' White
    fontColorMap.Add "mft", RGB(255, 255, 255) ' White text
    fontColorMap.Add "microsoft_rds_events_-_user_profile_disk", RGB(0, 0, 0) ' Black
    fontColorMap.Add "persistence", RGB(255, 255, 255) ' White
    fontColorMap.Add "powershell_engine_state", RGB(0, 0, 0) ' Black
    fontColorMap.Add "powershell_script", RGB(255, 255, 255) ' White
    fontColorMap.Add "Prefetch Files", RGB(0, 0, 0) ' Black
    fontColorMap.Add "rdp_events", RGB(0, 0, 0) ' Black
    fontColorMap.Add "Registry", RGB(255, 255, 255) ' White
    fontColorMap.Add "service_installation", RGB(255, 255, 255) ' White
    fontColorMap.Add "Shellbags", RGB(0, 0, 0) ' Black
    fontColorMap.Add "sigma", RGB(255, 255, 255) ' White
    fontColorMap.Add "WebHistory", RGB(0, 0, 0) ' Black

    ' Process each row
    For i = 2 To lastRow
        artifactName = ws.Cells(i, 2).Value
        infoValue = ws.Cells(i, infoColumn).Value
        
        If colorMap.Exists(artifactName) Then
            Dim rowColor As Long
            rowColor = colorMap(artifactName)
            
            ' Apply color variations for LNKFiles
            If artifactName = "LNKFiles" Then
                If infoValue = "Source Created" Or infoValue = "Sourced Created" Then
                    ' Lighter variation of LNKFiles color
                    rowColor = AdjustColor(rowColor, 20)
                ElseIf infoValue = "Target Modified" Then
                    ' Darker variation of LNKFiles color
                    rowColor = AdjustColor(rowColor, -20)
                End If
                ' "Target Created" keeps the base color
            End If
            
            ' Apply color variations for Shellbags
            If artifactName = "Shellbags" Then
                If infoValue = "First Interacted" Then
                    ' Lighter variation of Shellbags color
                    rowColor = AdjustColor(rowColor, 20)
                ElseIf infoValue = "Last Interacted" Then
                    ' Darker variation of Shellbags color
                    rowColor = AdjustColor(rowColor, -20)
                End If
                ' "Last Write" keeps the base color
            End If
            
            ' Format the entire row
            With ws.Range("A" & i & ":AC" & i)
                .Interior.Color = rowColor
                .Font.Color = fontColorMap(artifactName)
            End With
        End If
        
        ' Allow Excel to breathe every 1000 rows
        If i Mod 1000 = 0 Then
            DoEvents
        End If
    Next i
    
    ' NEW: Color Hayabusa rows with dark green after initial coloring
    For i = 2 To lastRow
        If InStr(1, ws.Cells(i, 3).Value, "Hayabusa", vbTextCompare) > 0 Then
            With ws.Range("A" & i & ":AC" & i)
                .Interior.Color = RGB(99, 100, 0)  ' Dark Green
                .Font.Color = RGB(255, 255, 255)  ' White text
            End With
        End If
    Next i
    
    ' Restore Excel performance settings
    Application.ScreenUpdating = True
    Application.Calculation = xlCalculationAutomatic
    
    ' Format header row with black background and white text
    With ws.Range("A1:AC1")
        .Interior.Color = RGB(0, 0, 0)
        .Font.Color = RGB(255, 255, 255)
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
