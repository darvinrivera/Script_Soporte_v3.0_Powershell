function Get-DetailedHardwareInfo {
    Show-Title "INFORMACION DETALLADA DE HARDWARE"
    
    # Cargar diccionarios para traducción de monitores
    $scriptDir = $PSScriptRoot
    $dicMarca = @{}
    $dicModelo = @{}
    
    if ($scriptDir) {
        $marcasFile = Join-Path $scriptDir "marcas.txt"
        $modelosFile = Join-Path $scriptDir "modelos.txt"
        
        if (Test-Path $marcasFile) {
            Get-Content $marcasFile | Where-Object { $_ -match '^([^=]+)=(.*)$' } | ForEach-Object {
                $dicMarca[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
        
        if (Test-Path $modelosFile) {
            Get-Content $modelosFile | Where-Object { $_ -match '^([^=]+)=(.*)$' } | ForEach-Object {
                $dicModelo[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }

    try {
        Write-Host "=== PROCESADOR ===" -ForegroundColor Yellow
        $processors = Get-CimInstance Win32_Processor
        foreach ($cpu in $processors) {
            Write-Host "Procesador: $($cpu.Name)" -ForegroundColor Cyan
            Write-Host "Nucleos: $($cpu.NumberOfCores) fisicos, $($cpu.NumberOfLogicalProcessors) logicos" -ForegroundColor Cyan
            Write-Host "Velocidad: $($cpu.MaxClockSpeed) MHz" -ForegroundColor Cyan
#            Write-Host "Socket: $($cpu.SocketDesignation)" -ForegroundColor Cyan
            Write-Host "Fabricante: $($cpu.Manufacturer)" -ForegroundColor Cyan
            
            # Estrategia mejorada para obtener número de serie
            $cpuSerial = $cpu.SerialNumber
            $cpuProcessorId = $cpu.ProcessorId
            
            # Filtrar valores genéricos/inválidos comunes
            $invalidSerials = @(
                "", "None", "Not Specified", "To Be Filled By O.E.M.", 
                "OEM_Not_To_Be_Displayed", "00000000", "0000000000000000",
                "0123456789", "123456789", "xxxxxxxx", "XXXXXXX", "Unknown"
            )
            
            # Verificar si el SerialNumber es válido
            if ([string]::IsNullOrWhiteSpace($cpuSerial) -or $invalidSerials -contains $cpuSerial) {
                # Intentar con ProcessorId como alternativa
                if (-not [string]::IsNullOrWhiteSpace($cpuProcessorId) -and 
                    $cpuProcessorId -notmatch "^0+$" -and 
                    $invalidSerials -notcontains $cpuProcessorId) {
                    $cpuSerial = "ProcessorID: $cpuProcessorId"
                } else {
                    # Si todo falla, intentar obtener información de BIOS/Board
                    $boardSerial = (Get-CimInstance Win32_BaseBoard).SerialNumber
                    if (-not [string]::IsNullOrWhiteSpace($boardSerial) -and 
                        $invalidSerials -notcontains $boardSerial) {
                        $cpuSerial = "BoardSerial: $boardSerial (referencia)"
                    } else {
                        $cpuSerial = "No Disponible / OEM"
                    }
                }
            }
            
            Write-Host "Identificador Unico: $cpuSerial" -ForegroundColor Cyan
            
            # Información adicional útil
            Write-Host "Familia: $($cpu.Family) - Modelo: $($cpu.Description)" -ForegroundColor Cyan
            
            # Información de caché
            $l2 = if ($cpu.L2CacheSize) { "$($cpu.L2CacheSize) KB" } else { "N/A" }
            $l3 = if ($cpu.L3CacheSize) { "$($cpu.L3CacheSize) KB" } else { "N/A" }
            Write-Host "Cache: L2=$l2, L3=$l3" -ForegroundColor Cyan
            
            # Estado de virtualización
#            $virtualizationEnabled = if ($cpu.VirtualizationFirmwareEnabled) { "Sí" } else { "No" }
#            Write-Host "Virtualizacion Habilitada: $virtualizationEnabled" -ForegroundColor Cyan
            
            Write-Host ""
        }

        Write-Host "=== MEMORIA RAM ===" -ForegroundColor Yellow
        $memory = Get-CimInstance Win32_PhysicalMemory
        $totalMemory = 0
        $moduloCount = 0
        
        if ($memory) {
            foreach ($mem in $memory) {
                $moduloCount++
                $sizeGB = [math]::Round($mem.Capacity / 1GB, 2)
                $totalMemory += $sizeGB
                
                Write-Host "Modulo #$moduloCount" -ForegroundColor Yellow
                Write-Host "Capacidad: $sizeGB GB" -ForegroundColor Cyan
                Write-Host "Velocidad: $($mem.Speed) MHz" -ForegroundColor Cyan
                Write-Host "Fabricante: $($mem.Manufacturer)" -ForegroundColor Cyan
                Write-Host "Numero de Serie: $($mem.SerialNumber)" -ForegroundColor Cyan
#                Write-Host "Banco/Slot: $($mem.BankLabel)" -ForegroundColor Cyan
#                Write-Host "Tipo: $($mem.MemoryType)" -ForegroundColor Cyan
#                Write-Host "Form Factor: $($mem.FormFactor)" -ForegroundColor Cyan
                
                # Información adicional si está disponible
#                if ($mem.PartNumber) {
#                    Write-Host "Numero de Parte: $($mem.PartNumber)" -ForegroundColor Cyan
#                }
                
                Write-Host ""
            }
            
            Write-Host "RESUMEN DE MEMORIA RAM" -ForegroundColor Green
            Write-Host "Total de Modulos: $moduloCount" -ForegroundColor Green
            Write-Host "Total Capacidad: $totalMemory GB" -ForegroundColor Green
        } else {
            Write-Host "No se pudo obtener información de la memoria RAM" -ForegroundColor Red
        }

        Write-Host "`n=== ALMACENAMIENTO ===" -ForegroundColor Yellow
        $disks = Get-CimInstance Win32_DiskDrive
        foreach ($disk in $disks) {
            $sizeGB = [math]::Round($disk.Size / 1GB, 2)
            Write-Host "Disco: $($disk.Model)" -ForegroundColor Cyan
            Write-Host "Numero de Serie: $($disk.SerialNumber)" -ForegroundColor Cyan
            Write-Host "Tamaño: $sizeGB GB - Interface: $($disk.InterfaceType)" -ForegroundColor Cyan
            Write-Host ""
        }

        Write-Host "=== TARJETAS DE VIDEO ===" -ForegroundColor Yellow
        $gpus = Get-CimInstance Win32_VideoController
        foreach ($gpu in $gpus) {
            if ($gpu.Name -notlike "*Remote*" -and $gpu.Name -notlike "*Mirror*") {
                $vramMB = if ($gpu.AdapterRAM -gt 0) { [math]::Round($gpu.AdapterRAM / 1MB, 2) } else { "Desconocido" }
                Write-Host "GPU: $($gpu.Name)" -ForegroundColor Cyan
                Write-Host "Numero de Serie: $($gpu.SerialNumber)" -ForegroundColor Cyan
                Write-Host "VRAM: $vramMB MB - Driver: $($gpu.DriverVersion)" -ForegroundColor Cyan
                Write-Host ""
            }
        }

        # NUEVA SECCIÓN DE MONITORES
        Write-Host "=== MONITORES ===" -ForegroundColor Yellow
        try {
            $monitores = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue
            
            if (-not $monitores) {
                Write-Host "No se detectaron monitores o no hay información disponible." -ForegroundColor Red
            } else {
                $indice = 1
                foreach ($mon in $monitores) {
                    # Obtener y traducir Marca
                    $codigoMarca = "N/A"
                    if ($mon.ManufacturerName -and $mon.ManufacturerName.Count -ge 3) {
                        $codigoMarca = ($mon.ManufacturerName[0..2] | ForEach-Object { 
                            if ($_ -gt 0) { [char]$_ } else { '' }
                        }) -join ''
                    }
                    $marcaFinal = if ($dicMarca.ContainsKey($codigoMarca)) { 
                        $dicMarca[$codigoMarca] 
                    } else { 
                        $codigoMarca 
                    }

                    # Obtener Modelo
                    $modeloCodigo = "No Reportado"
                    if ($mon.UserFriendlyName -and $mon.UserFriendlyName.Count -gt 0) {
                        $modeloCodigo = ($mon.UserFriendlyName | ForEach-Object { 
                            if ($_ -gt 0) { [char]$_ } else { '' }
                        }) -join ''
                    }
                    $modeloFinal = if ($dicModelo.ContainsKey($modeloCodigo)) { 
                        $dicModelo[$modeloCodigo] 
                    } else { 
                        $modeloCodigo 
                    }

                    # Obtener Número de Serie
                    $serial = "No Reportado"
                    if ($mon.SerialNumberID -and $mon.SerialNumberID.Count -gt 0) {
                        $serial = ($mon.SerialNumberID | ForEach-Object { 
                            if ($_ -gt 0) { [char]$_ } else { '' }
                        }) -join ''
                    }

                    # Obtener Código de Producto
                    $producto = "N/A"
                    if ($mon.ProductCodeID -and $mon.ProductCodeID.Count -gt 0) {
                        $producto = ($mon.ProductCodeID | ForEach-Object { 
                            if ($_ -gt 0) { [char]$_ } else { '' }
                        }) -join ''
                    }

                    Write-Host "Monitor #$indice" -ForegroundColor Cyan
#                    Write-Host "Activo: $(if ($mon.Active) { 'Si' } else { 'No' })" -ForegroundColor Cyan
                    Write-Host "Marca: $marcaFinal" -ForegroundColor Cyan
                    Write-Host "Modelo: $modeloFinal" -ForegroundColor Cyan
                    Write-Host "Numero de Serie: $serial" -ForegroundColor Cyan
#                    Write-Host "Codigo de Producto: $producto" -ForegroundColor Cyan
#                    Write-Host "Fecha de Fabricacion: $(if ($mon.YearOfManufacture) { $mon.YearOfManufacture } else { 'N/A' })" -ForegroundColor Cyan
                    Write-Host ""
                    
                    $indice++
                }
            }
        } catch {
            Write-Host "Error al obtener informacion de monitores: $($_.Exception.Message)" -ForegroundColor Red
        }

        # NUEVA SECCIÓN: PLACA BASE
        Write-Host "=== PLACA BASE ===" -ForegroundColor Yellow
        try {
            $boards = Get-CimInstance Win32_BaseBoard
            
            foreach ($board in $boards) {
                # Filtrar valores genéricos comunes en placas base
                $invalidValues = @(
                    "To Be Filled By O.E.M.", "OEM_Not_To_Be_Displayed",
                    "Default string", "Not Available", "Not Specified",
                    "123456789", "00000000", "xxxxxxxx", "XXXXXXX"
                )
                
                # Obtener fabricante
                $fabricante = $board.Manufacturer
                if ($invalidValues -contains $fabricante -or [string]::IsNullOrWhiteSpace($fabricante)) {
                    $fabricante = "No Disponible / OEM"
                }
                
                # Obtener modelo/producto
                $modelo = $board.Product
                if ($invalidValues -contains $modelo -or [string]::IsNullOrWhiteSpace($modelo)) {
                    $modelo = "No Disponible"
                }
                
                # Obtener número de serie
                $serialNumber = $board.SerialNumber
                if ($invalidValues -contains $serialNumber -or [string]::IsNullOrWhiteSpace($serialNumber)) {
                    $serialNumber = "No Disponible"
                }
                
                # Obtener versión
                $version = $board.Version
                if ($invalidValues -contains $version -or [string]::IsNullOrWhiteSpace($version)) {
                    $version = "N/A"
                }
                
                Write-Host "Fabricante: $fabricante" -ForegroundColor Cyan
                Write-Host "Modelo: $modelo" -ForegroundColor Cyan
                Write-Host "Numero de Serie: $serialNumber" -ForegroundColor Cyan
                Write-Host "Version: $version" -ForegroundColor Cyan
                
                # Información adicional sobre slots
#                $slots = Get-CimInstance Win32_SystemEnclosure
#                if ($slots) {
#                    Write-Host "Tipo de Chasis: $($slots.ChassisTypes[0])" -ForegroundColor Cyan
#                }
                
                # Información de BIOS
#                $bios = Get-CimInstance Win32_BIOS
#                if ($bios) {
#                    Write-Host "BIOS: $($bios.Manufacturer) - Versión: $($bios.SMBIOSBIOSVersion)" -ForegroundColor Cyan
#                    Write-Host "Serial BIOS: $($bios.SerialNumber)" -ForegroundColor Cyan
#                }
                
                Write-Host ""
            }
        } catch {
            Write-Host "Error al obtener informacion de la placa base: $($_.Exception.Message)" -ForegroundColor Red
        }
	
    } catch {
        Write-Host "Error al obtener informacion de hardware: $($_.Exception.Message)" -ForegroundColor Red
    }
}
