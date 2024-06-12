
@{
RootModule = 'module.psm1'
ModuleVersion = '2.4'
#CompatiblePSEditions = 'Desktop', 'Core'
GUID = '54948ec2-33c5-4009-88b0-9446fa2516e5'
Author = 'Dr. Tobias Weltner'
CompanyName = 'powershell.one'
Copyright = '2020 - MIT License'
Description = 'commands taken from articles published at https://powershell.one'
# PowerShellVersion = ''
# PowerShellHostName = ''
# PowerShellHostVersion = ''
# DotNetFrameworkVersion = ''
# CLRVersion = ''
# ProcessorArchitecture = ''
# RequiredModules = @()
# RequiredAssemblies = @()
# ScriptsToProcess = @()
# TypesToProcess = @()
# FormatsToProcess = @()
# NestedModules = @()
FunctionsToExport = @('Assert-PsOneFolderExists','Start-PSOneClipboardListener','Stop-PSOneClipboardListener','Get-PSOneClipboardListenerStatus','Show-PSOneApplicationWindow','Find-PSOneDuplicateFile','Test-PSOnePort','Test-PSOnePing','Invoke-PSOneForeach','Invoke-PSOneWhere','Test-PSOneScript','Get-PSOneToken','Expand-PSOneToken','Get-PSOneDirectory','Invoke-PSOneGroup','Find-PSOneDuplicateFileFast','Get-PsOneFileHash')
#CmdletsToExport = '*'
#VariablesToExport = '*'
#AliasesToExport = '*'
# DscResourcesToExport = @()
# ModuleList = @()
# FileList = @()
PrivateData = @{
    PSData = @{
        # Tags = @()
        LicenseUri = 'https://en.wikipedia.org/wiki/MIT_License'
        ProjectUri = 'https://github.com/TobiasPSP/Modules.PSOneTools/tree/master/PSOneTools'
        # IconUri = ''
        ReleaseNotes = 'Added Assert-PsOneFolderExists'
    } 
} 
# HelpInfo-URI dieses Moduls
# HelpInfoURI = ''
# DefaultCommandPrefix = ''
}

