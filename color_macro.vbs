Sub ColorRowsByArtifactName_Simple()
    Dim ws As Worksheet
    Dim lastRow As Long
    Dim i As Long
    Dim colorMap As Object, fontColorMap As Object
    Dim artifactName As String
    
    ' Set the active worksheet
    Set ws = ActiveSheet
    
    ' Find the last used row in column B
    lastRow = ws.Cells(ws.Rows.Count, 2).End(xlUp).Row
    
    ' Exit if no data
    If lastRow < 2 Then Exit Sub
    
    ' Disable screen updating & calculations to speed up processing
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    
    ' Create dictionaries for artifact colors
    Set colorMap = CreateObject("Scripting.Dictionary")
    Set fontColorMap = CreateObject("Scripting.Dictionary")

' Assign background colors - UPDATED WITH NEW ARTIFACT NAMES
colorMap.Add "AmcacheExecution", RGB(135, 206, 235) ' Sky Blue
colorMap.Add "EventLogs", RGB(153, 50, 204) ' Dark Orchid
colorMap.Add "FileDeletion", RGB(139, 0, 0) ' Dark Red
colorMap.Add "LNKFiles", RGB(211, 211, 211) ' Light Gray
colorMap.Add "MFT", RGB(65, 105, 225) ' Royal Blue
colorMap.Add "mft", RGB(70, 130, 180) ' Steel Blue
colorMap.Add "Prefetch Files", RGB(255, 140, 0) ' Dark Orange
colorMap.Add "Registry", RGB(0, 100, 0) ' Dark Green
colorMap.Add "Shellbags", RGB(255, 165, 0) ' Orange
colorMap.Add "WebHistory", RGB(173, 216, 230) ' Light Blue
colorMap.Add "account_tampering", RGB(0, 0, 255) ' Blue
colorMap.Add "antivirus", RGB(0, 128, 0) ' Green
colorMap.Add "indicator_removal", RGB(255, 0, 0) ' Red
colorMap.Add "lateral_movement", RGB(255, 165, 0) ' Orange
colorMap.Add "login_attacks", RGB(255, 255, 0) ' Yellow
colorMap.Add "microsoft_rds_events_-_user_profile_disk", RGB(0, 255, 255) ' Cyan
colorMap.Add "persistence", RGB(128, 128, 0) ' Olive
colorMap.Add "powershell_engine_state", RGB(255, 192, 203) ' Pink
colorMap.Add "powershell_script", RGB(165, 42, 42) ' Brown
colorMap.Add "rdp_events", RGB(0, 255, 0) ' Lime
colorMap.Add "service_installation", RGB(0, 128, 128) ' Teal
colorMap.Add "sigma", RGB(153, 50, 204) ' Dark Orchid (Purple)
colorMap.Add "AppCompatCache", RGB(176, 224, 230) ' Powder Blue
colorMap.Add "Jump Lists", RGB(230, 230, 250) ' Lavender

' Assign contrasting font colors
fontColorMap.Add "AmcacheExecution", RGB(0, 0, 0) ' Black
fontColorMap.Add "EventLogs", RGB(255, 255, 255) ' White
fontColorMap.Add "FileDeletion", RGB(255, 255, 255) ' White
fontColorMap.Add "LNKFiles", RGB(0, 0, 0) ' Black
fontColorMap.Add "MFT", RGB(255, 255, 255) ' White
fontColorMap.Add "mft", RGB(255, 255, 255) ' White text
fontColorMap.Add "Prefetch Files", RGB(0, 0, 0) ' Black
fontColorMap.Add "Registry", RGB(255, 255, 255) ' White
fontColorMap.Add "Shellbags", RGB(0, 0, 0) ' Black
fontColorMap.Add "WebHistory", RGB(0, 0, 0) ' Black
fontColorMap.Add "account_tampering", RGB(255, 255, 255) ' White
fontColorMap.Add "antivirus", RGB(255, 255, 255) ' White
fontColorMap.Add "indicator_removal", RGB(255, 255, 255) ' White
fontColorMap.Add "lateral_movement", RGB(0, 0, 0) ' Black
fontColorMap.Add "login_attacks", RGB(0, 0, 0) ' Black
fontColorMap.Add "microsoft_rds_events_-_user_profile_disk", RGB(0, 0, 0) ' Black
fontColorMap.Add "persistence", RGB(255, 255, 255) ' White
fontColorMap.Add "powershell_engine_state", RGB(0, 0, 0) ' Black
fontColorMap.Add "powershell_script", RGB(255, 255, 255) ' White
fontColorMap.Add "rdp_events", RGB(0, 0, 0) ' Black
fontColorMap.Add "service_installation", RGB(255, 255, 255) ' White
fontColorMap.Add "sigma", RGB(255, 255, 255) ' White
fontColorMap.Add "AppCompatCache", RGB(0, 0, 0) ' Black
fontColorMap.Add "Jump Lists", RGB(0, 0, 0) ' Black


' Process each row directly - much simpler and often faster
    For i = 2 To lastRow
        artifactName = ws.Cells(i, 2).Value
        If colorMap.Exists(artifactName) Then
            ' Format the entire row directly
            With ws.Range("A" & i & ":AC" & i)
                .Interior.Color = colorMap(artifactName)
                .Font.Color = fontColorMap(artifactName)
            End With
        End If
        
        ' Allow Excel to breathe every 1000 rows
        If i Mod 1000 = 0 Then
            DoEvents
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
