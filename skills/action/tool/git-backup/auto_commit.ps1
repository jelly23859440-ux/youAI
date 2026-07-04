# 自动备份 - 被动检测模式
# 文件变化时自动提交，保留最近50个版本

$repoPath = "D:\YUANYINo1\meta-infant"
$backupPath = "D:\GIT\meta-infant-backup"
$maxCommits = 50

Write-Host "自动备份已启动（被动检测模式）" -ForegroundColor Green
Write-Host "文件变化时自动提交，保留最近 $maxCommits 个版本" -ForegroundColor Yellow
Write-Host "按 Ctrl+C 停止" -ForegroundColor Yellow

# 创建文件监控器
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $repoPath
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# 监听文件变化
$action = {
    $time = Get-Date -Format "HH:mm:ss"
    Write-Host "[$time] 检测到文件变化: $($Event.SourceEventArgs.FullPath)" -ForegroundColor Cyan
    
    # 等待2秒让其他变化完成
    Start-Sleep -Seconds 2
    
    Set-Location $repoPath
    
    # 检查是否有修改
    $status = git status --short
    if ($status) {
        git add -A
        git commit -m "自动备份 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null
        
        # 同步到备份目录
        if (Test-Path $backupPath) {
            Remove-Item "$backupPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -Path "$repoPath\*" -Destination $backupPath -Recurse -Force -Exclude ".git"
        
        Write-Host "[$time] 已提交并备份" -ForegroundColor Green
        
        # 清理旧版本，保留最近N个
        $commits = git log --oneline | Measure-Object -Line
        if ($commits.Lines -gt $maxCommits) {
            $toDelete = $commits.Lines - $maxCommits
            git rebase --root --onto (git rev-list --max-parents=0 HEAD)~$toDelete HEAD 2>$null
            Write-Host "[$time] 已清理旧版本，保留 $maxCommits 个" -ForegroundColor Yellow
        }
    }
}

Register-ObjectEvent $watcher "Changed" -Action $action
Register-ObjectEvent $watcher "Created" -Action $action
Register-ObjectEvent $watcher "Deleted" -Action $action
Register-ObjectEvent $watcher "Renamed" -Action $action

Write-Host "监控已启动，等待文件变化..." -ForegroundColor Green

# 保持脚本运行
try {
    while ($true) { Start-Sleep -Seconds 1 }
} finally {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
}
