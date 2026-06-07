# =============================================
# PERFIL PERSONALIZADO DE POWERSHELL
# =============================================

# Color Scheme
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

# =============================================
# VARIABLES GLOBALES DE ESTADO
# =============================================

$Global:TerminalInitialized = $false
$Global:GitInfoCache = $null
$Global:LastGitPath = $null

# =============================================
# FUNCIONES ÚTILES Y ALIASES
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
    $Global:LastGitPath = $null
    . $PROFILE
}

# =============================================
# Funciones de inicialización e información
# =============================================

function Show-InitialInfo {
    Write-Host ""
    Write-Host $Global:AsciiArt -ForegroundColor $script:ColorScheme.Primary
    Write-Host ""
    Show-DockerInfo
    Write-Host ""
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
        if ($LASTEXITCODE -ne 0) { return $result }

        if ($versionOutput -match '(\d+\.\d+\.\d+)') {
            $result.Version = $matches[1]
        }

        $containers = @(docker ps --format "{{.Names}}" 2>$null)

        if ($LASTEXITCODE -eq 0) {
            $result.Status = "🟢"
            $result.Running = $true
            $result.Containers = $containers | Where-Object { $_ }
        }
    } catch {
    }

    return $result
}

function Get-BoxWidth($title, $dockerInfo) {
    $maxLength = $title.Length

    if ($dockerInfo.Running -and $dockerInfo.Containers.Count -gt 0) {
        foreach ($container in $dockerInfo.Containers) {
            $len = ("📦 $container").Length
            if ($len -gt $maxLength) { $maxLength = $len }
        }
    }

    return $maxLength + 30
}

function Write-BoxLine {
    param([string]$Text, [int]$Width, [string]$Color = 'White')

    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length - 2) / 2))
    Write-Host "$(' ' * $padding)$Text" -ForegroundColor $Color
}

function Write-DockerBox($title, $dockerInfo, $width) {
    Write-Host "╔$('═' * ($width - 2))╗" -ForegroundColor $script:ColorScheme.Border
    Write-BoxLine $title $width $script:ColorScheme.Secondary

    if ($dockerInfo.Running) {
        Write-Host "╠$('═' * ($width - 2))╣" -ForegroundColor $script:ColorScheme.Border
        Write-BoxLine "Contenedores activos:" $width $script:ColorScheme.Warning

        if ($dockerInfo.Containers.Count -gt 0) {
            $containersText = "$($dockerInfo.Containers.Count) contenedor(es) en ejecución"
            Write-BoxLine $containersText $width $script:ColorScheme.Success
            $dockerInfo.Containers | ForEach-Object {
                Write-BoxLine "📦 $_" $width $script:ColorScheme.Neutral
            }
        } else {
            Write-BoxLine "No hay contenedores activos" $width $script:ColorScheme.Info
        }
    } else {
        Write-Host "╠$('═' * ($width - 2))╣" -ForegroundColor $script:ColorScheme.Border
        Write-BoxLine "Docker engine its not running." $width $script:ColorScheme.Neutral
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
# Prompt
# =============================================

function Get-GitInfo {
    # Caché simple: mismo directorio = reutilizar
    if ($PWD.Path -eq $Global:LastGitPath -and $Global:GitInfoCache) {
        return $Global:GitInfoCache
    }

    $Global:LastGitPath = $PWD.Path

    # Validar si es repo git
    $null = git rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -ne 0) {
        $Global:GitInfoCache = $null
        return $null
    }

    # Obtener branch
    $gitBranch = git branch --show-current 2>$null
    if (-not $gitBranch) {
        $Global:GitInfoCache = $null
        return $null
    }

    # Verificar cambios
    $hasChanges = git status --porcelain 2>$null

    $result = @{ Branch = $gitBranch; IsDirty = [bool]$hasChanges }
    $Global:GitInfoCache = $result

    return $result
}

function Get-OptimizedPath {
    $currentPath = $PWD.Path
    $homePath = $env:USERPROFILE

    if ($currentPath.StartsWith($homePath)) {
        $currentPath = "~" + $currentPath.Substring($homePath.Length)
    }

    if ($currentPath.Length -gt 35) {
        $currentPath = "..." + $currentPath.Substring([Math]::Max(0, $currentPath.Length - 32))
    }

    return $currentPath
}

function prompt {
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
# CONFIGURACIÓN DE MÓDULOS Y ALIASES
# =============================================

$MaximumHistoryCount = 100

Set-PSReadLineOption -BellStyle None
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Import-Module Terminal-Icons -ErrorAction SilentlyContinue *>$null

Set-Alias which Get-Command
Set-Alias grep Select-String
Set-Alias reload Reload-Profile

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $Global:TerminalInitialized = $false
    $Global:GitInfoCache = $null
} -ErrorAction SilentlyContinue

# =============================================
# INICIALIZACIÓN
# =============================================

if (-not $Global:TerminalInitialized) {
    Clear-Host
    Show-InitialInfo
    $Global:TerminalInitialized = $true
}
