<#
copy light: Tatsuya.Nakajima
file encoding: UTF8 with BOM
#>

<#
.SYNOPSIS
    データ移行で使用する。ROBOCOPYへバックアップ対処のパスを渡す
.DESCRIPTION
    ファイル総数、ファイル総サイズを算出する
.PARAMETER Path
    調査対象のパス
.PARAMETER Scale
    容量の単位（KB,MB,GB）
.EXAMPLE
        Get-FileCountAndSize -SourcePath $path -Scale MB -backupfoldername $backupfolderpath
.INPUTS
    String
    validateSet
    string
.OUTPUTS
    PSObject
.NOTES
    Author:  Tatsuya Nakajima
#>
function Get-FileCountAndSize {
    [CmdletBinding()]
    param (
        [parameter(Position = 0, mandatory = 1)]
        [string[]]$SourcePath,
        [parameter(Position = 1, mandatory = 0)]
        [validateSet("KB", "MB", "GB")]
        [string]$Scale = "KB",
        [parameter(Position = 2, Mandatory = 0)]
        [string]$backupfoldername = ""
    )

    process {
        [decimal] $totalFileCount = 0
        [decimal] $totalFileSize = 0
        [decimal] $totalSize = 0
        $ret_array = @()
        $SourcePath `
        | ForEach-Object{
            if (Test-Path $_) {
                $FileInfoObj = @{}
                $FileInfoObj = New-Object PSObject | Select-Object SourcePath,DestinationPath,TotalFolderCount,TotalFileCount,TotalSize
                $FileInfoObj.SourcePath = $_
                $FileInfoObj.DestinationPath = if ([System.String]::IsNullOrEmpty($backupfoldername)) {$_} else {$_ -replace '^[A-Z]:', $backupfoldername} 
                Get-ChildItem -Path $_ -File -Recurse -ErrorAction "silentlycontinue" -Force | ForEach-Object {
                    $totalFileSize += $_.Length
                    $totalFileCount++
                }
                $FileInfoObj.TotalFileCount = $totalFileCount
                $totalSize = [decimal]("{0:N2}" -f ($totalFileSize / "1{0}" -f $scale))
                $FileInfoObj.TotalSize = "{0}{1}" -f $totalSize, $scale
                $FileInfoObj.TotalFolderCount = (Get-ChildItem -Path $_ -Directory -Recurse -ErrorAction "silentlycontinue" -Force | Measure-Object).Count
                $ret_array += $FileInfoObj
            }
        }
        return $ret_array
    }
}


<#
.SYNOPSIS
    本Powershellスクリプトのログを出力する
.DESCRIPTION
    与えられた文字列をアプリケーションログとして出力する
.PARAMETER LogString
    出力するログ文字列
.EXAMPLE
    $ret = Log -LogPath .\ -LogName "foo" -LogString "hogehoge"
.INPUTS
    String
    String
    String
.OUTPUTS
    String
.NOTES
    Author:  Tatsuya Nakajima
#>
function Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = 1)][string]$LogPath,
        [Parameter(Mandatory = 1)][string]$LogName,
        [Parameter(Mandatory = 1)][string]$LogString
    )
    
    process {
        $Now = Get-Date
        # Log 出力文字列に時刻を付加(YYYY/MM/DD HH:MM:SS.MMM $LogString)
        $Log = $Now.ToString("yyyy/MM/dd HH:mm:ss.fff") + " "
        $Log += $LogString
        $LogFile = "{0}_{1}.log" -f $LogName, $Now.ToString("yyyy-MM-dd")
        if (-not (Test-Path($LogPath))) {
            New-Item -Path $LogPath -ItemType Directory > $null
        }
        $LogFileName = Join-Path $LogPath $LogFile
        Write-Output $Log | Out-File -FilePath $LogFileName -Encoding Default -append
        # echo back
        Return $Log
    }
}


<#
.SYNOPSIS
    ファイルを削除する。
.DESCRIPTION
    StartDate 以前のファイルをすべて削除する。
.PARAMETER PurgePath
    削除対象のディレクトリパス
.PARAMETER PastDays
    現在の日付から指定された数を引いた年月日より古いファイルを消す。この値は0以上である必要がある。
.EXAMPLE
    $ret = PurgeFiles -PurgePath .\ -PastDays 30
.INPUTS
    String
    Integer
.OUTPUTS
    String
.NOTES
    Author:  Tatsuya Nakajima
#>
function PurgeFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = 1)][string]$PurgePath,
        [Parameter(Mandatory = 1)][int]$PastDays
    )
    
    process {
        $ReturnMsg = "Log purge successful."
        if ($PastDays -lt 0) {
            return "Second argument must be greater than 0."
        }
        try {
            Get-ChildItem -Path $PurgePath -Recurse | `
                Select-Object Mode, CreationTime, LastWriteTime, LastAccessTime, Size, Name, FullName | `
                Where-Object{ $_.LastWriteTime -le (Get-Date).AddDays($PastDays * -1) } | `
                ForEach-Object { Remove-Item $_.FullName }
        }
        catch {
            $ReturnMsg = "Log purge failed."
            throw $_.Exception
        }
        return $ReturnMsg
    }
}


<#
.SYNOPSIS
    それぞれのスクリプトに配置、必要ならインライン展開する方がいい。
    ライブラリファイルのディレクトリを返してしまうので、本来の実行されるスクリプトのパスを返すには、実行されるスクリプトにインライン展開するか
    この関数を実行されるスクリプトに組込む。
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
<# 各MAINスクリプトでディレクトリをとらないとうまくいかないので廃止
function Get-CurrentDirectoryPath {
    # PS v3
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $retval = $PSScriptRoot
    }
    # PS v2
    else {
        $retval = Split-Path $MyInvocation.MyCommand.Path -Parent
    }
    return (Split-Path $retval -Parent)
}
#>


<#
.SYNOPSIS
    新しいパソコンへデータ移行するために、Robocopy ユーティリティを起動し、バックアップを実施する
.DESCRIPTION
    Robocopy ユーティリティを起動し、バックアップを実施する
.PARAMETER src
    コピー元パス
.PARAMETER dst
    コピー先パス
.PARAMETER logfile
    Robocopy が出力するログファイルのパス
.EXAMPLE
    $resultObj = ExecRobocopy -src $item.SourcePath -dst $item.DestinationPath -logfile $robocopylogfile
.INPUTS
    String
    String
    String
.OUTPUTS
    PSObject
.NOTES
    Author:  Tatsuya Nakajima

    戻り値 0: コピーする必要がないため、何も実施しなかった
    戻り値 1: ファイルのコピーが成功した (フォルダーのコピーは含まれません)
    戻り値 2: 余分なフォルダー、ファイルが確認された (コピー元にはなく、コピー先だけにある) 
    戻り値 4: 同じ名前で別の種類のファイルが存在した (コピー元はフォルダーで、コピー先はファイル、またはその逆)
    戻り値 8: コピーに失敗した (リトライした結果を含みます、また /L では実際にコピー処理を行わないため、実質 8 以上の戻り値は出力されません)
    このそれぞれの戻り値は LOG オプションでカウントされる場所は以下となります。
    0 と判定されたファイル、フォルダーはログ中の "スキップ" にカウントされます。
    1 と判定されたファイル、フォルダーはログ中の "コピー済み" にカウントされます。
    2 と判定されたファイル、フォルダーはログ中の "Extras" にカウントされます。
    4 と判定されたファイル、フォルダーはログ中の "不一致" にカウントされます。
    8 と判定されたファイル、フォルダーはログ中の "失敗" にカウントされます。
    しかし、robocopy の Log ファイルをご覧いただいた事のある方であれば、戻り値が 9 以上となっている結果をご覧いただいたことがあるかもしれません。
    これは、複数のファイル、フォルダーをコピーされる場合に別々の結果となった場合に、足し算された値が返されるためです。
    例えば、戻り値が [1] の場合には、robocopy によって処理されたファイルが、すべて正常に "コピー済み" と判断された場合です。
    戻り値が [3] の場合、robocopy によって処理されたファイルの中に、戻り値 1 である "コピー済み" と戻り値 2 である "Extras" と判断されたファイルが混在する場合に記録されます。
    つまり、戻り値が [1] 以外となっている場合には、正常にコピーが完了しなかったファイルが存在していることを表します。
    以下に、[1] 以外のそれぞれの戻り値の結果をご紹介いたしますので、ご参考願います。
    戻り値 3: 一部のファイルのコピーに成功したが、一部、Extras と判定された。(1 + 2)
    戻り値 5: 一部のファイルのコピーに成功したが、一部、不一致 と判定された。(1 + 4)
    戻り値 6: ファイルのコピーに成功しておらず、Extras または 不一致 と判定された (2 + 4)
    戻り値 7: 一部のファイルのコピーに成功したが、一部 Extras または 不一致 と判定された (1 + 2 + 4)
    戻り値 9: 一部のファイルのコピーに成功したが、一部 失敗 と判定された (1 + 8)
    戻り値 10: ファイルのコピーに成功しておらず、Extras または 失敗 と判定された (2 + 8)
    戻り値 11: 一部のファイルのコピーに成功したが、一部 Extras または 失敗 と判定された (1 + 2 + 8)
    戻り値 12: ファイルのコピーに成功しておらず、不一致 または 失敗 と判定された (4 + 8)
    戻り値 13: 一部のファイルのコピーに成功したが、一部 不一致 または 失敗 と判定された (1 + 4 + 8)
    戻り値 14: ファイルのコピーに成功しておらず、Extras、不一致 または 失敗 と判定された (2 + 4 + 8)
    戻り値 15: 一部のファイルのコピーに成功したが、一部 Extras、不一致 または 失敗 と判定された (1 + 2 + 4 + 8)
    戻り値 16: ヘルプを表示したときにセットされます。また、存在しないフォルダーなどを指定するなど、引数が不正な場合にも記録されます。
#>
function ExecRobocopy {
    [CmdletBinding()]
    param (
        [parameter(position = 0, mandatory = 1)]
        [string]$src,
        [parameter(position = 1, mandatory = 1)]
        [string]$dst,
        [parameter(position = 2, mandatory = 1)]
        [string]$logfile
    )

    process {
        $retobj = @{}
        $retobj = New-Object PSObject | Select-Object code,msg
        $commandString = 'robocopy "{0}" "{1}" /E /NP /R:0 /ETA /LOG+:"{2}"' -f $src, $dst, $logfile
        Write-Verbose $commandString
        $retval = cmd /c $commandString
        if ($retval) {
            if ($retval -eq 1) {
                $retobj.code = 1
                $retobj.msg = "ファイルのコピーが成功した。"
            }
            elseif ($retval -eq 2) {
                $retobj.code = $retval
                $retobj.msg = "余分なフォルダー、ファイルが確認された。"
            }
            elseif ($retval -eq 3) {
                $retobj.code = $retval
                $retobj.msg = "一部のファイルのコピーに成功したが、一部、Extras と判定された。"
            }
            elseif ($retval -eq 4) {
                $retobj.code = $retval
                $retobj.msg = "同じ名前で別の種類のファイルが存在した。"
            }
            elseif ($retval -eq 5) {
                $retobj.code = $retval
                $retobj.msg = "一部のファイルのコピーに成功したが、一部、不一致 と判定された。"
            }
            elseif ($retval -eq 6) {
                $retobj.code = $retval
                $retobj.msg = "ファイルのコピーに成功しておらず、Extras または 不一致 と判定された。"
            }
            elseif ($retval -eq 7) {
                $retobj.code = $retval
                $retobj.msg = "一部のファイルのコピーに成功したが、一部 Extras または 不一致 と判定された。"
            }
            elseif ($retval -eq 8) {
                $retobj.code = $retval
                $retobj.msg = "コピーに失敗した。"
            }
            elseif ($retval -eq 9) {
                $retobj.code = $retval
                $retobj.msg = "一部のファイルのコピーに成功したが、一部 失敗 と判定された。"
            }
            elseif ($retval -eq 10) {
                $retobj.code = $retval
                $retobj.msg = "ファイルのコピーに成功しておらず、Extras または 失敗 と判定された。"
            }
            elseif ($retval -eq 11) {
                $retobj.code = $retval
                $retobj.msg = "一部のファイルのコピーに成功したが、一部 Extras または 失敗 と判定された。"
            }
            elseif ($retval -eq 12) {
                $retobj.code = $retval
                $retobj.msg = "ファイルのコピーに成功しておらず、不一致 または 失敗 と判定された。"
            }
            elseif ($retval -eq 13) {
                $retobj.code = $retval
                $retobj.msg = "一部のファイルのコピーに成功したが、一部 不一致 または 失敗 と判定された。"
            }
            elseif ($retval -eq 14) {
                $retobj.code = $retval
                $retobj.msg = "ファイルのコピーに成功しておらず、Extras、不一致 または 失敗 と判定された。"
            }
            elseif ($retval -eq 15) {
                $retobj.code = $retval
                $retobj.msg = "一部のファイルのコピーに成功したが、一部 Extras、不一致 または 失敗 と判定された。"
            }
            elseif ($retval -eq 16) {
                $retobj.code = $retval
                $retobj.msg = "不正な引数を指定した。"
            }
            else {
                $retobj.code = 0
                $retobj.msg = "何も実施しなかった。"
            }
        }
        return $retobj
    }
}


<#
.SYNOPSIS
    出力ファイル名に使用するホスト名を取得する
.DESCRIPTION
    IPv4からホスト名を取得する
.PARAMETER ipv4
    IPv4アドレス文字列
.EXAMPLE
     Get-BackupFolderName -ipv4 127.0.0.1
     Get-BackupFolderName -ipv4 localhost
.INPUTS
    String
.OUTPUTS
    string
.NOTES
    Author:  Tatsuya Nakajima
#>
function Get-BackupFolderName {
    [cmdletbinding()]
    param
    (
        [parameter(position = 0, Mandatory = 1)]
        [string]$ipv4
    )

    begin {
        [string]$hostname = ""
    }

    process {
        try {
            Write-Verbose 'get HOSTNAME ...'
            [System.Net.IPHostEntry]$he = [System.Net.Dns]::GetHostEntry($ipv4)
            $hostname = $he.HostName
        }
        catch {
            $hostname = 'unknownhost'
            Write-Output $_.Exception.Message
            throw $_.Exception
        }
        return $hostname
    }
}


<#
.SYNOPSIS
    パスワードファイルを読み取り、文字列を返す
.DESCRIPTION
    RPCを実行するための資格情報を作成する
    パスワードファイルを読み取り、暗号化されたパスワード文字列を返却する。
.PARAMETER path
    パス
.EXAMPLE
     Get-SecureStringFromPasswordFile -path "C:\temp"
.INPUTS
    String
.OUTPUTS
    securestring
.NOTES
    Author:  Tatsuya Nakajima
#>
function Get-SecureStringFromPasswordFile {
    [cmdletbinding()]
    param
    (
        [parameter(position = 0, Mandatory = 1)]
        [string]$path
    )

    begin {
        [string]$retsecure = ""
    }

    process {
        try {
            $retsecure = Get-Content $path
        }
        catch {
            Write-Output $_.Exception.Message
            throw $_.Exception
        }
        return $retsecure | ConvertTo-SecureString
    }
}


<#
.SYNOPSIS
    JSON形式設定ファイルの読み込み
.DESCRIPTION
    JSON形式の設定ファイルを読み込みJSONオブジェクトを返却
.PARAMETER path
    パス
.EXAMPLE
    Read-JsonSettingFile ".\\conf\\conf.json"
.INPUTS
    String
.OUTPUTS
    JSON Object
.NOTES
    Author:  Tatsuya Nakajima
#>
function Read-JsonSettingFile {
    [CmdletBinding()]
    param (
        [parameter(position = 0, Mandatory = 1)]
        [string]$path
    )

    begin {
        $returnObject = {}
    }

    process {
        try {
            $returnObject = ((Get-Content $path -Encoding UTF8) | ConvertFrom-Json)
        }
        catch {
            Write-Output $_.Exception.Message
            throw $_.Exception
        }
        return $returnObject

    }
}


Export-ModuleMember -Function *
