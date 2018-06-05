Add-Type -AssemblyName System.Windows.Forms

$keys_url = Read-Host "Keys URL"
$json = Invoke-WebRequest -Uri "$keys_url/json_enc" | ConvertFrom-Json
Invoke-WebRequest -Uri "$keys_url/seeddb" -OutFile "seeddb.bin"
$seeddb_date = (Get-Date).ToString()

function GetGM9NameForCIA {
    param([string]$TitleID)

    for ($i = 0; $i -le $json.Count; $i++) {
        if ($json[$i].titleID -eq $TitleID.ToLower()) {
            $name = $json[$i].titleID.ToUpper()

            if ($json[$i].name.Length -ne 0) {
                $name += " "
                $name += $json[$i].name
            }

            if ($json[$i].serial.Length -ne 0) {
                $name += " ("
                $name += $json[$i].serial
                $name += ")"
            }

            if ($json[$i].region.Length -ne 0) {
                $name += " ("
                $region = $json[$i].region

                if ($region -eq "ALL") {
                    $region = "W"
                } else {
                    $region = $region.Substring(0, 1)
                }
                $name += $region
                $name += ")"
            }
            $name += ".cia"
            return $name -replace '[<>:"/\\|?*]', ''
        }
    }

    return "$TitleID.cia"
}

function ConvertCIA {
    param([int]$To, [string]$Path)

    switch ($To) {
        0 {
            Start-Process -FilePath ".\makerom.exe" -ArgumentList "-ciatocci `"$Path`"" -Wait
        }

        1 {
            Start-Process -FilePath ".\makerom.exe" -ArgumentList "-ciatocci `"$Path`"" -Wait
            $old = [System.IO.Path]::GetFileNameWithoutExtension($Path) + ".cci"
            $new = [System.IO.Path]::GetFileNameWithoutExtension($Path) + ".3ds"
            Rename-Item -Path $old -NewName $new
        }
    }
}

function DecryptCIA {
    param([string]$Path)

    $process = Start-Process -FilePath ".\decrypt.exe" -ArgumentList "`"$Path`"" -PassThru
    Start-Sleep -Seconds 1
    [System.Windows.Forms.SendKeys]::SendWait('~')
    $process.WaitForExit()
    $files = Get-ChildItem -Exclude "*.exe","*.dll","*.cia"

    foreach ($file in $files) {
        $info = [System.IO.FileInfo]::new($file)

        if ($info.Name.Contains(".ncch")) {
            $data = [System.IO.File]::ReadAllBytes($file)
            $data[0x188 + 3] = 0
            $data[0x188 + 7] = 4
            [System.IO.File]::WriteAllBytes($file, $data)

            $name = [System.IO.Path]::GetFileNameWithoutExtension($info.Name)
            $noext = [System.IO.Path]::GetFileNameWithoutExtension($Path)
            $id = [System.IO.FileInfo]::new($name).Extension.Replace(".", "")
            $name = [System.IO.Path]::GetFileNameWithoutExtension($name)

            if ($name -eq $noext) {
                Start-Process -FilePath ".\makerom.exe" -ArgumentList "-f cia -o `"$noext ($id) (Decrypted).cia`" -i `"$file`:0:0`" -ignoresign -target p" -Wait

                if (!(Test-Path "$noext ($id) (Decrypted).cia")) {
                    Start-Process -FilePath ".\makerom.exe" -ArgumentList "-f cia -o `"$noext ($id) (Decrypted).cia`" -major 0 -i `"$file`:0:0`" -ignoresign -target p" -Wait
                }
            }

            Remove-Item "$file"
        }
    }
}

function DownloadAndDecryptCIA {
    param([string]$TitleID, [string]$Version)

    $TitleID = $TitleID.ToUpper()

    if ($Version -eq "") {
        Start-Process -FilePath ".\nustool.exe" -ArgumentList "-m -p $TitleID" -Wait
    } else {
        Start-Process -FilePath ".\nustool.exe" -ArgumentList "-m -p -V $Version $TitleID" -Wait
    }

    md "cdn"

    foreach ($file In (Get-ChildItem -Path "$TitleID" -Recurse -File)) {
        $dir = Get-ChildItem -Path "$TitleID" -Directory
        move "$TitleID/$dir/$file" "cdn/$file"
    }

    Remove-Item "$TitleID" -Recurse

    if (!(Test-Path "cdn/cetk")) {
        Invoke-WebRequest -Uri "$keys_url/ticket/$($TitleID.ToLower())" -OutFile "cdn/cetk"
    }

    $name = GetGM9NameForCIA -TitleID $TitleID
    Start-Process -FilePath ".\make_cdn_cia.exe" -ArgumentList "cdn `"$name`"" -Wait
    Remove-Item "cdn" -Recurse
    DecryptCIA -Path $name
}

while ($true) {
Clear-Host
Write-Host @"
3dstools
SeedDB updated: $seeddb_date
(1) Convert CIA
(2) Decrypt CIA
(3) Download & Decrypt CIA
(4) Download & Decrypt CIA list
(5) Convert all NCCHs to CIAs
(6) Extract all CIAs contents
(7) Update SeedDB
(8) Exit
"@
$option = [int](Read-Host "Select a option")
if ($option -eq 1) {
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.InitialDirectory = Convert-Path .
    $ofd.Filter = "CTR Importable Archive (*.cia)|*.cia"
    $ofd.ShowDialog() | Out-Null

    if ($ofd.FileName -ne "") {
        $format = [int](Read-Host "Format (0: CCI, 1: 3DS)")
        Write-Host "Converting..."
        ConvertCIA -To $format -Path $ofd.FileName
        $path = [System.IO.Path]::GetFileNameWithoutExtension($ofd.FileName)

        switch ($format) {
            0 {$path += ".cci"}
            1 {$path += ".3ds"}
        }

        if (!(Test-Path $path)) {
            Write-Host "makerom error"
            Pause
        }
    }
} elseif ($option -eq 2) {
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.InitialDirectory = Convert-Path .
    $ofd.Filter = "CTR Importable Archive (*.cia)|*.cia"
    $ofd.ShowDialog() | Out-Null

    if ($ofd.FileName -ne "") {
        Write-Host "Decrypting..."
        DecryptCIA -Path $ofd.FileName
    }
} elseif ($option -eq 3) {
    $tid = Read-Host "Title ID"

    if ($tid.Length -ne 16) {
        Write-Host "Invalid title ID"
        Pause
    } else {
        $ver = Read-Host "Version (empty for latest)"
        DownloadAndDecryptCIA -TitleID $tid -Version $ver
    }
} elseif ($option -eq 4) {
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.InitialDirectory = Convert-Path .
    $ofd.Filter = "Title List|*.txt"
    $ofd.ShowDialog() | Out-Null

    if ($ofd.FileName -ne "") {
        foreach ($title in ((Get-Content -Path $ofd.FileName) -split '`n')) {
            if ($title.Length -eq 16) {
                DownloadAndDecryptCIA -TitleID $title -Version ""
            } else {
                $TitleID = $title.Substring(0, $title.LastIndexOf(' '))
                $Version = $title.Substring($title.LastIndexOf(' ') + 1)
                DownloadAndDecryptCIA -TitleID $TitleID -Version $Version
            }
        }
    }
} elseif ($option -eq 5) {
    foreach ($ncch In (Get-ChildItem -Filter "*.ncch" -Recurse)) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($ncch)

        Start-Process -FilePath ".\makerom.exe" -ArgumentList "-f cia -o `"$name.cia`" -i `"$ncch`:0:0`" -ignoresign -target p" -Wait

        if (!(Test-Path "$name.cia")) {
            Start-Process -FilePath ".\makerom.exe" -ArgumentList "-f cia -o `"$name.cia`" -major 0 -i `"$ncch`:0:0`" -ignoresign -target p" -Wait
        }
    }
} elseif ($option -eq 6) {
    foreach ($cia in (Get-ChildItem -Filter "*.cia" -Recurse)) {
        $dest = Split-Path $cia -Leaf
        Start-Process -FilePath ".\ctrtool.exe" -ArgumentList "-x `"$cia`" --contents=`"$dest`"" -Wait
    }
} elseIf ($option -eq 7) {
    Invoke-WebRequest -Uri "$keys_url/seeddb" -OutFile "seeddb.bin"
    $seeddb_date = (Get-Date).ToString()
} elseIf ($option -eq 8) {
    break
}
}
