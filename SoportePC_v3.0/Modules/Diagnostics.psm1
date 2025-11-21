# ==========================================
# Diagnostics.psm1
# Modulo: Diagnosticos del sistema
# ==========================================

function Show-DiagnosticsMenu {
    while ($true) {
        Show-Title "MENU - DIAGNOSTICOS DEL SISTEMA"

        Write-Host "1) Diagnostico de rendimiento del sistema" -ForegroundColor White
        Write-Host "2) Verificar eventos criticos" -ForegroundColor White
        Write-Host "3) Diagnostico de salud del disco" -ForegroundColor White
        Write-Host "4) Test de memoria RAM" -ForegroundColor White
        Write-Host "5) Ver servicios problematicos" -ForegroundColor White
        Write-Host "6) Diagnostico de arranque" -ForegroundColor White
        Write-Host "7) Generar informe HTML del sistema" -ForegroundColor White
        Write-Host "0) Volver al menu principal" -ForegroundColor Gray
        Write-Host ""

        $opc = Get-UserChoice "Ingrese una opcion"

        switch ($opc) {
            "1" { Test-SystemPerformance }
            "2" { Get-CriticalEvents }
            "3" { Test-DiskHealth }
            "4" { Test-MemoryRAM }
            "5" { Get-ProblematicServices }
            "6" { Test-BootPerformance }
            "7" { Generate-SystemHtmlReport }
            "0" { return }
            default {
                Write-Host "Opcion invalida." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
        Pause
    }
}

function Test-SystemPerformance {
    Show-Title "DIAGNOSTICO DE RENDIMIENTO DEL SISTEMA"
    
    Write-Host "Analizando rendimiento del sistema..." -ForegroundColor Cyan
    Write-Host ""
    
    # Uso del CPU - Con manejo mejorado de errores
    Write-Host "=== USO DEL CPU ===" -ForegroundColor Yellow
    try {
        # Método alternativo si Get-Counter falla
        $cpuUsage = Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average
        if ($cpuUsage.Average -ne $null) {
            $usage = [math]::Round($cpuUsage.Average, 2)
            $color = if ($usage -gt 80) { "Red" } else { "Green" }
            Write-Host "CPU: $usage porciento" -ForegroundColor $color
        } else {
            # Método de respaldo usando WMI
            $cpu = Get-CimInstance Win32_Processor
            $usage = [math]::Round(($cpu | Measure-Object -Property LoadPercentage -Average).Average, 2)
            $color = if ($usage -gt 80) { "Red" } else { "Green" }
            Write-Host "CPU: $usage porciento" -ForegroundColor $color
        }
    } catch {
        Write-Host "CPU: No disponible - Contadores de rendimiento deshabilitados" -ForegroundColor Yellow
        Write-Host "Sugerencia: Ejecute 'lodctr /r' como administrador para reconstruir contadores" -ForegroundColor Gray
    }
    
    # Uso de memoria
    Write-Host "`n=== USO DE MEMORIA ===" -ForegroundColor Yellow
    try {
        $mem = Get-CimInstance Win32_OperatingSystem
        $totalMem = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
        $freeMem = [math]::Round($mem.FreePhysicalMemory / 1MB, 2)
        $usedMem = $totalMem - $freeMem
        $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 2)
        
        Write-Host "Memoria Total: $totalMem GB" -ForegroundColor White
        Write-Host "Memoria Usada: $usedMem GB" -ForegroundColor White
        Write-Host "Memoria Libre: $freeMem GB" -ForegroundColor White
        Write-Host "Porcentaje de uso: $memPercent porciento" -ForegroundColor $(if ($memPercent -gt 85) { "Red" } elseif ($memPercent -gt 70) { "Yellow" } else { "Green" })
    } catch {
        Write-Host "No se pudo obtener uso de memoria" -ForegroundColor Yellow
    }
    
    # Procesos que más consumen CPU
    Write-Host "`n=== TOP 5 PROCESOS CONSUMO CPU ===" -ForegroundColor Yellow
    try {
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | 
            Format-Table Name, 
                        @{Name="CPU(s)"; Expression={[math]::Round($_.CPU, 2)}}, 
                        @{Name="Memoria(MB)"; Expression={[math]::Round($_.WorkingSet / 1MB, 2)}} -AutoSize
    } catch {
        Write-Host "No se pudieron obtener procesos" -ForegroundColor Yellow
    }
    
    # Procesos que más consumen memoria
    Write-Host "`n=== TOP 5 PROCESOS CONSUMO MEMORIA ===" -ForegroundColor Yellow
    try {
        Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5 | 
            Format-Table Name, 
                        @{Name="Memoria(MB)"; Expression={[math]::Round($_.WorkingSet / 1MB, 2)}}, 
                        @{Name="CPU(s)"; Expression={[math]::Round($_.CPU, 2)}} -AutoSize
    } catch {
        Write-Host "No se pudieron obtener procesos" -ForegroundColor Yellow
    }
    
    # Información adicional del sistema
    Write-Host "`n=== INFORMACION ADICIONAL ===" -ForegroundColor Yellow
    try {
        $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        Write-Host "Tiempo activo: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor Cyan
        
        $processCount = (Get-Process).Count
        Write-Host "Procesos activos: $processCount" -ForegroundColor Cyan
        
        $handleCount = (Get-Process | Measure-Object -Property Handles -Sum).Sum
        Write-Host "Handles totales: $handleCount" -ForegroundColor Cyan
    } catch {
        Write-Host "No se pudo obtener información adicional" -ForegroundColor Yellow
    }
    
    Write-Log "Diagnostico de rendimiento ejecutado" "INFO"
}

function Get-CriticalEvents {
    Show-Title "EVENTOS CRITICOS DEL SISTEMA"
    
    Write-Host "Recopilando eventos criticos (ultimas 24 horas)..." -ForegroundColor Cyan
    Write-Host ""
    
    $startTime = (Get-Date).AddHours(-24)
    $systemEvents = @()
    $appEvents = @()
    
    # Eventos de Sistema
    Write-Host "=== EVENTOS DE SISTEMA (Error/Critico) ===" -ForegroundColor Yellow
    try {
        # Método usando Get-WinEvent (más moderno)
        $systemEvents = Get-WinEvent -LogName 'System' -ErrorAction SilentlyContinue | 
                       Where-Object { $_.TimeCreated -ge $startTime -and ($_.LevelDisplayName -eq 'Error' -or $_.Level -eq 1) } |
                       Sort-Object TimeCreated -Descending |
                       Select-Object -First 20
        
        if ($systemEvents) {
            $systemEvents | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, 
                                         @{Name="Message"; Expression={$_.Message.Substring(0, [math]::Min(100, $_.Message.Length))}} | 
                Format-Table -AutoSize
        } else {
            Write-Host "No se encontraron eventos criticos en Sistema (ultimas 24h)" -ForegroundColor Green
        }
    } catch {
        # Método alternativo usando Get-EventLog
        try {
            Write-Host "Intentando metodo alternativo..." -ForegroundColor Gray
            $systemEvents = Get-EventLog -LogName System -EntryType Error -After $startTime -ErrorAction SilentlyContinue
            if ($systemEvents) {
                $systemEvents | Select-Object TimeGenerated, Source, InstanceId, 
                                             @{Name="Message"; Expression={$_.Message.Substring(0, [math]::Min(100, $_.Message.Length))}} | 
                    Format-Table -AutoSize
            } else {
                Write-Host "No se encontraron eventos criticos en Sistema" -ForegroundColor Green
            }
        } catch {
            Write-Host "No se pudieron obtener eventos del sistema" -ForegroundColor Yellow
            Write-Host "Posible causa: Servicio de registro de eventos no disponible" -ForegroundColor Gray
        }
    }
    
    # Eventos de Aplicación
    Write-Host "`n=== EVENTOS DE APLICACION (Error/Critico) ===" -ForegroundColor Yellow
    try {
        $appEvents = Get-WinEvent -LogName 'Application' -ErrorAction SilentlyContinue | 
                    Where-Object { $_.TimeCreated -ge $startTime -and ($_.LevelDisplayName -eq 'Error' -or $_.Level -eq 1) } |
                    Sort-Object TimeCreated -Descending |
                    Select-Object -First 20
        
        if ($appEvents) {
            $appEvents | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, 
                                      @{Name="Message"; Expression={$_.Message.Substring(0, [math]::Min(100, $_.Message.Length))}} | 
                Format-Table -AutoSize
        } else {
            Write-Host "No se encontraron eventos criticos en Aplicacion (ultimas 24h)" -ForegroundColor Green
        }
    } catch {
        # Método alternativo
        try {
            Write-Host "Intentando metodo alternativo..." -ForegroundColor Gray
            $appEvents = Get-EventLog -LogName Application -EntryType Error -After $startTime -ErrorAction SilentlyContinue
            if ($appEvents) {
                $appEvents | Select-Object TimeGenerated, Source, InstanceId, 
                                          @{Name="Message"; Expression={$_.Message.Substring(0, [math]::Min(100, $_.Message.Length))}} | 
                    Format-Table -AutoSize
            } else {
                Write-Host "No se encontraron eventos criticos en Aplicacion" -ForegroundColor Green
            }
        } catch {
            Write-Host "No se pudieron obtener eventos de aplicacion" -ForegroundColor Yellow
        }
    }
    
    # Resumen
    Write-Host "`n=== RESUMEN ===" -ForegroundColor Yellow
    $systemCount = if ($systemEvents) { $systemEvents.Count } else { 0 }
    $appCount = if ($appEvents) { $appEvents.Count } else { 0 }
    
    Write-Host "Eventos de Sistema: $systemCount" -ForegroundColor $(if ($systemCount -gt 0) { "Red" } else { "Green" })
    Write-Host "Eventos de Aplicacion: $appCount" -ForegroundColor $(if ($appCount -gt 0) { "Red" } else { "Green" })
    
    # Información adicional sobre el estado del servicio de eventos
    Write-Host "`n=== ESTADO DEL SERVICIO DE EVENTOS ===" -ForegroundColor Yellow
    try {
        $eventLogService = Get-Service -Name "EventLog" -ErrorAction SilentlyContinue
        if ($eventLogService) {
            Write-Host "Servicio EventLog: $($eventLogService.Status)" -ForegroundColor $(if ($eventLogService.Status -eq 'Running') { 'Green' } else { 'Red' })
        } else {
            Write-Host "Servicio EventLog: No encontrado" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "No se pudo verificar el servicio de eventos" -ForegroundColor Gray
    }
    
    Write-Log "Eventos criticos consultados. Sistema: $systemCount, App: $appCount" "INFO"
}

function Test-DiskHealth {
    Show-Title "DIAGNOSTICO DE SALUD DEL DISCO"
    
    Write-Host "Analizando salud de los discos..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Información básica de discos
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
        
        foreach ($disk in $disks) {
            Write-Host "=== DISCO $($disk.DeviceID) ===" -ForegroundColor Yellow
            
            $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
            $usedSpaceGB = $totalSpaceGB - $freeSpaceGB
            $percentFree = [math]::Round(($freeSpaceGB / $totalSpaceGB) * 100, 2)
            
            Write-Host "Espacio Total: $totalSpaceGB GB" -ForegroundColor White
            Write-Host "Espacio Libre: $freeSpaceGB GB" -ForegroundColor White
            Write-Host "Espacio Usado: $usedSpaceGB GB" -ForegroundColor White
            Write-Host "Porcentaje Libre: $percentFree porciento" -ForegroundColor $(if ($percentFree -lt 15) { "Red" } elseif ($percentFree -lt 25) { "Yellow" } else { "Green" })
            Write-Host ""
        }
        
        # Recomendaciones
        Write-Host "=== RECOMENDACIONES ===" -ForegroundColor Magenta
        foreach ($disk in $disks) {
            $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
            $percentFree = [math]::Round(($freeSpaceGB / $totalSpaceGB) * 100, 2)
            
            if ($percentFree -lt 10) {
                Write-Host "ATENCION $($disk.DeviceID): Espacio critico! Liberar inmediatamente." -ForegroundColor Red
            } elseif ($percentFree -lt 20) {
                Write-Host "ADVERTENCIA $($disk.DeviceID): Espacio bajo. Considerar limpieza." -ForegroundColor Yellow
            } else {
                Write-Host "OK $($disk.DeviceID): Espacio adecuado." -ForegroundColor Green
            }
        }
        
    } catch {
        Write-Host "Error al obtener informacion de discos: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Log "Diagnostico de salud de discos ejecutado" "INFO"
}

function Test-MemoryRAM {
    Show-Title "TEST DE MEMORIA RAM"
    
    Write-Host "Analizando memoria RAM..." -ForegroundColor Cyan
    Write-Host ""
    
    # Información básica de memoria
    try {
        $memory = Get-CimInstance Win32_ComputerSystem
        $physicalMemory = Get-CimInstance Win32_PhysicalMemory
        $osMemory = Get-CimInstance Win32_OperatingSystem
        
        $totalPhysicalMem = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
        $availableMem = [math]::Round($osMemory.FreePhysicalMemory / 1MB, 2)
        $usedMem = $totalPhysicalMem - ($availableMem / 1024)
        $usagePercent = [math]::Round(($usedMem / $totalPhysicalMem) * 100, 2)
        
        Write-Host "=== INFORMACION DE MEMORIA ===" -ForegroundColor Yellow
        Write-Host "Memoria Total: $totalPhysicalMem GB" -ForegroundColor White
        Write-Host "Memoria Usada: $([math]::Round($usedMem, 2)) GB" -ForegroundColor White
        Write-Host "Memoria Disponible: $([math]::Round($availableMem / 1024, 2)) GB" -ForegroundColor White
        Write-Host "Porcentaje de Uso: $usagePercent porciento" -ForegroundColor $(if ($usagePercent -gt 85) { "Red" } else { "Green" })
        
        # Información de módulos
        Write-Host "`n=== MODULOS DE MEMORIA ===" -ForegroundColor Yellow
        $physicalMemory | ForEach-Object {
            $sizeGB = [math]::Round($_.Capacity / 1GB, 2)
            Write-Host "Modulo: $sizeGB GB - $($_.Speed) MHz - $($_.Manufacturer)" -ForegroundColor Cyan
        }
        
    } catch {
        Write-Host "Error al obtener informacion de memoria: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Diagnóstico de memoria con mdsched (Windows Memory Diagnostic)
    Write-Host "`n=== DIAGNOSTICO AVANZADO ===" -ForegroundColor Yellow
    Write-Host "Para un diagnostico completo de memoria, ejecute Windows Memory Diagnostic." -ForegroundColor White
    $runDiagnostic = Read-Host "Ejecutar diagnostico de memoria ahora? (S/N)"
    
    if ($runDiagnostic -eq "S" -or $runDiagnostic -eq "s") {
        Write-Host "Iniciando Windows Memory Diagnostic..." -ForegroundColor Green
        try {
            Start-Process "mdsched.exe"
            Write-Host "El sistema se reiniciara para realizar el diagnostico." -ForegroundColor Yellow
        } catch {
            Write-Host "No se pudo iniciar el diagnostico de memoria" -ForegroundColor Red
        }
    }
    
    Write-Log "Test de memoria RAM ejecutado" "INFO"
}

function Get-ProblematicServices {
    Show-Title "SERVICIOS PROBLEMATICOS"
    
    Write-Host "Buscando servicios con problemas..." -ForegroundColor Cyan
    Write-Host ""
    
    # Servicios detenidos que deberían estar ejecutándose
    Write-Host "=== SERVICIOS DETENIDOS (Auto/Manual) ===" -ForegroundColor Yellow
    $stoppedServices = Get-Service | Where-Object { 
        $_.Status -eq "Stopped" -and $_.StartType -ne "Disabled" 
    }
    
    if ($stoppedServices) {
        $stoppedServices | Select-Object Name, DisplayName, StartType | 
            Format-Table -AutoSize
    } else {
        Write-Host "No hay servicios detenidos problematicos." -ForegroundColor Green
    }
    
    # Servicios esenciales para verificar
    Write-Host "`n=== VERIFICACION DE SERVICIOS ESENCIALES ===" -ForegroundColor Yellow
    $essentialServices = @(
        @{Name="Winmgmt"; DisplayName="Windows Management Instrumentation"},
        @{Name="EventLog"; DisplayName="Windows Event Log"},
        @{Name="CryptSvc"; DisplayName="Cryptographic Services"},
        @{Name="DcomLaunch"; DisplayName="DCOM Server Process Launcher"},
        @{Name="RpcSs"; DisplayName="Remote Procedure Call"}
    )
    
    foreach ($essential in $essentialServices) {
        $service = Get-Service -Name $essential.Name -ErrorAction SilentlyContinue
        if ($service) {
            $statusColor = if ($service.Status -eq "Running") { "Green" } else { "Red" }
            Write-Host "$($service.Name): $($service.Status)" -ForegroundColor $statusColor
        }
    }
    
    Write-Log "Servicios problematicos consultados" "INFO"
}

function Test-BootPerformance {
    Show-Title "DIAGNOSTICO DE ARRANQUE"
    
    Write-Host "Analizando rendimiento de arranque..." -ForegroundColor Cyan
    Write-Host ""
    
    # Tiempo de arranque desde el evento de inicio
    Write-Host "=== TIEMPO DE ARRANQUE ===" -ForegroundColor Yellow
    try {
        $bootEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ID=100} -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($bootEvents) {
            $bootTime = $bootEvents.TimeCreated
            $uptime = (Get-Date) - $bootTime
            Write-Host "Ultimo arranque: $bootTime" -ForegroundColor White
            Write-Host "Tiempo activo: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor White
        }
    } catch {
        Write-Host "No se pudo obtener informacion de arranque." -ForegroundColor Yellow
    }
    
    # Programas de inicio
    Write-Host "`n=== PROGRAMAS DE INICIO ===" -ForegroundColor Yellow
    try {
        $startupPrograms = Get-CimInstance Win32_StartupCommand | 
            Select-Object Name, Command, Location, User | 
            Sort-Object Location
        
        if ($startupPrograms) {
            $startupPrograms | Format-Table -AutoSize
            Write-Host "Total de programas de inicio: $($startupPrograms.Count)" -ForegroundColor Cyan
        } else {
            Write-Host "No se encontraron programas de inicio" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "No se pudieron obtener programas de inicio" -ForegroundColor Yellow
    }
    
    # Servicios que afectan el arranque
    Write-Host "`n=== SERVICIOS DE ARRANQUE AUTOMATICO ===" -ForegroundColor Yellow
    $autoServices = Get-Service | Where-Object { $_.StartType -eq "Automatic" -and $_.Status -eq "Running" }
    Write-Host "Servicios automaticos ejecutandose: $($autoServices.Count)" -ForegroundColor Cyan
    
    # Recomendaciones
    Write-Host "`n=== RECOMENDACIONES ===" -ForegroundColor Magenta
    $startupCount = if ($startupPrograms) { $startupPrograms.Count } else { 0 }
    if ($startupCount -gt 15) {
        Write-Host "Muchos programas de inicio. Considerar deshabilitar algunos." -ForegroundColor Yellow
    } else {
        Write-Host "Cantidad de programas de inicio aceptable." -ForegroundColor Green
    }
    
    Write-Log "Diagnostico de arranque ejecutado" "INFO"
}

function Generate-SystemHtmlReport {
    Show-Title "GENERAR INFORME HTML DEL SISTEMA"

    Write-Host "Recolectando datos para el informe..." -ForegroundColor Cyan

    # Recolectar datos
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $memoryModules = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
        $nics = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        $servicesStopped = Get-Service | Where-Object { $_.Status -eq "Stopped" -and $_.StartType -ne "Disabled" } -ErrorAction SilentlyContinue
        
        # CORRECCIÓN: Usar solo "Error" en lugar de "Error,Critical"
        $criticalEvents = Get-EventLog -LogName System -EntryType Error -After (Get-Date).AddHours(-24) -ErrorAction SilentlyContinue
        
        $bootEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ID=100} -MaxEvents 1 -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Error al recolectar datos: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Construir nombre por defecto y abrir SaveFileDialog en %TEMP%
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $defaultName = "Reporte_Sistema_$timestamp.html"
    Add-Type -AssemblyName System.Windows.Forms

    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.InitialDirectory = $env:TEMP
    $dlg.FileName = $defaultName
    $dlg.Filter = "HTML files (*.html)|*.html"
    $dlg.Title = "Guardar informe HTML"
    $result = $dlg.ShowDialog()

    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
        return
    }

    $outPath = $dlg.FileName

    # Construir HTML (Estilo 1: profesional, fondo blanco, tablas azules)
    $html = @"
<!DOCTYPE html>
<html lang='es'>
<head>
<meta charset='utf-8'>
<title>Reporte del Sistema - $timestamp</title>
<style>
body { font-family: 'Segoe UI', Tahoma, Arial, sans-serif; background: #ffffff; color: #333333; margin:20px; }
.header { background:#0078d4; color:#ffffff; padding:20px; border-radius:6px; }
.subtitle { color:#f3f6f9; font-size:14px; margin-top:6px; }
.section { margin-top:20px; padding:15px; border:1px solid #e1e1e1; border-radius:6px; background:#ffffff; }
.section h2 { background:#e9f3ff; color:#004a7c; padding:8px; border-radius:4px; }
table { width:100%; border-collapse:collapse; margin-top:10px; }
th { background:#0078d4; color:#ffffff; text-align:left; padding:8px; }
td { padding:8px; border-bottom:1px solid #e9eef3; }
.row-alt { background:#fbfdff; }
.status-good { color:#107c10; font-weight:bold; }
.status-warn { color:#d97706; font-weight:bold; }
.status-bad { color:#a80000; font-weight:bold; }
.footer { margin-top:20px; font-size:12px; color:#666666; }
</style>
</head>
<body>
<div class='header'>
  <h1>Reporte del Sistema</h1>
  <div class='subtitle'>Generado: $timestamp</div>
</div>

<div class='section'>
  <h2>Informacion general</h2>
  <table>
    <tr><th>Campo</th><th>Valor</th></tr>
    <tr><td>Nombre equipo</td><td>$($env:COMPUTERNAME)</td></tr>
    <tr><td>Sistema operativo</td><td>$($os.Caption) $($os.Version)</td></tr>
    <tr><td>Fabricante</td><td>$($os.Manufacturer)</td></tr>
    <tr><td>CPU</td><td>$($cpu.Name)</td></tr>
  </table>
</div>

<div class='section'>
  <h2>Memoria</h2>
  <table>
    <tr><th>Modulo</th><th>Tamano (GB)</th><th>Velocidad (MHz)</th><th>Fabricante</th></tr>
"@

    if ($memoryModules) {
        foreach ($m in $memoryModules) {
            $sizeGB = [math]::Round($m.Capacity / 1GB, 2)
            $html += "<tr><td>Modulo</td><td>$sizeGB</td><td>$($m.Speed)</td><td>$($m.Manufacturer)</td></tr>`n"
        }
    } else {
        $html += "<tr><td colspan='4'>No se detectaron modulos de memoria</td></tr>`n"
    }

    $html += @"
  </table>
</div>

<div class='section'>
  <h2>Discos</h2>
  <table>
    <tr><th>Disco</th><th>Tamano (GB)</th><th>Libre (GB)</th><th>Estado</th></tr>
"@

    if ($disks) {
        foreach ($d in $disks) {
            $size = [math]::Round($d.Size / 1GB, 2)
            $free = [math]::Round($d.FreeSpace / 1GB, 2)
            $percentFree = if ($size -gt 0) { [math]::Round(($free / $size) * 100, 2) } else { 0 }
            $statusClass = if ($percentFree -lt 10) { 'status-bad' } elseif ($percentFree -lt 20) { 'status-warn' } else { 'status-good' }
            $html += "<tr><td>$($d.DeviceID)</td><td>$size</td><td>$free</td><td class='$statusClass'>$percentFree % libre</td></tr>`n"
        }
    } else {
        $html += "<tr><td colspan='4'>No se detectaron discos</td></tr>`n"
    }

    $html += @"
  </table>
</div>

<div class='section'>
  <h2>Red</h2>
  <table>
    <tr><th>Adaptador</th><th>Estado</th><th>MAC</th><th>IP</th></tr>
"@

    if ($nics) {
        foreach ($nic in $nics) {
            $ipAddr = ""
            try {
                $ipObj = Get-NetIPAddress -InterfaceIndex $nic.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($ipObj) { $ipAddr = $ipObj.IPAddress }
            } catch { $ipAddr = "" }
            $html += "<tr><td>$($nic.Name)</td><td>$($nic.Status)</td><td>$($nic.MacAddress)</td><td>$ipAddr</td></tr>`n"
        }
    } else {
        $html += "<tr><td colspan='4'>No se detectaron adaptadores de red activos</td></tr>`n"
    }

    $html += @"
  </table>
</div>

<div class='section'>
  <h2>Servicios detenidos</h2>
  <table>
    <tr><th>Nombre</th><th>DisplayName</th><th>Tipo inicio</th></tr>
"@

    if ($servicesStopped) {
        foreach ($s in $servicesStopped) {
            $html += "<tr><td>$($s.Name)</td><td>$($s.DisplayName)</td><td>$($s.StartType)</td></tr>`n"
        }
    } else {
        $html += "<tr><td colspan='3'>No se detectaron servicios detenidos importantes</td></tr>`n"
    }

    $html += @"
  </table>
</div>

<div class='section'>
  <h2>Eventos criticos (24h)</h2>
  <table>
    <tr><th>Fecha</th><th>ID</th><th>Fuente</th><th>Mensaje</th></tr>
"@

    if ($criticalEvents) {
        foreach ($e in $criticalEvents) {
            $msg = $e.Message -replace '[\r\n]+',' '
            $html += "<tr><td>$($e.TimeGenerated)</td><td>$($e.InstanceId)</td><td>$($e.Source)</td><td>$msg</td></tr>`n"
        }
    } else {
        $html += "<tr><td colspan='4'>No se encontraron eventos criticos en las ultimas 24 horas</td></tr>`n"
    }

    $html += @"
  </table>
</div>

<div class='section'>
  <h2>Resumen de salud</h2>
  <table>
    <tr><th>Indicador</th><th>Valor</th></tr>
"@

    # Calcular health score similar a Get-CompleteSystemReport
    $healthScore = 100
    if ($disks) {
        Get-PSDrive -PSProvider FileSystem | ForEach-Object {
            $freePercent = if ($_.Used -gt 0) { [math]::Round(($_.Free / $_.Used) * 100, 2) } else { 0 }
            if ($freePercent -lt 10) { $healthScore -= 20 }
            elseif ($freePercent -lt 20) { $healthScore -= 10 }
        }
    }

    $memPercent = 0
    if ($os) {
        try {
            $osInfo = Get-CimInstance Win32_OperatingSystem
            $totalMem = [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 2)
            $freeMem = [math]::Round($osInfo.FreePhysicalMemory / 1MB, 2)
            $usedMem = $totalMem - $freeMem
            $memPercent = if ($totalMem -gt 0) { [math]::Round(($usedMem / $totalMem) * 100, 2) } else { 0 }
        } catch { $memPercent = 0 }
    }

    if ($memPercent -gt 90) { $healthScore -= 15 } elseif ($memPercent -gt 80) { $healthScore -= 10 }
    $eventCount = if ($criticalEvents) { $criticalEvents.Count } else { 0 }
    if ($eventCount -gt 5) { $healthScore -= 15 } elseif ($eventCount -gt 0) { $healthScore -= 5 }
    $serviceCount = if ($servicesStopped) { $servicesStopped.Count } else { 0 }
    if ($serviceCount -gt 3) { $healthScore -= 10 } elseif ($serviceCount -gt 0) { $healthScore -= 5 }

    if ($healthScore -lt 0) { $healthScore = 0 }

    $html += "<tr><td>Health Score</td><td>$healthScore / 100</td></tr>`n"
    $statusText = if ($healthScore -ge 80) { 'BUEN ESTADO' } elseif ($healthScore -ge 60) { 'MANTENIMIENTO RECOMENDADO' } else { 'ATENCION INMEDIATA' }
    $html += "<tr><td>Estado general</td><td>$statusText</td></tr>`n"

    $html += @"
  </table>
</div>

<div class='footer'>
  Reporte generado por Sistema de Soporte Tecnico
</div>
</body>
</html>
"@

    # Guardar archivo
    try {
        $html | Out-File -FilePath $outPath -Encoding UTF8
        Write-Host "Informe guardado en: $outPath" -ForegroundColor Green
        Write-Log "Informe HTML generado: $outPath" "SUCCESS"
        # Abrir en navegador por defecto
        try { Start-Process $outPath } catch {}
    } catch {
        Write-Host "No se pudo guardar el informe: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Error al guardar informe HTML: $($_.Exception.Message)" "ERROR"
    }
}

Export-ModuleMember -Function Show-DiagnosticsMenu, Test-*, Get-*, Test-*, Generate-SystemHtmlReport