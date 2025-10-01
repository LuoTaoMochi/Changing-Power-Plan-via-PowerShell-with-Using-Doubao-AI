<#
.SYNOPSIS
����Windows��Դ�ƻ��Ĺ���
#>

# ��鲢��ȡ����ԱȨ��
try {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "`n��Ҫ����ԱȨ�޲����޸ĵ�Դ�ƻ�����������Ȩ��..." -ForegroundColor Yellow
        
        # �Թ���Ա����������нű�
        $scriptPath = $MyInvocation.MyCommand.Definition
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        exit
    }
}
catch {
    Write-Host "`n��ȡ����ԱȨ��ʱ����: $_" -ForegroundColor Red
    Read-Host "��������˳�..."
    exit
}

# ����ע���CsEnabledֵ
function Set-CsEnabledRegistry {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    $regKey = "CsEnabled"
    $targetValue = 0

    try {
        # ���ע���·���Ƿ����
        if (-not (Test-Path -Path $regPath)) {
            Write-Host "`nע���·�� $regPath �����ڣ����ڴ���..." -ForegroundColor Cyan
            New-Item -Path $regPath -Force | Out-Null
        }

        # ���CsEnabledֵ�Ƿ����
        $currentValue = Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $regKey -ErrorAction SilentlyContinue

        if ($null -eq $currentValue) {
            # ����������ֵΪ0
            New-ItemProperty -Path $regPath -Name $regKey -Value $targetValue -PropertyType DWord -Force | Out-Null
            Write-Host "ע����в����� $regKey�����½�����ֵ����Ϊ $targetValue��" -ForegroundColor Green
        }
        else {
            if ($currentValue -ne $targetValue) {
                # �޸�����ֵΪ0
                Set-ItemProperty -Path $regPath -Name $regKey -Value $targetValue -Force
                Write-Host "ע����� $regKey ��ǰֵΪ $currentValue�����޸�Ϊ $targetValue��" -ForegroundColor Green
            }
            else {
                # ֵ��Ϊ0�������޸�
                Write-Host "ע����� $regKey ��Ϊ $targetValue�������޸ġ�" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "`n����ע���ʱ����: $_" -ForegroundColor Red
        Read-Host "��������˳�..."
        exit
    }
}

# ִ��ע���������ò���
Set-CsEnabledRegistry
Read-Host "`nע����������ɣ�����������빦��ѡ��˵�..."

# �����Դ�ƻ�
$powerSchemes = @(
    @{ Name = "����"; Guid = "a1841308-3541-4fab-bc81-f71556f20b4a" },
    @{ Name = "ƽ��"; Guid = "381b4222-f694-41f0-9685-ff5bb260df2e" },
    @{ Name = "������"; Guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" },
    @{ Name = "׿Խ����"; Guid = "e9a42b02-d5df-448d-aa00-03f14749eb61" }
)

# ��ʾ�˵�
function Show-Menu {
    Clear-Host
    Write-Host "===== ��Դ�ƻ����� =====" -ForegroundColor Green
    Write-Host "1. �л�������ģʽ"
    Write-Host "2. �л���ƽ��ģʽ"
    Write-Host "3. �л���������ģʽ"
    Write-Host "4. �л���׿Խ����ģʽ"
    Write-Host "5. ��ʾ���е�Դ�ƻ�"
    Write-Host "`n������ѡ�� (1-5)��ֱ���˳�"
    Write-Host "========================" -ForegroundColor Green
}

# �л���Դ�ƻ�
function Switch-Scheme {
    param(
        [string]$name,
        [string]$guid
    )
    
    try {
        Write-Host "`n�����л���$nameģʽ..."
        
        # ���Ʒ���
        Write-Host "���Ƶ�Դ����..."
        $copyOutput = powercfg -duplicatescheme $guid 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "���Ʒ���ʧ��: $copyOutput"
        }
        
        # ��ȡ��GUID
        $newGuid = $null
        foreach ($line in $copyOutput) {
            if ($line -match '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}') {
                $newGuid = $matches[0]
                break
            }
        }
        
        if (-not $newGuid) {
            throw "�޷���ȡ�·���GUID"
        }
        
        # �����
        Write-Host "�����Դ����..."
        $activateOutput = powercfg -setactive $newGuid 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "�����ʧ��: $activateOutput"
        }
        
        Write-Host "`n�ɹ��л���$nameģʽ��" -ForegroundColor Green
    }
    catch {
        Write-Host "`n����ʧ��: $_" -ForegroundColor Red
    }
}

# �����Դ����
function Manage-Schemes {
    do {
        Clear-Host
        Write-Host "===== ���е�Դ�ƻ� =====" -ForegroundColor Green
        
        # ��ȡ����ʾ����
        try {
            $schemes = powercfg /L 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "�޷���ȡ�����б�: $schemes"
            }
            Write-Host $schemes
        }
        catch {
            Write-Host "����: $_" -ForegroundColor Red
            Read-Host "�����������..."
            return
        }
        
        # ���������б�
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
        
        Write-Host "`n===== ����ѡ�� =====" -ForegroundColor Green
        Write-Host "������Ҫɾ���ķ������ (1-$($schemeList.Count))"
        Write-Host "0 - �������˵�"
        Write-Host "5 - ˢ���б�"
        Write-Host "������ - �˳�"
        
        $choice = Read-Host "������ѡ��"
        
        if ($choice -eq "0") { return }
        elseif ($choice -eq "5") { continue }
        elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $schemeList.Count) {
            $index = [int]$choice - 1
            $selected = $schemeList[$index]
            
            # ����Ƿ�Ϊ��ǰʹ�õķ���
            if ($selected.Name -match '\*') {
                Write-Host "`n����ɾ����ǰ����ʹ�õĵ�Դ������" -ForegroundColor Red
            }
            else {
                try {
                    Write-Host "`n����ɾ�� $($selected.Name)..."
                    $result = powercfg /d $selected.Guid 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "ɾ��ʧ��: $result"
                    }
                    Write-Host "ɾ���ɹ���" -ForegroundColor Green
                }
                catch {
                    Write-Host "����: $_" -ForegroundColor Red
                }
            }
            Read-Host "�����������..."
        }
        else {
            exit
        }
    } while ($true)
}

# ������
try {
    do {
        Show-Menu
        $input = Read-Host "��ѡ��"
        
        if ($input -eq "1" -or $input -eq "2" -or $input -eq "3" -or $input -eq "4") {
            $index = [int]$input - 1
            Switch-Scheme -name $powerSchemes[$index].Name -guid $powerSchemes[$index].Guid
            Read-Host "`n��������������˵�..."
        }
        elseif ($input -eq "5") {
            Manage-Schemes
        }
        else {
            Write-Host "`n�˳�����..."
            exit
        }
    } while ($true)
}
catch {
    Write-Host "`n�������: $_" -ForegroundColor Red
    Read-Host "��������˳�..."
    exit
}
