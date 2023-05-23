<#
2023/5/22

THIS FILE ENCODING IS: UTF8 with BOM
AUTHOR: tatsuya.nakajima
NOTE: Use the cli-kintone utility to import CSV file data and attachments.

冪等性を担保した実装に
#>
[cmdletbinding()]
param (
    [string]$application = ""
)

# 関数のエラーはキャッチできるようにする。
$ErrorActionPreference = "Stop"

# バッチファイルの設定が記述されているファイルパス
Set-Variable jsonConfigFile -Option Constant -Value ".\\conf\\conf.json"


<#
.SYNOPSIS
    それぞれのスクリプトに配置、必要ならインライン展開する方がいい。
    スクリプト実行フォルダ
.DESCRIPTION
    スクリプト実行フォルダ
.EXAMPLE
        Get-CurrentDirectoryPath
.INPUTS
    void
.OUTPUTS
    string
.NOTES
    Author:  Tatsuya Nakajima
#>
function Get-CurrentDirectoryPath {
    # PS v3
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $retval = $PSScriptRoot
    }
    # PS v2
    else {
        $retval = Split-Path $MyInvocation.MyCommand.Path -Parent
    }
    return $retval
}

function Invoke-Clikintone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$logpath,
        [Parameter(Mandatory=$true)][string]$logname,
        [Parameter(Mandatory=$true)][string]$baseUrl,
        [Parameter(Mandatory=$true)][string]$appToken,
        [Parameter(Mandatory=$true)][string]$appId,
        [Parameter(Mandatory=$true)][string]$csvFilePath,
        [Parameter(Mandatory=$false)][ValidateSet("utf8", "sjis")]$charEncoding,
        [Parameter(Mandatory=$false)][string]$updateKey = "",
        [Parameter(Mandatory=$false)][string]$attachments = ""
    )

    begin {
        [string]$stdOut = ""
    }

    process {
        if (($updateKey -eq "") -and ($attachments -eq "")) {
            Log -LogPath $logpath -LogName $logname -LogString "not upsert and not attachments"
            .\cli-kintone.exe record import `
                --base-url $baseUrl `
                --api-token $appToken `
                --app $appId `
                --file-path $csvFilePath `
                --encoding $charEncoding
        }
        elseif (($updateKey -ne "") -and ($attachments -eq "")) {
            Log -LogPath $logpath -LogName $logname -LogString "upsert and not attachments"
            .\cli-kintone.exe record import `
                --base-url $baseUrl `
                --api-token $appToken `
                --app $appId `
                --file-path $csvFilePath `
                --encoding $charEncoding `
                --update-key $updateKey
        }
        elseif (($updateKey -eq "") -and ($attachments -ne "")) {
            Log -LogPath $logpath -LogName $logname -LogString "not upsert and attachments"
            .\cli-kintone.exe record import `
                --base-url $baseUrl `
                --api-token $appToken `
                --app $appId `
                --file-path $csvFilePath `
                --encoding $charEncoding `
                --attachments-dir $attachments
        }
        else {
            Log -LogPath $logpath -LogName $logname -LogString "upsert and attachments"
            .\cli-kintone.exe record import `
                --base-url $baseUrl `
                --api-token $appToken `
                --app $appId `
                --file-path $csvFilePath `
                --encoding $charEncoding `
                --update-key $updateKey `
                --attachments-dir $attachments
        }
    }
}


# 実行時ディレクトリを設定
Set-Location -Path (Get-CurrentDirectoryPath)

# ライブラリのインポート
Import-Module -Name .\library\AppCommon.psm1 -Force

$setting = (Read-JsonSettingFile -path $jsonConfigFile)

# 不要ログ削除
$retString = PurgeFiles -PurgePath $setting.batsettings.logfilepath -PastDays $setting.batsettings.logSaveDays
Log -LogPath $setting.batsettings.logfilepath -LogName $setting.batsettings.logfilename -LogString ("不要ログ削除：{0}" -f $retString)

# 処理開始
Log -LogPath $setting.batsettings.logfilepath `
    -LogName $setting.batsettings.logfilename `
    -LogString "cli-Kintoneを使用してCSVデータのインポートを開始します。"

foreach ($item in $setting.apps) {
    if ("" -eq $application) {
        Log -LogPath $setting.batsettings.logfilepath `
            -LogName $setting.batsettings.logfilename `
            -LogString ("アプリケーション:{0}に、CSVをインポートします。" -f $item.appname)
        
        $timeSpan = Measure-Command {
            Invoke-Clikintone `
                -logpath $setting.batsettings.logfilepath `
                -logname $setting.batsettings.logfilename `
                -baseUrl $setting.baseurl `
                -appToken $item.apptoken `
                -appId $item.appid `
                -csvFilePath $item.targetcsv `
                -charEncoding $item.csvencoding `
                -updateKey $item.updatekey `
                -attachments $item.attachments
        }
        Log -LogPath $setting.batsettings.logfilepath `
            -LogName $setting.batsettings.logfilename `
            -LogString ("処理時間：{0}" -f $timeSpan.ToString("d'日'h'時間'm'分's'秒'fff"))
        Log -LogPath $setting.batsettings.logfilepath `
            -LogName $setting.batsettings.logfilename `
            -LogString ("アプリケーション:{0}へ、CSVをインポートしました。" -f $item.appname)
    } else {
        if ($application -eq $item.appname) {
            Log -LogPath $setting.batsettings.logfilepath `
                -LogName $setting.batsettings.logfilename `
                -LogString ("アプリケーション:{0}に、CSVをインポートします。" -f $item.appname)
        
            $timeSpan = Measure-Command {
                Invoke-Clikintone `
                    -logpath $setting.batsettings.logfilepath `
                    -logname $setting.batsettings.logfilename `
                    -baseUrl $setting.baseurl `
                    -appToken $item.apptoken `
                    -appId $item.appid `
                    -csvFilePath $item.targetcsv `
                    -charEncoding $item.csvencoding `
                    -updateKey $item.updatekey `
                    -attachments $item.attachments
            }
            
            Log -LogPath $setting.batsettings.logfilepath `
                -LogName $setting.batsettings.logfilename `
                -LogString ("処理時間：{0}" -f $timeSpan.ToString("d'日'h'時間'm'分's'秒'fff"))
            Log -LogPath $setting.batsettings.logfilepath `
                -LogName $setting.batsettings.logfilename `
                -LogString ("アプリケーション:{0}へ、CSVをインポートしました。" -f $item.appname)
        }
    }
}

# 処理終了
Log -LogPath $setting.batsettings.logfilepath `
    -LogName $setting.batsettings.logfilename `
    -LogString "cli-Kintoneを使用してCSVデータのインポートが完了しました。"
