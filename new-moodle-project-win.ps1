# Prompt for project name
$project = Read-Host "Enter project name (no spaces)"
$safeProject = $project.ToLower() -replace ' ', '-'

function Get-FreePortRange {
    do {
        $basePort = Get-Random -Minimum 8000 -Maximum 8997
        $inUse = @(0, 1, 2) | ForEach-Object {
            $port = $basePort + $_
            $test = Test-NetConnection -Port $port -ComputerName 127.0.0.1 -WarningAction SilentlyContinue
            $test.TcpTestSucceeded
        } | Where-Object { $_ -eq $true }
    } while ($inUse.Count -gt 0)

    return $basePort
}

$freeBasePort = Get-FreePortRange
$MoodlePort = $freeBasePort
$PhpMyAdminPort = $freeBasePort + 1
$MailhogPort = $freeBasePort + 2

# Ensure Projects folder exists
$projectsPath = "Projects"
if (-not (Test-Path $projectsPath)) {
    New-Item -ItemType Directory -Path $projectsPath | Out-Null
}

# Copy template folder to Projects\<safeProject>
$destinationPath = Join-Path -Path $projectsPath -ChildPath $safeProject
Copy-Item -Recurse -Force "TEMPLATES\MOODLE-DEV-TEMPLATE" $destinationPath

# Change directory to the new project
Set-Location $destinationPath

# Write .env file
@"
PROJECT_NAME=$SAFE_PROJECT
MOODLE_PORT=$MoodlePort
PHPMYADMIN_PORT=$PhpMyAdminPort
MAILHOG_PORT=$MailhogPort
MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=moodle
MYSQL_USER=moodle
MYSQL_PASSWORD=moodle
"@ | Out-File -Encoding utf8 -FilePath ".env"

# Write config.php inside ./moodle (literal $CFG kept by using single quotes)
$configPhp = @'
<?php  // Moodle configuration file

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'mariadb';
$CFG->dbname    = 'moodle';
$CFG->dbuser    = 'moodle';
$CFG->dbpass    = 'moodle';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => 3306,
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_general_ci',
);

$CFG->wwwroot   = 'http://localhost:{PORT}';
$CFG->dataroot  = '/var/www/moodledata';
$CFG->admin     = 'admin';

$CFG->directorypermissions = 0777;

$CFG->debug = (E_ALL | E_STRICT);
$CFG->debugdisplay = 1;

require_once(__DIR__ . '/lib/setup.php');
'@

# Replace {PORT} with actual MoodlePort
$configPhp = $configPhp -replace '{PORT}', $MoodlePort

# Write to file
$configPhp | Set-Content -Encoding UTF8 ".\moodle\config.php"



# Run Docker
docker-compose -p $safeProject up -d --build

# Output info
Write-Host "✅ Project '$project' created at $safeProject"
Write-Host "🌐 Moodle: http://localhost:$MoodlePort"
Write-Host "🛠️  phpMyAdmin: http://localhost:$PhpMyAdminPort"
