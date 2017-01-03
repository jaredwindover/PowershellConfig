Set-Location C:\Users\Redirection\windoj9
Set-Variable HOME -force C:\Users\Redirection\windoj9
(get-psprovider 'FileSystem').Home = $HOME

Import-Module posh-git
Import-Module PSReadLine

Set-Alias la ls -Option AllScope
Set-Alias cd pushd -Option AllScope
Set-Alias bd popd -Option AllScope
Set-Alias e emacsclient
Set-Alias sa Start-SshAgent

Remove-Item alias:r

$saveStates = @{}

#PSReadline Configuration
Set-PSReadlineOption -EditMode Emacs
Set-PSReadlineKeyHandler -Key Ctrl+P,UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key Ctrl+N,DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

function en
{
		emacsclient -n $args
}

function tsk-GetPath
{
  $t = $args[0];
	$path = "$env:Home/.time/$t.tm";
	New-Item -ItemType Directory -Force -Path "$env:Home/.time/" | Out-Null;
  return $path;
}

function tsk
{
	$path = tsk-GetPath $args[0]
	if (Test-Path $path) {
		$to = Import-cliXML $path
		$ti = $to.Time;
		$tls = $to.LastStart;
		$td = (Get-Date) - $tls;
		return $ti + $td;
	} else {
	  throw "No Task"
	}
}

function tskb
{
	$path = tsk-GetPath $args[0]
  if (Test-Path $path) {
	  $to = Import-cliXML $path;
	  if ($to.LastStart -eq $null) {
			$tn = $to | Add-Member -Force LastStart (Get-Date) -passthru;
		  Export-cliXML -InputObject $tn -Path $path
		} else {
		  throw "Already Started";
		}
	} else {
	  Export-cliXML -InputObject (New-Object -Type PsObject | Add-Member LastStart (Get-Date) -passthru | Add-Member Time (New-TimeSpan) -passthru) -Path $path
	}
}

function tske
{
	$path = tsk-GetPath $args[0]
  if (Test-Path $path) {
	  $to = Import-cliXML $path;
	  if ($to.LastStart -ne $null) {
			$td = (Get-Date) - $to.LastStart;
			$tn = $to.Time;
			$tf = $tn + $td;
			Export-cliXML -InputObject (New-Object -Type PsObject | Add-Member LastStart $null -passthru | Add-Member Time $tf -passthru) -Path $path
		} else {
		  throw "Not Started";
		}
	} else {
		  throw "No Task";
	}
}

function Find-Duplicates
{
		Get-ChildItem -recurse $args |
		Get-FileHash |
		Group-Object -Property Hash |
		Where-Object {$_.Count -gt 1} |
		Select-Object -ExpandProperty Group |
		Format-Table -groupby Hash -property Path
}

function r
{
	repo --no-pager $args
}

function rgo
{
	if ($args.count -eq 0)
	{
	  cl (python -c 'from imp import load_source; print(load_source(""repo"",""C:\\repo\\repo"")._FindRepo()[1] + ""\\.."")')
	}
  else
	{
		cl (r info $args[0] | sls "Mount path*" | %{$_ -replace "Mount path: ",""})
	}
}

function cl
{
	cd $args[0]
	ls
}

function bl
{
	bd
	ls
}

function ul
{
	cl ..
}

function ex
{
	$args[0] | fl
}

function rs
{
	$bufferSize = $host.UI.RawUI.BufferSize
	if ($args.count -eq 0)
	{
		$windowSize = $host.UI.RawUI.WindowSize
		$width = $windowSize.Width
	}
	else
	{
		$width = $args[0]
	}
	$bufferSize.Width = $width
	$host.UI.RawUI.BufferSize = $bufferSize
}

function ap
{
	if ($args.count -gt 0) {
		$newEntry = $args[0]
		$oldPath = $env:OldPath
		$path = $env:Path
		$newPath = $env:Path + ";" + $newEntry
		[Environment]::SetEnvironmentVariable(
				"Path",
				$newPath,
				[System.EnvironmentVariableTarget]::Machine
		)
		if ($?) {
			[Environment]::SetEnvironmentVariable(
				"OldPath",
				$path,
				[System.EnvironmentVariableTarget]::Machine
			)
		}
	}
}

function save
{
	$command = [String]::Join(" ", $args);
	$value = $(Invoke-Expression $command);
	if ($saveStates.ContainsKey($command)) {
	  $saveStates.Set_Item($command, $value);
	} else {
		$saveStates.Add($command, $value);
	}
}

function load
{
	$command = [String]::Join(" ", $args);
  $saveStates.Get_Item($command);
}

function gitfix
{
	(git log -1 --pretty=%B) -replace "Change-Id:.*","" | git commit --amend --file -
}

function prompt
{
	$realLASTEXITCODE = $LASTEXITCODE
	$t = Get-Date -Format "HH:mm:(ss)"
	#$p = Split-Path -leaf -path (Get-Location)
	$p = $(uniquePWD $(pwd))
	Write-Host "$t" -NoNewline -ForegroundColor Red
	Write-Host " - " -NoNewline -ForegroundColor White
	Write-Host "$p" -NoNewline -ForegroundColor Yellow
	Write-VcsStatus
	Write-Host ">" -NoNewline -ForegroundColor Yellow
	$global:LASTEXITCODE = $realLASTEXITCODE
	return " "
}

function xunit
{
		if ($args.count -gt 0) {
				$dir = $args[0]
		}
		else
		{
				$dir = $(pwd)
		}
		python C:\Code\deployment\scripts\run_xunit_tests.py --xunit_path C:\Code\externals\xunit2\ --path_to_scan $dir --output $(gci env:temp)
}

function workon {
		$h = ${env:VIRTUALENV-HOME}
		if ($args.count -gt 0) {
				$ve = $args[0]
				$path = "$h/$ve/Scripts/activate.ps1"
				& $path
		}
}

if (Test-Path Function:\TabExpansion) {
    Rename-Item Function:\TabExpansion TabExpansionCustomBackup
}

function TabExpansion($line, $lastWord) {
    $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()

    switch -regex ($lastBlock) {
        # Execute git tab completion for all git-related commands
        "^$(Get-AliasPattern workon) (.*)" {
						Get-ChildItem -Path ${env:VIRTUALENV-HOME} -Filter $lastWord* |
							Select-Object -ExpandProperty BaseName
				}

        # Fall back on existing tab expansion
        default {
						if (Test-Path Function:\TabExpansionCustomBackup) {
								TabExpansionBackup $line $lastWord
						}
				}
    }
}


Start-SshAgent -Quiet
