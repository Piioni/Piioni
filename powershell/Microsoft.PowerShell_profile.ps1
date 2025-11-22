# =============================================
# PERFIL PERSONALIZADO DE POWERSHELL
# =============================================

# Variables globales
$Global:TerminalInitialized = $false
$Global:GitInfoCache = $null
$Global:GitInfoCacheExpiry = (Get-Date).AddSeconds(-1)

# ASCII Art definido como variable
$Global:AsciiArt = @"
██████╗ ██╗██╗ ██████╗ ███╗   ██╗██╗
██╔══██╗██║██║██╔═══██╗████╗  ██║██║
██████╔╝██║██║██║   ██║██╔██╗ ██║██║
██╔═══╝ ██║██║██║   ██║██║╚██╗██║██║
██║     ██║██║╚██████╔╝██║ ╚████║██║
╚═╝     ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝
"@

# Importar Terminal-Icons si está disponible
try {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
} catch {
    # Silencioso si no está instalado
}

# Configuración básica de PSReadLine
Set-PSReadLineOption -BellStyle None
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# =============================================
# FUNCIÓN DE INFORMACIÓN INICIAL
# =============================================

function Show-InitialInfo {    
    Write-Host ""
    Write-Host $Global:AsciiArt -ForegroundColor Magenta
    Write-Host ""
    
    Show-DockerInfo
}

function Show-DockerInfo {
    $dockerInfo = Get-DockerStatus
    
    # Crear título con versión en la misma línea
    $dockerTitle = if ($dockerInfo.Version) {
        "-= 🐳 Docker (v$($dockerInfo.Version)) $($dockerInfo.Status) =-"
    } else {
        "-= 🐳 Docker - No disponible $($dockerInfo.Status) =-"
    }
    
    # Calcular ancho dinámico
    $boxWidth = Get-OptimalBoxWidth $dockerTitle $dockerInfo
    
    # Dibujar caja
    Write-DockerBox $dockerTitle $dockerInfo $boxWidth
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
            
            # Verificar si el engine está corriendo
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

function Get-OptimalBoxWidth($title, $dockerInfo) {
    $maxLength = $title.Length
    
    if ($dockerInfo.Running) {
        $containersTitle = "Contenedores activos:"
        $maxLength = [Math]::Max($maxLength, $containersTitle.Length)
        
        foreach ($name in $dockerInfo.Containers) {
            $containerLine = "📦 $name"
            $maxLength = [Math]::Max($maxLength, $containerLine.Length)
        }
    } else {
        $engineOffText = "Docker engine its not running."
        $maxLength = [Math]::Max($maxLength, $engineOffText.Length)
    }
    
    return $maxLength + 30
}

function Write-CenteredBoxLine {
    param(
        [string]$Text,
        [int]$Width,
        [string]$Color = 'White'
    )
    
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length - 2) / 2))
    Write-Host "║$(' ' * $padding)" -NoNewline -ForegroundColor DarkGray
    Write-Host $Text -ForegroundColor $Color
}

function Write-BoxSeparator {
    param([int]$Width)
    Write-Host "╠$('═' * ($Width - 2))╣" -ForegroundColor DarkGray
}

function Write-DockerBox($title, $dockerInfo, $width) {
    # Línea superior
    Write-Host "╔$('═' * ($width - 2))╗" -ForegroundColor DarkGray
    
    # Título Docker
    Write-CenteredBoxLine $title $width 'Cyan'
    
    if ($dockerInfo.Running) {
        Write-BoxSeparator $width
        Write-CenteredBoxLine "Contenedores activos:" $width 'Yellow'
        
        if ($dockerInfo.Containers.Count -gt 0) {
            $containersText = "$($dockerInfo.Containers.Count) contenedor(es) en ejecución"
            Write-CenteredBoxLine $containersText $width 'Green'
            
            # Mostrar nombres de contenedores
            $dockerInfo.Containers | ForEach-Object {
                Write-CenteredBoxLine "📦 $_" $width 'White'
            }
        } else {
            Write-CenteredBoxLine "No hay contenedores activos" $width 'Blue'
        }
    } else {
        Write-BoxSeparator $width
        Write-CenteredBoxLine "Docker engine its not running." $width 'White'
    }
    
    # Línea inferior
    Write-Host "╚$('═' * ($width - 2))╝" -ForegroundColor DarkGray
}

# =============================================
# FUNCIÓN DE PROMPT OPTIMIZADA
# =============================================

function Get-GitInfo {
    # Cache mejorado con mejor performance
    if ($Global:GitInfoCache -and (Get-Date) -lt $Global:GitInfoCacheExpiry) {
        return $Global:GitInfoCache
    }
    
    try {
        # Verificar si estamos en un repositorio Git de manera eficiente
        $gitDir = git rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        
        $gitBranch = git branch --show-current 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitBranch) {
            # Verificar estado de manera más eficiente
            $gitStatus = git status --porcelain=v1 --untracked-files=no 2>$null
            $isDirty = $LASTEXITCODE -eq 0 -and $gitStatus
            
            $result = @{
                Branch = $gitBranch
                IsDirty = $isDirty
            }
            
            $Global:GitInfoCache = $result
            $Global:GitInfoCacheExpiry = (Get-Date).AddSeconds(10)  # Cache más largo
            return $result
        }
    } catch {
        # Silencioso
    }
    return $null
}

function prompt {
    # Mostrar información inicial solo la primera vez
    if (-not $Global:TerminalInitialized) {
        Clear-Host
        Show-InitialInfo
        $Global:TerminalInitialized = $true
    }
    
    # Usuario y computadora con colores originales
    Write-Host "(" -NoNewline -ForegroundColor DarkGray
    Write-Host "$env:USERNAME" -NoNewline -ForegroundColor Magenta
    Write-Host "@" -NoNewline -ForegroundColor DarkGray
    Write-Host "$env:COMPUTERNAME" -NoNewline -ForegroundColor Yellow
    Write-Host ") " -NoNewline -ForegroundColor DarkGray
    
    # Ruta actual optimizada
    $currentPath = Get-OptimizedPath
    Write-Host $currentPath -NoNewline -ForegroundColor Blue
    
    # Información de Git con colores originales
    $gitInfo = Get-GitInfo
    if ($gitInfo) {
        Write-Host " (" -NoNewline -ForegroundColor White
        Write-Host $gitInfo.Branch -NoNewline -ForegroundColor Red
        Write-Host ")" -NoNewline -ForegroundColor White
        if ($gitInfo.IsDirty) {
            Write-Host "*" -NoNewline -ForegroundColor Yellow
        }
    }
    
    Write-Host " ⇒" -NoNewline -ForegroundColor Yellow
    return " "
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

# =============================================
# FUNCIONES ÚTILES OPTIMIZADAS
# =============================================

# Navegación rápida
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function cdroot($drive = "C") { Set-Location "${drive}:\" }
function C: { Set-Location "C:\" }
function D: { Set-Location "D:\" }

# Git shortcuts optimizados
function gs { git status --short }
function ga { git add $args }
function gc { param($m) git commit -m $m }
function gp { git push }
function gl { git log --oneline -10 }
function gd { git diff }

# Docker shortcuts optimizados
function dps { docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" }
function dimg { docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" }
function dstop { docker stop $args }
function drm { docker rm $args }
function dprune { docker system prune -f }
function dlogs { docker logs $args }

# Utilidades del sistema optimizadas
function touch($file) { New-Item -ItemType File -Name $file -Force | Out-Null }
function grep($regex, $dir) {
    if ($dir) {
        Get-ChildItem $dir -Recurse | Select-String $regex
    } else {
        $input | Select-String $regex
    }
}

function find-file($name) {
    Get-ChildItem -Recurse -Filter "*${name}*" -ErrorAction SilentlyContinue
}

function Open-Explorer($path = ".") {
    $fullPath = Resolve-Path $path -ErrorAction SilentlyContinue
    if ($fullPath) {
        Start-Process explorer.exe -ArgumentList $fullPath.Path
    } else {
        Write-Warning "Path not found: $path"
    }
}

function Get-DirSize($path = ".") {
    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    [PSCustomObject]@{
        Path = $path
        "Size(MB)" = [math]::Round($size / 1MB, 2)
        "Size(GB)" = [math]::Round($size / 1GB, 3)
    }
}

function Reload-Profile {
    $Global:TerminalInitialized = $false
    $Global:GitInfoCache = $null
    $Global:GitInfoCacheExpiry = (Get-Date).AddSeconds(-1)
    . $PROFILE
}

# =============================================
# CONFIGURACIONES FINALES
# =============================================

# Aliases útiles
Set-Alias which Get-Command
Set-Alias ll Get-ChildItem
Set-Alias la 'Get-ChildItem -Force'
Set-Alias grep Select-String
Set-Alias explorer Open-Explorer

# Limpiar variables al salir
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $Global:TerminalInitialized = $false
    $Global:GitInfoCache = $null
} -ErrorAction SilentlyContinue

# Configuraciones adicionales de rendimiento
$MaximumHistoryCount = 1000