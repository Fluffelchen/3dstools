Add-Type -AssemblyName System.Windows.Forms

$keys_url = "http://3ds.titlekeys.gq"
$json = Invoke-WebRequest -Uri "$keys_url/json_enc" | ConvertFrom-Json

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
            return $name -replace '[<>:"/\\|?*]', ''
        }
    }

    return $TitleID
}

function Convert3DS {
    param([int]$To, [string]$Path)

    switch ($To) {
        0 {
            $si = [System.Diagnostics.ProcessStartInfo]::new()
            $si.FileName = [Environment]::CurrentDirectory + "\makerom.exe"
            $si.Arguments = "-ccitocia `"$Path`" -ignoresign -target p"
            $si.UseShellExecute = $false
            $si.CreateNoWindow = $true
            [System.Diagnostics.Process]::Start($si).WaitForExit()
        }

        1 {
            $si = [System.Diagnostics.ProcessStartInfo]::new()
            $si.FileName = [Environment]::CurrentDirectory + "\makerom.exe"
            $si.Arguments = "-ccitocia `"$Path`" -ignoresign -target p"
            $si.UseShellExecute = $false
            $si.CreateNoWindow = $true
            [System.Diagnostics.Process]::Start($si).WaitForExit()
            $old = [System.IO.Path]::GetFileNameWithoutExtension($Path) + ".cci"
            $new = [System.IO.Path]::GetFileNameWithoutExtension($Path) + ".3ds"
            Rename-Item -Path $old -NewName $new
        }
    }
}

function ConvertCIA {
    param([int]$To, [string]$Path)

    switch ($To) {
        0 {
            $si = [System.Diagnostics.ProcessStartInfo]::new()
            $si.FileName = [Environment]::CurrentDirectory + "\makerom.exe"
            $si.Arguments = "-ciatocci `"$Path`""
            $si.UseShellExecute = $false
            $si.CreateNoWindow = $true
            [System.Diagnostics.Process]::Start($si).WaitForExit()
        }

        1 {
            $si = [System.Diagnostics.ProcessStartInfo]::new()
            $si.FileName = [Environment]::CurrentDirectory + "\makerom.exe"
            $si.Arguments = "-ciatocci `"$Path`""
            $si.UseShellExecute = $false
            $si.CreateNoWindow = $true
            [System.Diagnostics.Process]::Start($si).WaitForExit()
            $old = [System.IO.Path]::GetFileNameWithoutExtension($Path) + ".cci"
            $new = [System.IO.Path]::GetFileNameWithoutExtension($Path) + ".3ds"
            Rename-Item -Path $old -NewName $new
        }
    }
}

function Decrypt3DS {
    param([string]$Path)

    $si = [System.Diagnostics.ProcessStartInfo]::new()
    $si.FileName = [Environment]::CurrentDirectory + "\decrypt.exe"
    $si.Arguments = "`"$Path`""
    $si.UseShellExecute = $false
    $si.CreateNoWindow = $true
    $si.RedirectStandardInput = $true
    $process = [System.Diagnostics.Process]::Start($si)
    $process.StandardInput.WriteLine()
    $process.WaitForExit()
    $files = Get-ChildItem -Filter "*.ncch"

    foreach ($file in $files) {
        $info = [System.IO.FileInfo]::new($file)
        $data = [System.IO.File]::ReadAllBytes($file)
        $data[0x188 + 3] = 0
        $data[0x188 + 7] = 4
        [System.IO.File]::WriteAllBytes($file, $data)
    }

    $files_str = ""
    $i = 0

    foreach ($file in $files) {
        $files_str += " -content `"$file`:$i`:$i`""
        ++$i
    }

    $noext = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $si = [System.Diagnostics.ProcessStartInfo]::new()
    $si.FileName = [Environment]::CurrentDirectory + "\makerom.exe"
    $si.Arguments = "-f cci -o `"$noext (Decrypted).3ds`"$files_str"
    $si.UseShellExecute = $false
    $si.CreateNoWindow = $true
    [System.Diagnostics.Process]::Start($si).WaitForExit()

    foreach ($file in $files) {
        Remove-Item $file
    }
}

function DecryptCIA {
    param([string]$Path)

    $si = [System.Diagnostics.ProcessStartInfo]::new()
    $si.FileName = [Environment]::CurrentDirectory + "\decrypt.exe"
    $si.Arguments = "`"$Path`""
    $si.UseShellExecute = $false
    $si.CreateNoWindow = $true
    $si.RedirectStandardInput = $true
    $process = [System.Diagnostics.Process]::Start($si)
    $process.StandardInput.WriteLine()
    $process.WaitForExit()
    $files = Get-ChildItem -Filter "*.ncch"
    $dlc = ""

    foreach ($file in $files) {
        $info = [System.IO.FileInfo]::new($file)
        $data = [System.IO.File]::ReadAllBytes($file)
        $data[0x188 + 3] = 0
        $data[0x188 + 7] = 4
        [System.IO.File]::WriteAllBytes($file, $data)
        if ($info.Name.Contains("DLC") -or $info.Name.Contains("0004008c") -or $info.Name.Contains("0004008C")) {
            $dlc = " -dlc"
        }
    }

    $files_str = ""
    $i = 0

    foreach ($file in $files) {
        $files_str += "-i `"$file`:$i`:$i`" "
        ++$i
    }

    $noext = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $si = [System.Diagnostics.ProcessStartInfo]::new()
    $si.FileName = [Environment]::CurrentDirectory + "\makerom.exe"
    $si.Arguments = "-f cia -o `"$noext (Decrypted).cia`" $files_str-ignoresign -target p$dlc"
    $si.UseShellExecute = $false
    $si.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($si)
    $process.WaitForExit()

    if (!(Test-Path "$noext (Decrypted).cia")) {
        $si = [System.Diagnostics.ProcessStartInfo]::new()
        $si.FileName = [Environment]::CurrentDirectory + "\makerom.exe"
        $si.Arguments = "-f cia -o `"$noext (Decrypted).cia`" $files_str-ignoresign -target p$dlc"
        $si.UseShellExecute = $false
        $si.CreateNoWindow = $true
        $process = [System.Diagnostics.Process]::Start($si)
        $process.WaitForExit()
    }

    foreach ($file in $files) {
        Remove-Item $file
    }
}

function DownloadAndDecryptCIA {
    param([string]$TitleID, [string]$Version)

    Write-Host "Downloading..."

    $TitleID = $TitleID.ToUpper()

    $si = [System.Diagnostics.ProcessStartInfo]::new()
    $si.FileName = [Environment]::CurrentDirectory + "\nustool.exe"

    if ($Version -eq "") {
        $si.Arguments = "-m $TitleID"
    } else {
        $si.Arguments = "-m -V $Version $TitleID"
    }

    $si.UseShellExecute = $false
    $si.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($si)
    $process.WaitForExit()

    md "cdn" | Out-Null

    foreach ($file In (Get-ChildItem -Path "$TitleID" -Recurse -File)) {
        $dir = Get-ChildItem -Path "$TitleID" -Directory
        move "$TitleID/$dir/$file" "cdn/$file"
    }

    Remove-Item "$TitleID" -Recurse

    if (!(Test-Path "cdn/cetk")) {
        Invoke-WebRequest -Uri "$keys_url/ticket/$($TitleID.ToLower())" -OutFile "cdn/cetk"

        if (!(Test-Path "cdn/cetk")) {
            Write-Host "Download failed (No ticket)"
            Remove-Item "cdn" -Recurse
            return $false
        }
    }

    $name = GetGM9NameForCIA -TitleID $TitleID
    $si = [System.Diagnostics.ProcessStartInfo]::new()
    $si.FileName = [Environment]::CurrentDirectory + "\make_cdn_cia.exe"
    $si.Arguments = "cdn `"$name`".cia"
    $si.UseShellExecute = $false
    $si.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($si)
    $process.WaitForExit()
    Remove-Item "cdn" -Recurse
    Write-Host "Decrypting..."
    DecryptCIA -Path "$name.cia"
    return $true
}

while ($true) {
Clear-Host
Write-Host @"
3dstools
(1) Convert (Decrypted Files Only)
(2) Decrypt
(3) Download & Decrypt CIA
(4) Download & Decrypt CIA list
(5) Convert all NCCHs to CIAs
(6) Extract all CIAs contents
(7) Exit
"@
$option = [int](Read-Host "Select a option")
if ($option -eq 1) {
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.InitialDirectory = Convert-Path .
    $ofd.Filter = "CTR Importable Archive|*.cia|3DS File|*.3ds"
    $ofd.ShowDialog() | Out-Null

    if ($ofd.FileName -ne "") {
        $file = [System.IO.Path]::GetFileNameWithoutExtension($ofd.FileName)

        switch ([System.IO.FileInfo]::new($ofd.FileName).Extension) {
            ".3ds" {
                $format = [int](Read-Host "Format (0: CIA)")

                if ($format -ne 0) {
                    Write-Host "Invalid format"
                    Pause
                    return
                }

                Write-Host "Converting..."
                Convert3DS -To $format -Path $ofd.FileName

                switch ($format) {
                    0 { $file += ".cia" }
                }
            }
            ".cia" {
                $format = [int](Read-Host "Format (0: CCI, 1: 3DS)")

                Write-Host "Converting..."
                ConvertCIA -To $format -Path $ofd.FileName

                switch ($format) {
                    0 { $file += ".cci" }
                    1 { $file += ".3ds" }
                }
            }
        }

        if (!(Test-Path $file)) {
            Write-Host "makerom error"
            Pause
        }
    }
} elseif ($option -eq 2) {
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.InitialDirectory = Convert-Path .
    $ofd.Filter = "CTR Importable Archive|*.cia|3DS File|*.3ds"
    $ofd.ShowDialog() | Out-Null

    if ($ofd.FileName -ne "") {
        Write-Host "Decrypting..."

        $info = [System.IO.FileInfo]::new($ofd.FileName)

        switch ($info.Extension) {
            ".3ds" { Decrypt3DS -Path $ofd.FileName }
            ".cia" { DecryptCIA -Path $ofd.FileName }
        }
    }
} elseif ($option -eq 3) {
    $tid = Read-Host "Title ID"

    if ($tid.Length -ne 16) {
        Write-Host "Invalid title ID"
        Pause
    } else {
        $ver = Read-Host "Version (empty for latest)"
        $result = DownloadAndDecryptCIA -TitleID $tid -Version $ver
        if (!$result) {
            Pause
        }
    }
} elseif ($option -eq 4) {
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.InitialDirectory = Convert-Path .
    $ofd.Filter = "Title List|*.txt"
    $ofd.ShowDialog() | Out-Null

    if ($ofd.FileName -ne "") {
        $pause = $false
        foreach ($title in ((Get-Content -Path $ofd.FileName) -split '`n')) {
            Write-Host "Title: $($title.ToUpper())"
            if ($title.Split(' ').Length -eq 1) {
                $result = DownloadAndDecryptCIA -TitleID $title -Version ""
                if (!$result) {
                    $pause = $true
                }
            } else {
                $TitleID = $title.Substring(0, $title.LastIndexOf(' '))
                $Version = $title.Substring($title.LastIndexOf(' ') + 1)
                $result = DownloadAndDecryptCIA -TitleID $TitleID -Version $Version
                if (!$result) {
                    $pause = $true
                }
            }
        }
        if ($pause) {
            Pause
        }
    }
} elseif ($option -eq 5) {
    foreach ($ncch In (Get-ChildItem -Filter "*.ncch" -Recurse)) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($ncch)
        $dlc = ""

        if ($name.Contains("DLC") -or $name.Contains("0004008c") -or $name.Contains("0004008C")) {
            $dlc = " -dlc"
        }

        $si = [System.Diagnostics.ProcessStartInfo]::new()
        $si.FileName = [Environment]::CurrentDirectory + "\makerom.exe"
        $si.Arguments = "-f cia -o `"$name.cia`" -i `"$ncch`:0:0`" -ignoresign -target p$dlc"
        $si.UseShellExecute = $false
        $si.CreateNoWindow = $true
        [System.Diagnostics.Process]::Start($si).WaitForExit()

        if (!(Test-Path "$name.cia")) {
            $si.Arguments = "-f cia -o `"$name.cia`" -major 0 -i `"$ncch`:0:0`" -ignoresign -target p$dlc"
            [System.Diagnostics.Process]::Start($si).WaitForExit()
        }
    }
} elseif ($option -eq 6) {
    $si = [System.Diagnostics.ProcessStartInfo]::new()
    $si.FileName = [Environment]::CurrentDirectory + "\ctrtool.exe"
    $si.UseShellExecute = $false
    $si.CreateNoWindow = $true

    foreach ($cia in (Get-ChildItem -Filter "*.cia" -Recurse)) {
        $dest = Split-Path $cia -Leaf
        $si.Arguments = "-x `"$cia`" --contents=`"$dest`""
        [System.Diagnostics.Process]::Start($si).WaitForExit()
    }
} elseif ($option -eq 7) {
    break
}
}
