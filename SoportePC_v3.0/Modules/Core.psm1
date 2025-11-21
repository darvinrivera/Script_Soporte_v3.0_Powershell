# ==========================================
# Core.psm1
# Funciones base del sistema de soporte
# ==========================================

function Clear-Screen {
    Clear-Host
}

function Show-Title {
    param([string]$Text)
    Clear-Screen
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Pause {
    Write-Host ""
    Write-Host "Presione ENTER para continuar..." -ForegroundColor Gray -NoNewline
    $null = Read-Host
}

function Get-UserChoice {
    param([string]$Message = "Seleccione una opcion")
    Write-Host ""
    Write-Host "$Message : " -ForegroundColor Cyan -NoNewline
    $opc = Read-Host
    return $opc.Trim()
}

function Show-Welcome {
    Show-Title "SISTEMA DE SOPORTE TECNICO - PC MAINTENANCE"
    Write-Host "Version: 3.0" -ForegroundColor Green
    Write-Host "Modulos cargados: Core, Info, Maintenance, Repair, Network, Diagnostics" -ForegroundColor Green
    Write-Host "Estado: OK Sistema listo" -ForegroundColor Green
    Write-Host ""
    Write-Host "Desarrollado para mantenimiento y diagnostico de sistemas Windows" -ForegroundColor Gray
    Write-Host ""
}

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-AdminWarning {
    if (-not (Test-AdminPrivileges)) {
        Write-Host "ADVERTENCIA: Algunas funciones requieren permisos de administrador" -ForegroundColor Yellow
        Write-Host "   Ejecute el script como administrador para acceso completo" -ForegroundColor Yellow
        Write-Host ""
    }
}

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    
    $logPath = Join-Path $PSScriptRoot "soporte_pc.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Type] $Message"
    
    Add-Content -Path $logPath -Value $logEntry
    
    switch ($Type) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        default { Write-Host $Message -ForegroundColor White }
    }
}

# ==========================================
# Menu Principal
# ==========================================

function Show-MainMenu {
    while ($true) {
        Show-Title "MENU PRINCIPAL - by Smith Lozano"
        Show-AdminWarning
        
        Write-Host "1) Informacion del sistema" -ForegroundColor White
        Write-Host "2) Limpieza y mantenimiento" -ForegroundColor White
        Write-Host "3) Reparacion del sistema" -ForegroundColor White
        Write-Host "4) Herramientas de red" -ForegroundColor White
        Write-Host "5) Diagnosticos avanzados" -ForegroundColor White
        Write-Host "6) Ver log de actividades" -ForegroundColor White
        Write-Host "0) Salir" -ForegroundColor Red
        Write-Host ""

        $opc = Get-UserChoice "Ingrese una opcion"

        switch ($opc) {
            "1" { 
                Write-Log "Usuario accedio a Informacion del sistema" "INFO"
                if (Get-Command -Name "Show-InfoMenu" -ErrorAction SilentlyContinue) {
                    Show-InfoMenu 
                } else {
                    Write-Host "Modulo de Informacion no disponible" -ForegroundColor Red
                    Pause
                }
            }
            "2" { 
                Write-Log "Usuario accedio a Limpieza y mantenimiento" "INFO"
                if (Get-Command -Name "Show-MaintenanceMenu" -ErrorAction SilentlyContinue) {
                    Show-MaintenanceMenu 
                } else {
                    Write-Host "Modulo de Mantenimiento no disponible" -ForegroundColor Red
                    Pause
                }
            }
            "3" { 
                Write-Log "Usuario accedio a Reparacion del sistema" "INFO"
                if (Get-Command -Name "Show-RepairMenu" -ErrorAction SilentlyContinue) {
                    Show-RepairMenu 
                } else {
                    Write-Host "Modulo de Reparacion no disponible" -ForegroundColor Red
                    Pause
                }
            }
            "4" { 
                Write-Log "Usuario accedio a Herramientas de red" "INFO"
                if (Get-Command -Name "Show-NetworkMenu" -ErrorAction SilentlyContinue) {
                    Show-NetworkMenu 
                } else {
                    Write-Host "Modulo de Red no disponible" -ForegroundColor Red
                    Pause
                }
            }
            "5" { 
                Write-Log "Usuario accedio a Diagnosticos avanzados" "INFO"
                if (Get-Command -Name "Show-DiagnosticsMenu" -ErrorAction SilentlyContinue) {
                    Show-DiagnosticsMenu 
                } else {
                    Write-Host "Modulo de Diagnosticos no disponible" -ForegroundColor Red
                    Pause
                }
            }
            "6" { 
                Show-ActivityLog 
            }
            "0" { 
                Write-Log "Usuario salio del sistema" "INFO"
                Show-Title "Saliendo del sistema de soporte..."
                Write-Host "Hasta pronto!" -ForegroundColor Green
                Start-Sleep -Seconds 2
                return
            }
            default {
                Write-Log "Opcion invalida seleccionada: $opc" "WARNING"
                Write-Host "Opcion invalida. Intente nuevamente." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}

function Show-ActivityLog {
    Show-Title "LOG DE ACTIVIDADES"
    $logPath = Join-Path $PSScriptRoot "soporte_pc.log"
    
    if (Test-Path $logPath) {
        Write-Host "Ultimas actividades del sistema:" -ForegroundColor Cyan
        Write-Host ""
        Get-Content $logPath | ForEach-Object {
            if ($_ -match "ERROR") {
                Write-Host $_ -ForegroundColor Red
            } elseif ($_ -match "WARNING") {
                Write-Host $_ -ForegroundColor Yellow
            } elseif ($_ -match "SUCCESS") {
                Write-Host $_ -ForegroundColor Green
            } else {
                Write-Host $_ -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "No hay registros de actividad aun." -ForegroundColor Yellow
    }
    Pause
}

Export-ModuleMember -Function Show-*, Get-*, Clear-*, Pause, Test-*, Write-Log