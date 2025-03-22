Sub ColorRowsByArtifactName()
    Dim ws As Worksheet
    Dim lastRow As Long
    Dim i As Long
    Dim colorMap As Object, fontColorMap As Object
    Dim artifactName As String
    Dim rowDict As Object
    Dim key As Variant
    Dim chunkSize As Integer
    Dim tempRange As Range

    ' Set the active worksheet
    Set ws = ActiveSheet

    ' Find the last used row in column B
    lastRow = ws.Cells(ws.Rows.Count, 2).End(xlUp).Row

    ' Exit if no data
    If lastRow < 2 Then Exit Sub

    ' Disable screen updating & calculations to speed up processing
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual

    ' Define chunk size to avoid performance issues
    chunkSize = 5000  

    ' Create dictionaries for artifact colors
    Set colorMap = CreateObject("Scripting.Dictionary")
    Set fontColorMap = CreateObject("Scripting.Dictionary")
    Set rowDict = CreateObject("Scripting.Dictionary")

    ' Assign background colors
    colorMap.Add "account_tampering", RGB(0, 0, 255) ' Blue
    colorMap.Add "antivirus", RGB(0, 128, 0) ' Green
    colorMap.Add "indicator_removal", RGB(255, 0, 0) ' Red
    colorMap.Add "lateral_movement", RGB(255, 165, 0) ' Orange
    colorMap.Add "login_attacks", RGB(255, 255, 0) ' Yellow
    colorMap.Add "MFT - FileNameCreated0x30", RGB(128, 0, 128) ' Purple
    colorMap.Add "microsoft_rds_events_-_user_profile_disk", RGB(0, 255, 255) ' Cyan
    colorMap.Add "persistence", RGB(128, 128, 0) ' Olive
    colorMap.Add "powershell_engine_state", RGB(255, 192, 203) ' Pink
    colorMap.Add "powershell_script", RGB(165, 42, 42) ' Brown
    colorMap.Add "rdp_events", RGB(0, 255, 0) ' Lime
    colorMap.Add "service_installation", RGB(0, 128, 128) ' Teal
    colorMap.Add "sigma", RGB(153, 50, 204) ' Dark Orchid (Purple)
    colorMap.Add "Web History", RGB(173, 216, 230) ' Light Blue
    colorMap.Add "File Deletion", RGB(139, 0, 0) ' Dark Red
    colorMap.Add "Registry Update", RGB(0, 100, 0) ' Dark Green
    colorMap.Add "Program Execution - Amcache", RGB(135, 206, 235) ' Sky Blue
    colorMap.Add "LNK Files", RGB(211, 211, 211) ' Light Gray
    colorMap.Add "File/Folder Access - Shellbags", RGB(255, 140, 0) ' Dark Orange
    colorMap.Add "MFT - Created ( Users and TMP EXE, DLL, ZIP RAR etc..)", RGB(65, 105, 225) ' Royal Blue
    colorMap.Add "mft", RGB(0, 128, 128) ' Teal
    colorMap.Add "Event Logs", RGB(47, 79, 79) ' Dark Slate Gray

    ' Assign contrasting font colors
    fontColorMap.Add "account_tampering", RGB(255, 255, 255) ' White
    fontColorMap.Add "antivirus", RGB(255, 255, 255) ' White
    fontColorMap.Add "indicator_removal", RGB(255, 255, 255) ' White
    fontColorMap.Add "lateral_movement", RGB(0, 0, 0) ' Black
    fontColorMap.Add "login_attacks", RGB(0, 0, 0) ' Black
    fontColorMap.Add "MFT - FileNameCreated0x30", RGB(255, 255, 255) ' White
    fontColorMap.Add "microsoft_rds_events_-_user_profile_disk", RGB(0, 0, 0) ' Black
    fontColorMap.Add "persistence", RGB(255, 255, 255) ' White
    fontColorMap.Add "powershell_engine_state", RGB(0, 0, 0) ' Black
    fontColorMap.Add "powershell_script", RGB(255, 255, 255) ' White
    fontColorMap.Add "rdp_events", RGB(0, 0, 0) ' Black
    fontColorMap.Add "service_installation", RGB(255, 255, 255) ' White
    fontColorMap.Add "sigma", RGB(255, 255, 255) ' White
    fontColorMap.Add "Web History", RGB(0, 0, 0) ' Black
    fontColorMap.Add "File Deletion", RGB(255, 255, 255) ' White
    fontColorMap.Add "Registry Update", RGB(255, 255, 255) ' White
    fontColorMap.Add "Program Execution - Amcache", RGB(0, 0, 0) ' Black
    fontColorMap.Add "LNK Files", RGB(0, 0, 0) ' Black
    fontColorMap.Add "File/Folder Access - Shellbags", RGB(0, 0, 0) ' Black
    fontColorMap.Add "MFT - Created ( Users and TMP EXE, DLL, ZIP RAR etc..)", RGB(255, 255, 255) ' White
    fontColorMap.Add "mft", RGB(255, 255, 255) ' White
    fontColorMap.Add "Event Logs", RGB(255, 255, 255) ' White

    ' Read column B values into an array (fast processing)
    Dim data As Variant
    data = ws.Range("B2:B" & lastRow).Value

    ' Loop through the data and store rows in a dictionary
    For i = 1 To UBound(data, 1)
        artifactName = data(i, 1)
        If colorMap.Exists(artifactName) Then
            If Not rowDict.Exists(artifactName) Then
                Set rowDict(artifactName) = ws.Range("A" & (i + 1) & ":V" & (i + 1))
            Else
                ' Use Union only if the range is valid
                If Not rowDict(artifactName) Is Nothing Then
                    Set rowDict(artifactName) = Union(rowDict(artifactName), ws.Range("A" & (i + 1) & ":V" & (i + 1)))
                End If
            End If
        End If
    Next i

    ' Apply formatting in batch operations
    For Each key In rowDict.Keys
        If Not rowDict(key) Is Nothing Then
            ' If the range is too large, process in chunks
            Dim rowChunks As Range
            Set rowChunks = rowDict(key)
            Dim rowCount As Long
            rowCount = rowChunks.Rows.Count

            If rowCount > chunkSize Then
                ' Apply in chunks of 5000 rows
                Dim startRow As Long
                startRow = 1

                Do While startRow <= rowCount
                    ' Select a chunk of rows
                    Set tempRange = rowChunks.Rows(startRow).Resize(Application.Min(chunkSize, rowCount - startRow + 1))
                    
                    ' Apply formatting
                    With tempRange
                        .Interior.Color = colorMap(key)
                        .Font.Color = fontColorMap(key)
                    End With
                    
                    ' Move to the next chunk
                    startRow = startRow + chunkSize
                Loop
            Else
                ' Apply formatting to the entire range
                With rowChunks
                    .Interior.Color = colorMap(key)
                    .Font.Color = fontColorMap(key)
                End With
            End If
        End If
    Next key

    ' Restore Excel performance settings
    Application.ScreenUpdating = True
    Application.Calculation = xlCalculationAutomatic

    MsgBox "Row coloring complete!", vbInformation
End Sub
