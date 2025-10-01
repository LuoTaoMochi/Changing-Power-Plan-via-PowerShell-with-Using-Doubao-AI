<#
.SYNOPSIS
管理Windows电源计划的工具
#>

# 检查并获取管理员权限
try {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "`n需要管理员权限才能修改电源计划，正在请求权限..." -ForegroundColor Yellow
        
        # 以管理员身份重新运行脚本
        $scriptPath = $MyInvocation.MyCommand.Definition
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        exit
    }
}
catch {
    Write-Host "`n获取管理员权限时出错: $_" -ForegroundColor Red
    Read-Host "按任意键退出..."
    exit
}

# 处理注册表CsEnabled值
function Set-CsEnabledRegistry {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    $regKey = "CsEnabled"
    $targetValue = 0

    try {
        # 检查注册表路径是否存在
        if (-not (Test-Path -Path $regPath)) {
            Write-Host "`n注册表路径 $regPath 不存在，正在创建..." -ForegroundColor Cyan
            New-Item -Path $regPath -Force | Out-Null
        }

        # 检查CsEnabled值是否存在
        $currentValue = Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $regKey -ErrorAction SilentlyContinue

        if ($null -eq $currentValue) {
            # 创建并设置值为0
            New-ItemProperty -Path $regPath -Name $regKey -Value $targetValue -PropertyType DWord -Force | Out-Null
            Write-Host "注册表中不存在 $regKey，已新建并将值设置为 $targetValue。" -ForegroundColor Green
        }
        else {
            if ($currentValue -ne $targetValue) {
                # 修改现有值为0
                Set-ItemProperty -Path $regPath -Name $regKey -Value $targetValue -Force
                Write-Host "注册表中 $regKey 当前值为 $currentValue，已修改为 $targetValue。" -ForegroundColor Green
            }
            else {
                # 值已为0，无需修改
                Write-Host "注册表中 $regKey 已为 $targetValue，无需修改。" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "`n处理注册表时出错: $_" -ForegroundColor Red
        Read-Host "按任意键退出..."
        exit
    }
}

# 执行注册表检查和设置操作
Set-CsEnabledRegistry
Read-Host "`n注册表操作已完成，按任意键进入功能选择菜单..."

# 定义电源计划
$powerSchemes = @(
    @{ Name = "节能"; Guid = "a1841308-3541-4fab-bc81-f71556f20b4a" },
    @{ Name = "平衡"; Guid = "381b4222-f694-41f0-9685-ff5bb260df2e" },
    @{ Name = "高性能"; Guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" },
    @{ Name = "卓越性能"; Guid = "e9a42b02-d5df-448d-aa00-03f14749eb61" }
)

# 显示菜单
function Show-Menu {
    Clear-Host
    Write-Host "===== 电源计划管理 =====" -ForegroundColor Green
    Write-Host "1. 切换到节能模式"
    Write-Host "2. 切换到平衡模式"
    Write-Host "3. 切换到高性能模式"
    Write-Host "4. 切换到卓越性能模式"
    Write-Host "5. 显示所有电源计划"
    Write-Host "`n请输入选择 (1-5)或直接退出"
    Write-Host "========================" -ForegroundColor Green
}

# 切换电源计划
function Switch-Scheme {
    param(
        [string]$name,
        [string]$guid
    )
    
    try {
        Write-Host "`n正在切换到$name模式..."
        
        # 复制方案
        Write-Host "复制电源方案..."
        $copyOutput = powercfg -duplicatescheme $guid 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "复制方案失败: $copyOutput"
        }
        
        # 获取新GUID
        $newGuid = $null
        foreach ($line in $copyOutput) {
            if ($line -match '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}') {
                $newGuid = $matches[0]
                break
            }
        }
        
        if (-not $newGuid) {
            throw "无法获取新方案GUID"
        }
        
        # 激活方案
        Write-Host "激活电源方案..."
        $activateOutput = powercfg -setactive $newGuid 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "激活方案失败: $activateOutput"
        }
        
        Write-Host "`n成功切换到$name模式！" -ForegroundColor Green
    }
    catch {
        Write-Host "`n操作失败: $_" -ForegroundColor Red
    }
}

# 管理电源方案
function Manage-Schemes {
    do {
        Clear-Host
        Write-Host "===== 所有电源计划 =====" -ForegroundColor Green
        
        # 获取并显示方案
        try {
            $schemes = powercfg /L 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "无法获取方案列表: $schemes"
            }
            Write-Host $schemes
        }
        catch {
            Write-Host "错误: $_" -ForegroundColor Red
            Read-Host "按任意键返回..."
            return
        }
        
        # 解析方案列表
        $schemeList = @()
        $lines = $schemes -split "`n"
        foreach ($line in $lines) {
            if ($line -match '([A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12})\s+(.*)') {
                $schemeList += [PSCustomObject]@{
                    Guid = $matches[1]
                    Name = $matches[3].Trim()
                }
            }
        }
        
        Write-Host "`n===== 操作选择 =====" -ForegroundColor Green
        Write-Host "请输入要删除的方案序号 (1-$($schemeList.Count))"
        Write-Host "0 - 返回主菜单"
        Write-Host "5 - 刷新列表"
        Write-Host "其他键 - 退出"
        
        $choice = Read-Host "请输入选择"
        
        if ($choice -eq "0") { return }
        elseif ($choice -eq "5") { continue }
        elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $schemeList.Count) {
            $index = [int]$choice - 1
            $selected = $schemeList[$index]
            
            # 检查是否为当前使用的方案
            if ($selected.Name -match '\*') {
                Write-Host "`n不能删除当前正在使用的电源方案！" -ForegroundColor Red
            }
            else {
                try {
                    Write-Host "`n正在删除 $($selected.Name)..."
                    $result = powercfg /d $selected.Guid 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "删除失败: $result"
                    }
                    Write-Host "删除成功！" -ForegroundColor Green
                }
                catch {
                    Write-Host "错误: $_" -ForegroundColor Red
                }
            }
            Read-Host "按任意键继续..."
        }
        else {
            exit
        }
    } while ($true)
}

# 主程序
try {
    do {
        Show-Menu
        $input = Read-Host "请选择"
        
        if ($input -eq "1" -or $input -eq "2" -or $input -eq "3" -or $input -eq "4") {
            $index = [int]$input - 1
            Switch-Scheme -name $powerSchemes[$index].Name -guid $powerSchemes[$index].Guid
            Read-Host "`n按任意键返回主菜单..."
        }
        elseif ($input -eq "5") {
            Manage-Schemes
        }
        else {
            Write-Host "`n退出程序..."
            exit
        }
    } while ($true)
}
catch {
    Write-Host "`n程序错误: $_" -ForegroundColor Red
    Read-Host "按任意键退出..."
    exit
}
