$src = "C:\Users\yakes\source\repos\NetSpeedLite"
$dst = "C:\Users\yakes\.gemini\antigravity\scratch\NetSpeedLite"

Copy-Item "$src\README.md" -Destination "$dst\README.md" -Force
Copy-Item "$src\CONTRIBUTING.md" -Destination "$dst\CONTRIBUTING.md" -Force
Copy-Item "$src\SECURITY.md" -Destination "$dst\SECURITY.md" -Force
if (!(Test-Path "$dst\.github\ISSUE_TEMPLATE")) { New-Item -Path "$dst\.github\ISSUE_TEMPLATE" -ItemType Directory -Force | Out-Null }
Copy-Item "$src\.github\ISSUE_TEMPLATE\*" -Destination "$dst\.github\ISSUE_TEMPLATE" -Force

$git = "C:\Program Files\Git\cmd\git.exe"
cd $src
& $git add .
& $git commit -m "seo: optimize README with targeted search keywords, FAQ rich snippets, and community health templates"
& $git push origin main
Write-Output "SEO commit pushed to GitHub!"
