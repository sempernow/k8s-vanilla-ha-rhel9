param (
    [string]$VMName = "a3",
    [string]$VHDXPath = "S:\Hyper-V\$VMname\Virtual Hard Disks",
    [string]$VHDXName = "$VMname-static-etcd.vhdx",
    [int]$SizeGB = 2
)

# Ensure target path exists
if (-not (Test-Path -Path "$VHDXPath")) {
    New-Item -Path "$VHDXPath" -ItemType Directory -Force
}

# Full VHDX path
$VHDXFullPath = Join-Path -Path "$VHDXPath" -ChildPath $VHDXName

# Create a fixed-size 2GiB VHDX
$SizeBytes = $SizeGB * 1GB
New-VHD -Path "$VHDXFullPath" -SizeBytes $SizeBytes -Fixed | Out-Null

# Attach the VHDX to the VM's SCSI Controller
Add-VMHardDiskDrive -VMName $VMName -Path "$VHDXFullPath" -ControllerType SCSI

Write-Host "✅ VHDX created at '$VHDXFullPath' and attached to VM '$VMName' under SCSI controller."
