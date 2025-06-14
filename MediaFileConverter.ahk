/*
FFmpeg Media File Converter
Open source utility that converts media files using FFmpeg.
=============================
Mesut Akcan
makcan@gmail.com
youtube.com/mesutakcan
mesutakcan.blogspot.com
github.com/akcansoft
=============================
v1.1 R19
14/06/2025

What's New in v1.1
------------------
- Settings Persistence:  
  User settings (FFmpeg path, parameters, output extension) are now saved to an INI file and automatically loaded on startup.  
- "Save settings on Exit" Option:  
  Added a checkbox to control whether settings are saved on exit.
- Improved Menu System:  
  Menu items and context menu items are now dynamically enabled/disabled based on the ListView state (selection, file count, etc.).
- Unified UI Update Function:  
  Button and menu enable/disable logic is now handled by a single `UpdateUI` function instead of separate functions.
- Download & Help Buttons:  
  Added buttons and menu items for downloading FFmpeg and accessing FFmpeg/format documentation directly.
- Drag & Drop and Command Line Improvements:  
  Drag & drop and command line file adding logic is more robust and unified.
- Status Window Enhancements:  
  Status window (conversion progress) is improved and resizes more responsively.
- Improved Error Handling:  
  More user-friendly error messages and checks (e.g., for FFmpeg path validity).
- Code Refactoring:  
  More modular and readable code structure, with global variables and settings handled more cleanly.
=============================
*/
#Requires AutoHotkey v2.0

appName := "FFmpeg Media File Converter"
appVer := "v1.1"

iniFile := A_ScriptDir "\settings.ini" ; Settings file
margin := 10
mainGuiDim := { w: 600, h: 500 } ; Main Gui size
statusGuiDim := { w: 600, h: 350 } ; Status Gui size
cancelConvert := false ; Flag to cancel conversion

links := {
  ffmpeg: "https://ffmpeg.org/ffmpeg.html", ; FFmpeg download link
  ffmpegFormats: "https://ffmpeg.org/ffmpeg-formats.html", ; FFmpeg formats documentation link
  ffmpegdownload: "https://ffmpeg.org/download.html" ; FFmpeg download page
}

; Menu Text
menuTxt := {
  add: "&Add file`tIns", ; Add File
  remove: "&Remove from list`tDel", ; Remove from List
  clear: "&Clear list", ; Clear List
  convert: "C&onvert all`tCtrl+Enter", ; Convert All
  select: "&Select all`tCtrl+A", ; Select all
  deselect: "&Deselect all`tEsc", ; Deselect all
  exit: "&Exit`tAlt+F4", ; Exit
  file: "&File", ; File menu
  help: "&Help", ; Help menu
  ffmpeghlp: "&FFmpeg help", ; FFmpeg Help
  ffmpegformatshlp: "FF&mpeg formats help", ; FFmpeg Formats Help
  download: "&Download FFmpeg", ; Download FFmpeg
  about: "&About" ; About
}

; ---- Main gui ------------------
mainGui := Gui("+Resize +MinSize500x300", appName)
mainGui.MarginX := mainGui.MarginY := margin

; --- ListView ---
LV1 := mainGui.AddListView("xm ym h" mainGuiDim.h - 140, ["File Path", "File Name"])
LV1.OnEvent("ItemSelect", UpdateUI)
LV1.OnEvent("ContextMenu", ShowContextMenu)

; FFmpeg selection
txtFFmpeg := mainGui.AddText("xm y+10", "FFmpeg.exe:")
edtFFmpeg := mainGui.AddEdit("x+10 w350", "C:\Program Files\FFmpeg\bin\ffmpeg.exe") ; Default FFmpeg path
edtFFmpeg.OnEvent("Change", SetSettingsChanged)

btnBrowse := mainGui.AddButton("x+10", "...")
btnBrowse.OnEvent("Click", BrowseFFmpeg)

btnFFmpegDownload := mainGui.AddButton("x+1", "Download FFmpeg")
btnFFmpegDownload.OnEvent("Click", (*) => Run(links.ffmpegdownload)) ; Download FFmpeg button

txtFFmpegParams := mainGui.AddText("xm y+15", "FFmpeg Parameters:")
edtFFmpegParams := mainGui.AddEdit("x+10 yp-5 w200", "-acodec pcm_s16le") ; Default FFmpeg parameters
edtFFmpegParams.OnEvent("Change", SetSettingsChanged)

btnFFmpegHlp := mainGui.AddButton("x+1", "?") ; Help button for FFmpeg
btnFFmpegHlp.OnEvent("Click", (*) => Run(links.ffmpeg))

txtOutputExt := mainGui.AddText("x+10 yp+5", "Output Extension:")
edtOutputExt := mainGui.AddEdit("x+10 yp-5", "wav") ; Default output file extension
edtOutputExt.OnEvent("Change", SetSettingsChanged)

btnFFmpegFormatHlp := mainGui.AddButton("x+1", "?") ; Help button for FFmpeg Formats
btnFFmpegFormatHlp.OnEvent("Click", (*) => Run(links.ffmpegFormats))

btnAdd := mainGui.AddButton("xm", "Add &File")
btnAdd.OnEvent("Click", AddFiles)

btnRemove := mainGui.AddButton("x+10 Disabled", "&Remove from List")
btnRemove.OnEvent("Click", RemoveSelected)

btnConvert := mainGui.AddButton("x+10 Disabled", "&Convert")
btnConvert.OnEvent("Click", ConvertFiles)

optSaveSettings := mainGui.AddCheckBox("x+10 yp5", "Save settings on Exit")
optSaveSettings.Value := true ; Default value for saving settings

btnExit := mainGui.AddButton("x+300", "&Exit")
btnExit.OnEvent("Click", mainGuiClose)

; --- Status Bar -------
SB1 := mainGui.AddStatusBar()
SB1.SetText("You can drag and drop files.")

; --- Events ------
mainGui.OnEvent("DropFiles", DropFiles) ; File drag and drop
mainGui.OnEvent("Size", mainGuiSize) ; Resize event
mainGui.OnEvent("Close", mainGuiClose) ; Close event

; --- Menu ---
fileMenu := Menu() ; Main menu
AddMenuItems(fileMenu)
fileMenu.Add() ; Separator
fileMenu.Add(menuTxt.exit, mainGuiClose)
rcMenu := Menu() ; Context menu
AddMenuItems(rcMenu)
helpMenu := Menu() ; Help menu
helpMenu.Add(menuTxt.about, About)
helpMenu.Add() ; Separator
helpMenu.Add(menuTxt.download, (*) => Run(links.ffmpegdownload)) ; Download FFmpeg
helpMenu.Add(menuTxt.ffmpeghlp, (*) => Run(links.ffmpeg)) ; FFmpeg help
helpMenu.Add(menuTxt.ffmpegformatshlp, (*) => Run(links.ffmpegFormats)) ; FFmpeg formats help
mnuBar := MenuBar() ; Menu bar
mnuBar.Add(menuTxt.file, fileMenu)
mnuBar.Add(menuTxt.help, helpMenu)
mainGui.MenuBar := mnuBar

; --------- Status gui -----------------------
statusGui := Gui("+Resize", "Conversion Status") ; Status window
LV2 := statusGui.AddListView("w" statusGuiDim.w - 20 " h" statusGuiDim.h - 70, ["File", "Status", "New File"])
progressBar := statusGui.AddProgress("xm w" statusGuiDim.w - 2 * margin " h20 cGreen BackgroundAAAAAA")
progressTxt1 := statusGui.AddText("xm yp+3 w30 BackgroundTrans cffffff", "1/100")
progressTxt2 := statusGui.AddText("xm yp BackgroundTrans cffffff", "000%")

btnOK := statusGui.AddButton("xm y+10", "Cancel")
btnOK.OnEvent("Click", statusGuibtnCancelCloseClick)
SB2 := statusGui.AddStatusBar()
statusGui.OnEvent("Size", statusGuiSize)
statusGui.OnEvent("Close", statusGuiClose) ; Close event
;--------------------------------------------

; --- Hotkeys ---
#HotIf WinActive("ahk_id " mainGui.Hwnd)
Del:: RemoveSelected()
Insert:: AddFiles()
^Enter:: ConvertFiles()
^a:: SelectAll(true)
Esc:: SelectAll(false)
#HotIf

; --- Add files from command line parameters ---
if A_Args.Length {
  duplicateCount := 0
  for f in A_Args {
    if DirExist(f) {
      Loop Files, f "\*.*" {
        if !AddFileToListView(A_LoopFileFullPath)
          duplicateCount++
      }
    } else {
      if !AddFileToListView(f)
        duplicateCount++
    }
  }
  SB1Message(duplicateCount)
  UpdateUI()
}

; ---- Main program start -------------------
LoadSettings() ; Load settings from the ini file
UpdateUI() ; Initial UI update
mainGui.Show("w" mainGuiDim.w " h" mainGuiDim.h) ; Show the main GUI

; Add menu items to the context menu and the main menu
AddMenuItems(m) {
  global menuTxt
  m.Add(menuTxt.add, AddFiles)
  m.Add() ; Separator
  m.Add(menuTxt.remove, RemoveSelected)
  m.Add(menuTxt.clear, ClearList)
  m.Add(menuTxt.convert, ConvertFiles)
  m.Add() ; Separator
  m.Add(menuTxt.select, (*) => (SelectAll(true)))
  m.Add(menuTxt.deselect, (*) => (SelectAll(false)))
}

SelectAll(select) { ; Select all or deselect all items in the ListView.
  LV1.Modify(0, select ? "Select" : "-Select")
  UpdateUI()
}


; FFmpeg path selection
; This function allows the user to select the FFmpeg executable file.
BrowseFFmpeg(*) {
  mainGui.Opt("+OwnDialogs")
  if selectedFile := FileSelect(1, edtFFmpeg.Text, "Select FFmpeg", "FFmpeg (ffmpeg.exe)") {
    if FileExist(selectedFile) {
      edtFFmpeg.Text := selectedFile
    } else {
      MsgBox("The selected FFmpeg file could not be found.", "Error", "Icon!")
    }
  }
}

; Adds a file to the ListView if it is not already present.
AddFileToListView(filePath) {
  SplitPath(filePath, &fileName, &dir)
  if FindRowInListView(dir, fileName) {
    return false
  }
  LV1.Add("", dir, fileName)
  return true
}

; Checks if a file is already present in the ListView.
FindRowInListView(dir, fileName) {
  loop LV1.GetCount() {
    if (LV1.GetText(A_Index, 1) = dir && LV1.GetText(A_Index, 2) = fileName)
      return true
  }
  return false
}

; Clears the ListView and updates the buttons.
ClearList(*) {
  LV1.Delete()
  UpdateUI()
}

; Adds files to the ListView using a file selection dialog.
AddFiles(*) {
  mainGui.Opt("+OwnDialogs")
  selectedFiles := FileSelect("M3", , "Select File")
  if !selectedFiles
    return

  duplicateCount := 0
  for file in selectedFiles {
    if !AddFileToListView(file)
      duplicateCount++
  }
  SB1Message(duplicateCount)
  UpdateUI()
}

; Adds files to the ListView using drag-and-drop functionality.
DropFiles(gObj, gCtrlObj, FileArray, X, Y) {
  duplicateCount := 0
  for file in FileArray {
    if DirExist(file) {
      Loop Files, file "\*.*" {
        if !AddFileToListView(A_LoopFileFullPath)
          duplicateCount++
      }
    } else {
      if !AddFileToListView(file)
        duplicateCount++
    }
  }
  SB1Message(duplicateCount)
  UpdateUI()
}

; Removes selected files from the ListView.
RemoveSelected(*) {
  while (row := LV1.GetNext()) {
    LV1.Delete(row)
  }
  SB1Message(0)
  UpdateUI()
}

; Close the main GUI and exit the application.
mainGuiClose(*) {
  ; Save settings on exit if the checkbox is checked
  if optSaveSettings.Value && isSettingsChanged {
    SaveSettings()
  }
  ExitApp()
}


; Close the status GUI and cancel the conversion if necessary.
statusGuibtnCancelCloseClick(*) {
  global cancelConvert
  ; Cancel button
  if btnOK.Text != "Close" {
    cancelConvert := true
    return
  }

  ; Close button
  statusGuiClose()
}

statusGuiClose(*) {
  cancelConvert := false
  btnOK.Text := "Cancel"
  LV2.Delete() ; Clear the status ListView
  statusGui.Hide() ; Hide the status window
  mainGui.Opt("-Disabled") ; Enable the main window
  mainGui.Show() ; Show the main window
}

; Converts files using FFmpeg based on the selected parameters.
ConvertFiles(*) {
  global cancelConvert
  ffmpegPath := Trim(edtFFmpeg.Text)
  if !FileExist(ffmpegPath) {
    MsgBox("ffmpeg.exe not found. Please specify a valid FFmpeg path.", "Error", "Icon!")
    return
  }

  statusGui.Show() ; Show the status window
  statusGui.Opt("+OwnDialogs") ; Allow the status window to own dialogs
  statusGui.Opt('+Owner' mainGui.hwnd) ; Set the owner of the status window to the main window
  mainGui.Opt('+Disabled') ; Disable the main window
  convertedCount := 0
  failedCount := 0
  totalFiles := LV1.GetCount()
  ext := Trim(edtOutputExt.Text)
  if !RegExMatch(ext, "^\.") {
    ext := "." ext
  }
  parameter := " " Trim(edtFFmpegParams.Text) " "

  loop totalFiles { ; Loop through all files in the ListView
    if cancelConvert {
      btnOK.Text := "Close"
      cancelConvert := false
      SB2.SetText("Conversion was canceled by the user.")
      return
    }
    LV1.Modify(0, "-Select") ; Deselect all items
    LV1.Modify(A_Index, "Select Vis") ; Select the current item

    fileDir := LV1.GetText(A_Index, 1) ; Get the directory of the file
    fileName := LV1.GetText(A_Index, 2) ; Get the file name
    SplitPath(fileName, , , , &fName) ; Split the file name to get the base name

    inputFile := fileDir "\" fileName ; Full path of the input file
    outputFile := fileDir "\" fName ext ; Full path of the output file

    SB2.SetText(inputFile)
    UpdateProgress(A_Index, totalFiles)
    if FileExist(inputFile) { ; Check if the input file exists
      if !FileExist(outputFile) {
        cmd := '"' ffmpegPath '" -i "' inputFile '"' parameter '"' outputFile '"'
        LV2.Add("", inputFile, "Converting...")
        row := LV2.GetCount()
        LV2.Modify(0, "-Select") ; Deselect all items
        LV2.Modify(row, "Select Vis") ; Select the current item
        try {
          RunWait(cmd, , "Hide")
          if FileExist(outputFile) {
            LV2.Modify(row, , , "Converted", fName ext)
            convertedCount++
          } else {
            LV2.Modify(row, , , "ERROR: Conversion failed")
            failedCount++
          }
        } catch as err {
          LV2.Modify(row, , , "ERROR: " err.message)
          failedCount++
        }
      } else {
        LV2.Add("", inputFile, "FILE ALREADY EXISTS")
      }
    } else {
      LV2.Add("", inputFile, "ERROR: Source file not found")
      failedCount++
    }
  }
  SB2.SetText(Format("Process complete. Total files: {1}, Converted files: {2}, Failed: {3}", totalFiles, convertedCount, failedCount))
  btnOK.Text := "Close"
}

; Updates the status bar message with the number of duplicate files and total file count.
SB1Message(dupeCount) {
  if dupeCount > 0 {
    txt := dupeCount " files were not added because they are already in the list."
  }
  txt .= " Total file count: " LV1.GetCount()
  SB1.SetText(txt)
}

; ListView resizing function
ResizeListView(LV, gWidth, gHeight, r) {
  LV.Move(, , gWidth - 2 * margin, gHeight - r)
  LV.GetPos(, , &w, &h)
  colCount := LV.GetCount("Column")
  colWidths := colCount = 3 ? [0.5, 0.3, 0.2] : [0.7, 0.3]
  for i, width in colWidths {
    LV.ModifyCol(i, w * width - 15)
  }
  return h
}

; Main gui resizing
mainGuiSize(gObj, MinMax, Width, Height) {
  if MinMax = -1  ; When window is minimized
    return

  ; Adjust ListView to new size
  h := ResizeListView(LV1, Width, Height, 140)

  txtFFmpeg.Move(, margin + h + 15)
  edtFFmpeg.Move(, margin + h + 10)
  btnBrowse.Move(, margin + h + 10)
  btnFFmpegDownload.Move(, margin + h + 10)

  txtFFmpegParams.Move(, margin + h + 50)
  edtFFmpegParams.Move(, margin + h + 45)

  btnFFmpegHlp.Move(, margin + h + 45)

  txtOutputExt.Move(, margin + h + 50)
  edtOutputExt.Move(, margin + h + 45)
  btnFFmpegFormatHlp.Move(, margin + h + 45)

  btnAdd.Move(, margin + h + 75)
  btnRemove.Move(, margin + h + 75)
  btnConvert.Move(, margin + h + 75)

  optSaveSettings.Move(, margin + h + 80)

  btnExit.GetPos(, , &w)
  btnExit.Move(Width - w - margin, margin + h + 75)
  WinRedraw(gObj)
}

; Resizes the status window and its components.
statusGuiSize(gObj, MinMax, Width, Height) {
  if MinMax = -1  ; When window is minimized
    return

  h := ResizeListView(LV2, Width, Height, 90)
  progressBar.Move(, h + 15, Width - 2 * margin)
  progressTxt1.Move(, h + 18)
  progressTxt2.GetPos(, , &w)
  progressTxt2.Move(Width / 2 - w / 2, h + 18)
  btnOK.GetPos(, , &w)
  btnOK.Move(Width / 2 - w / 2, margin + h + 30)
  WinRedraw(gObj)
}

; Context menu for the ListView
ShowContextMenu(LV1, Item, IsRightClick, X, Y) {
  UpdateUI()
  rcMenu.Show(X, Y)
}

; Updates progress bar and text based on current file index and total files.
UpdateProgress(index, totalFiles) {
  percentage := Round(index / totalFiles * 100)
  progressBar.Value := percentage
  WinGetPos(, , &statusGui_w, , statusGui.Hwnd)
  progressTxt1.Text := index "/" totalFiles
  progressTxt2.GetPos(, , &w)
  progressTxt2.Move(statusGui_w / 2 - w / 2)
  progressTxt2.Text := percentage "%"
}

; Load settings from INI file
LoadSettings(*) {
  global iniFile, isSettingsChanged
  if FileExist(iniFile) { ; Check if the settings file exists
    p := IniRead(iniFile, "Settings", "FFMpegPath")
    if !FileExist(p) {
      MsgBox("The specified FFmpeg path does not exist. Please select a valid FFmpeg path.", "Error", "Icon!")
      edtFFmpeg.Text := ""
    }
    edtFFmpegParams.Text := IniRead(iniFile, "Settings", "FFMpegParams")
    edtOutputExt.Text := IniRead(iniFile, "Settings", "OutputExt")
  }
  isSettingsChanged := false ; Reset settings changed flag
}

; Save settings to INI file
SaveSettings(*) {
  global iniFile 
  IniWrite(edtFFmpeg.Text, iniFile, "Settings", "FFMpegPath")
  IniWrite(edtFFmpegParams.Text, iniFile, "Settings", "FFMpegParams")
  IniWrite(edtOutputExt.Text, iniFile, "Settings", "OutputExt")
}

; Set the flag to indicate that settings have changed.
SetSettingsChanged(*) {
  global isSettingsChanged
  isSettingsChanged := true ; Set flag to indicate settings have changed
}

; Update the UI based on the current state of the ListView and buttons.
UpdateUI(*) { 
  global LV1, fileMenu, rcMenu
  hasSelected := LV1.GetCount("Selected") > 0
  hasItems := LV1.GetCount() > 0

  btnRemove.Enabled := hasSelected
  btnConvert.Enabled := hasItems

  ; Update menu items
  menuItems := Map(
    menuTxt.remove, hasSelected,
    menuTxt.clear, hasItems,
    menuTxt.convert, hasItems,
    menuTxt.select, hasItems,
    menuTxt.deselect, hasItems,
  )

  ; Apply states to both menus
  for mText, enabled in menuItems {
    for menu in [fileMenu, rcMenu] {
      try {
        enabled ? menu.Enable(mText) : menu.Disable(mText)
      }
    }
  }
}

; About dialog
About(*) {
  MsgBox(Format("
(
{1}
{2}

©2025
Mesut Akcan
makcan@gmail.com

akcansoft.blogspot.com
mesutakcan.blogspot.com
github.com/akcansoft
youtube.com/mesutakcan
)",
    appName, appVer), "About", "Owner" mainGui.Hwnd)
}