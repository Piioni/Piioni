# =============================================
# PERFIL PERSONALIZADO DE POWERSHELL
# =============================================

# Variables globales
$Global:TerminalInitialized = $false
$Global:GitInfoCache = $null
$Global:GitInfoCacheExpiry = (Get-Date).AddSeconds(-1)
$Global:LastGitPath = $null

# Constantes de color
$script:ColorScheme = @{
    Primary = 'Magenta'
    Secondary = 'Cyan'
    Warning = 'Yellow'
    Success = 'Green'
    Info = 'Blue'
    Error = 'Red'
    Border = 'DarkGray'
    Neutral = 'White'
}

# ASCII Art
$Global:AsciiArt = @"
██████╗ ██╗██╗ ██████╗ ███╗   ██╗██╗
██╔══██╗██║██║██╔═══██╗████╗  ██║██║
██████╔╝██║██║██║   ██║██╔██╗ ██║██║
██╔═══╝ ██║██║██║   ██║██║╚██╗██║██║
██║     ██║██║╚██████╔╝██║ ╚████║██║
╚═╝     ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝
"@

# Importar Terminal-Icons de forma lazy
function Initialize-TerminalIcons {
    if (-not (Get-Command Get-TerminalIcon -ErrorAction SilentlyContinue)) {
        try {
            Import-Module Terminal-Icons -ErrorAction SilentlyContinue
        } catch {
            # Silencioso si no está instalado
        }
    }
}

# Configuración básica de PSReadLine
Set-PSReadLineOption -BellStyle None
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# =============================================
# FUNCIONES DE INFORMACIÓN
# =============================================

function Show-InitialInfo {
    Write-Host ""
    Write-Host $Global:AsciiArt -ForegroundColor $script:ColorScheme.Primary
    Write-Host ""
    Show-DockerInfo
}

function Get-DockerStatus {
    $result = @{
        Version = $null
        Status = "🔴"
        Running = $false
        Containers = @()
    }

    try {
        $versionOutput = docker --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $versionOutput -match '(\d+\.\d+\.\d+)') {
            $result.Version = $matches[1]
            $null = docker ps --quiet 2>$null
            if ($LASTEXITCODE -eq 0) {
                $result.Status = "🟢"
                $result.Running = $true
                $result.Containers = @(docker ps --format "{{.Names}}" 2>$null | Where-Object { $_ })
            }
        }
    } catch {
        # Mantener valores por defecto
    }

    return $result
}

function Get-BoxWidth($title, $dockerInfo) {
    $maxLength = $title.Length

    if ($dockerInfo.Running) {
        $maxLength = [Math]::Max($maxLength, "Contenedores activos:".Length)
        $dockerInfo.Containers | ForEach-Object {
            $maxLength = [Math]::Max($maxLength, ("📦 $_").Length)
        }
    } else {
        $maxLength = [Math]::Max($maxLength, "Docker engine its not running.".Length)
    }

    return $maxLength + 30
}

function Write-BoxLine {
    param([string]$Text, [int]$Width, [string]$Color = 'White', [bool]$Centered = $true)

    if ($Centered) {
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length - 2) / 2))
        Write-Host "║$(' ' * $padding)" -NoNewline -ForegroundColor $script:ColorScheme.Border
        Write-Host $Text -ForegroundColor $Color
    } else {
        Write-Host "║ $Text" -ForegroundColor $Color
    }
}

function Write-DockerBox($title, $dockerInfo, $width) {
    Write-Host "╔$('═' * ($width - 2))╗" -ForegroundColor $script:ColorScheme.Border
    Write-BoxLine $title $width $script:ColorScheme.Secondary $true

    if ($dockerInfo.Running) {
        Write-Host "╠$('═' * ($width - 2))╣" -ForegroundColor $script:ColorScheme.Border
        Write-BoxLine "Contenedores activos:" $width $script:ColorScheme.Warning $true

        if ($dockerInfo.Containers.Count -gt 0) {
            $containersText = "$($dockerInfo.Containers.Count) contenedor(es) en ejecución"
            Write-BoxLine $containersText $width $script:ColorScheme.Success $true
            $dockerInfo.Containers | ForEach-Object {
                Write-BoxLine "📦 $_" $width $script:ColorScheme.Neutral $true
            }
        } else {
            Write-BoxLine "No hay contenedores activos" $width $script:ColorScheme.Info $true
        }
    } else {
        Write-Host "╠$('═' * ($width - 2))╣" -ForegroundColor $script:ColorScheme.Border
        Write-BoxLine "Docker engine its not running." $width $script:ColorScheme.Neutral $true
    }

    Write-Host "╚$('═' * ($width - 2))╝" -ForegroundColor $script:ColorScheme.Border
}

function Show-DockerInfo {
    $dockerInfo = Get-DockerStatus
    $dockerTitle = if ($dockerInfo.Version) {
        "-= 🐳 Docker (v$($dockerInfo.Version)) $($dockerInfo.Status) =-"
    } else {
        "-= 🐳 Docker - No disponible $($dockerInfo.Status) =-"
    }
    Write-DockerBox $dockerTitle $dockerInfo (Get-BoxWidth $dockerTitle $dockerInfo)
}

# =============================================
# FUNCIÓN DE PROMPT
# =============================================

function Get-GitInfo {
    if ($PWD.Path -ne $Global:LastGitPath) {
        $Global:GitInfoCache = $null
        $Global:LastGitPath = $PWD.Path
    }

    if ($Global:GitInfoCache -and (Get-Date) -lt $Global:GitInfoCacheExpiry) {
        return $Global:GitInfoCache
    }

    try {
        $null = git rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }

        $gitBranch = git branch --show-current 2>$null
        if (-not $gitBranch) { return $null }

        $gitStatus = git status --porcelain=v1 --untracked-files=no 2>$null
        $result = @{ Branch = $gitBranch; IsDirty = [bool]$gitStatus }

        $Global:GitInfoCache = $result
        $Global:GitInfoCacheExpiry = (Get-Date).AddSeconds(10)
        return $result
    } catch {
        return $null
    }
}

function Get-OptimizedPath {
    $currentPath = $PWD.Path
    $homePath = $env:USERPROFILE

    if ($currentPath.StartsWith($homePath)) {
        $currentPath = "~" + $currentPath.Substring($homePath.Length)
    }

    if ($currentPath.Length -gt 35) {
        $currentPath = "..." + $currentPath.Substring($currentPath.Length - 32)
    }

    return $currentPath
}

function prompt {
    if (-not $Global:TerminalInitialized) {
        Clear-Host
        Show-InitialInfo
        Initialize-TerminalIcons
        $Global:TerminalInitialized = $true
    }

    Write-Host "(" -NoNewline -ForegroundColor $script:ColorScheme.Border
    Write-Host "$env:USERNAME" -NoNewline -ForegroundColor $script:ColorScheme.Primary
    Write-Host "@" -NoNewline -ForegroundColor $script:ColorScheme.Border
    Write-Host "$env:COMPUTERNAME" -NoNewline -ForegroundColor $script:ColorScheme.Warning
    Write-Host ") " -NoNewline -ForegroundColor $script:ColorScheme.Border

    Write-Host (Get-OptimizedPath) -NoNewline -ForegroundColor $script:ColorScheme.Info

    $gitInfo = Get-GitInfo
    if ($gitInfo) {
        Write-Host " (" -NoNewline -ForegroundColor $script:ColorScheme.Neutral
        Write-Host $gitInfo.Branch -NoNewline -ForegroundColor $script:ColorScheme.Error
        Write-Host ")" -NoNewline -ForegroundColor $script:ColorScheme.Neutral
        if ($gitInfo.IsDirty) {
            Write-Host "*" -NoNewline -ForegroundColor $script:ColorScheme.Warning
        }
    }

    Write-Host " ⇒" -NoNewline -ForegroundColor $script:ColorScheme.Warning
    return " "
}

# =============================================
# FUNCIONES ÚTILES
# =============================================

# Navegación
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function C: { Set-Location "C:\" }
function D: { Set-Location "D:\" }
function E: { Set-Location "E:\" }

# Git
function gs { git status --short }
function ga { git add $args }
function gitc { param($m) git commit -m $m }
function gp { git push }
function gl { git log --oneline -10 }
function gd { git diff }

# Docker
function dps { docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" }
function dimg { docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" }
function dstop { docker stop $args }
function drm { docker rm $args }
function dprune { docker system prune -f }
function dlogs { docker logs $args }

# Sistema
function touch($file) { New-Item -ItemType File -Name $file -Force | Out-Null }
function grep($regex, $dir) {
    if ($dir) {
        Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue | Select-String $regex
    } else {
        $input | Select-String $regex
    }
}

function Reload-Profile {
    $Global:TerminalInitialized = $false
    $Global:GitInfoCache = $null
    $Global:GitInfoCacheExpiry = (Get-Date).AddSeconds(-1)
    $Global:LastGitPath = $null
    . $PROFILE
}

# =============================================
# CONFIGURACIONES FINALES
# =============================================

Set-Alias which Get-Command
Set-Alias ll Get-ChildItem
Set-Alias la 'Get-ChildItem -Force'
Set-Alias grep Select-String
Set-Alias reload Reload-Profile

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $Global:TerminalInitialized = $false
    $Global:GitInfoCache = $null
} -ErrorAction SilentlyContinue

$MaximumHistoryCount = 1000
