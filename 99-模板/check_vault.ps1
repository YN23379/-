param(
    [string]$Root = "D:\笔记"
)

# 知识库体检脚本
# 用法：& "D:\笔记\99-模板\check_vault.ps1"
#
# 检查项：
#   1. wiki 链接与嵌入的附件是否指向真实存在的文件
#   2. 链接内是否有路径反斜杠（Obsidian 解析不了）
#   3. frontmatter 是否存在、必填字段是否齐全且取值合法
#   4. 是否有一级标题
#
# 说明：本库 Obsidian 设置为 newLinkFormat=absolute、attachmentFolderPath=90-附件，
#       因此 [[90-附件/xxx.png]]、[[20-领域/...]] 这类库内绝对路径是**正确**写法。
#       表格里的管道符写作反斜杠转义形式属于合法 Markdown，不算断链。

$ErrorActionPreference = "Stop"

# ---- 建立文件索引（含非 md 附件）----
$allFiles = Get-ChildItem $Root -Recurse -File |
    Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\\.obsidian\\' }

$byPath = @{}   # 库内相对路径（含扩展名）小写 -> 原路径
$byName = @{}   # 文件名（含扩展名）小写 -> 路径数组
foreach ($f in $allFiles) {
    $rel = $f.FullName.Replace("$Root\", "").Replace("\", "/")
    $byPath[$rel.ToLower()] = $rel
    $n = $f.Name.ToLower()
    if (-not $byName.ContainsKey($n)) { $byName[$n] = @() }
    $byName[$n] += $rel
}

$mdFiles = $allFiles | Where-Object { $_.Extension -eq '.md' }

# ---- 收集所有 md 的标题（用于校验 #锚点）----
$headings = @{}
foreach ($f in $mdFiles) {
    $rel = $f.FullName.Replace("$Root\", "").Replace("\", "/")
    $set = New-Object System.Collections.Generic.HashSet[string]
    foreach ($line in (Get-Content $f.FullName -Encoding UTF8)) {
        if ($line -match '^\s{0,3}(#{1,6})\s+(.+?)\s*$') {
            [void]$set.Add($Matches[2].Trim().ToLower())
        }
    }
    $headings[$rel.ToLower()] = $set
}

$broken    = @()
$badAnchor = @()
$backslash = @()
$noFm      = @()
$noTitle   = @()
$fmProblems = @()

$legalType     = @('项目档案','知识库','参考','索引','归档','学习方法','视频蒸馏')
$legalStatus   = @('待整理','已整理','待验证','进行中','已归档')
$legalEvidence = @('官方资料','源码确认','实机验证','教材课程','个人观点','推测','不适用','待标注')

foreach ($f in $mdFiles) {
    $rel = $f.FullName.Replace("$Root\", "").Replace("\", "/")
    $txt = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($null -eq $txt) { $txt = "" }

    # ---- frontmatter ----
    if (-not $txt.StartsWith("---")) {
        $noFm += $rel
    }
    else {
        $end = $txt.IndexOf("`n---", 3)
        $fmLines = if ($end -gt 0) { ($txt.Substring(3, $end - 3)) -split "`n" } else { @() }
        $fm = @{}
        foreach ($l in $fmLines) {
            if ($l -match '^([A-Za-z_]+):\s*(.*)$') { $fm[$Matches[1]] = $Matches[2].Trim() }
        }
        foreach ($req in @('type','scope','doc_type','status','evidence','updated')) {
            if (-not $fm.ContainsKey($req)) {
                $fmProblems += "$rel  缺字段 $req"
            }
        }
        if ($fm.ContainsKey('type')     -and $legalType     -notcontains $fm['type'])     { $fmProblems += "$rel  type 取值非法: $($fm['type'])" }
        if ($fm.ContainsKey('status')   -and $legalStatus   -notcontains $fm['status'])   { $fmProblems += "$rel  status 取值非法: $($fm['status'])" }
        if ($fm.ContainsKey('evidence') -and $legalEvidence -notcontains $fm['evidence']) { $fmProblems += "$rel  evidence 取值非法: $($fm['evidence'])" }
    }

    # ---- 一级标题 ----
    if ($txt -notmatch '(?m)^#\s') { $noTitle += $rel }

    # ---- 链接 ----
    # 剔除"包含 [[ 的行内代码/代码块"：那些是语法示例或 shell 的 [[ 判断，不是真链接。
    # 注意：不能无差别删除所有行内代码，否则会破坏锚点里合法的反引号（如 `#`<stdarg.h>`可变参数`）。
    $scan = [regex]::Replace($txt, '(?s)```.*?```', '')
    $scan = [regex]::Replace($scan, '`[^`\r\n]*\[\[[^`\r\n]*`', '')

    foreach ($m in [regex]::Matches($scan, '(!?)\[\[([^\]]+?)\]\]')) {
        $inner = $m.Groups[2].Value

        if ($inner -match '\\' -and $inner -notmatch '\\\|') {
            $backslash += "$rel  ::  $inner"
        }

        # 去掉别名、锚点、块引用
        $t = ($inner -split '\\?\|')[0]
        $anchor = $null
        if ($t -match '^(.*?)#(.*)$') { $t = $Matches[1]; $anchor = $Matches[2] }
        if ($t -match '^(.*?)\^(.*)$') { $t = $Matches[1] }
        $t = $t.Trim().Replace([char]92, [char]47)
        if ($t -eq '') { continue }

        $key = $t.ToLower()
        $ok = $byPath.ContainsKey($key)
        if (-not $ok) { $ok = $byPath.ContainsKey("$key.md") }
        if (-not $ok) {
            $base = ($t -split '/')[-1].ToLower()
            if ($byName.ContainsKey($base)) { $ok = $true }
            elseif ($byName.ContainsKey("$base.md")) { $ok = $true }
        }
        if (-not $ok) {
            $broken += "$rel  ->  $t"
            continue
        }

        # 锚点校验（只对 md 且锚点不是块引用）
        if ($anchor -and $anchor -notmatch '^\^') {
            $targetRel = $byPath[$key]
            if (-not $targetRel) { $targetRel = $byPath["$key.md"] }
            if (-not $targetRel) {
                $base = ($t -split '/')[-1].ToLower()
                if ($byName.ContainsKey("$base.md")) { $targetRel = $byName["$base.md"][0] }
            }
            if ($targetRel -and $targetRel.ToLower().EndsWith('.md')) {
                # Obsidian 比较锚点时忽略标点与空白、忽略大小写；这里做同样归一化
                $hset = $headings[$targetRel.ToLower()]
                if ($hset) {
                    $norm = [regex]::Replace($anchor.Trim().ToLower(), '[\s\p{P}\p{S}]', '')
                    $found = $false
                    foreach ($h in $hset) {
                        if ([regex]::Replace($h.ToLower(), '[\s\p{P}\p{S}]', '') -eq $norm) { $found = $true; break }
                    }
                    if (-not $found) { $badAnchor += "$rel  ->  $t#$anchor" }
                }
            }
        }
    }
}

Write-Output "================ 知识库体检 ================"
Write-Output ("扫描文件(md)        : " + $mdFiles.Count)
Write-Output ("断链                : " + $broken.Count)
Write-Output ("锚点失效            : " + $badAnchor.Count)
Write-Output ("链接内反斜杠        : " + $backslash.Count)
Write-Output ("缺 frontmatter      : " + $noFm.Count)
Write-Output ("frontmatter 字段问题: " + $fmProblems.Count)
Write-Output ("缺一级标题          : " + $noTitle.Count)
Write-Output ""

function Show($title, $items, $limit) {
    if ($items.Count -eq 0) { return }
    Write-Output "--- $title ---"
    $items | Sort-Object -Unique | Select-Object -First $limit | ForEach-Object { Write-Output ("  " + $_) }
    if ($items.Count -gt $limit) { Write-Output ("  ... 另有 " + ($items.Count - $limit) + " 条") }
    Write-Output ""
}

Show "断链" $broken 60
Show "锚点失效" $badAnchor 40
Show "链接内反斜杠" $backslash 20
Show "缺 frontmatter" $noFm 20
Show "frontmatter 字段问题" $fmProblems 40
Show "缺一级标题" $noTitle 50

if ($broken.Count -gt 0 -or $backslash.Count -gt 0) { exit 1 } else { exit 0 }
