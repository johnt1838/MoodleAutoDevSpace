# Prompt for project name
$project = Read-Host "Enter project name (no spaces)"
$safeProject = $project.ToLower() -replace ' ', '-'

# Port validation
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


# Clone Moodle repository
Write-Host "Cloning Moodle repository..."
git clone https://github.com/moodle/moodle.git -b MOODLE_405_STABLE


# Confirm moodle folder exists
$configDir = ".\moodle"
$configFile = Join-Path $configDir "config.php"


# Write .env file
@"
PROJECT_NAME=$safeProject
MOODLE_PORT=$MoodlePort
PHPMYADMIN_PORT=$PhpMyAdminPort
MAILHOG_PORT=$MailhogPort
MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=moodle
MYSQL_USER=moodle
MYSQL_PASSWORD=moodle
"@ | Out-File -Encoding utf8 -FilePath ".env"

# Create config.php content
$configPhp = @'
<?php

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

require_once(__DIR__ . '/lib/setup.php');
'@

# Replace port placeholder
$configPhp = $configPhp -replace '{PORT}', $MoodlePort


# Create empty config.php if it doesn't exist
if (-not (Test-Path $configFile)) {
    New-Item -ItemType File -Path $configFile | Out-Null
}
$configPhp | Out-File -Encoding utf8 -FilePath $configFile


# Run Docker
docker-compose -p $safeProject up -d --build

# Output info
Write-Host "1. Project '$project' created at $safeProject"
Write-Host "2. Moodle: http://localhost:$MoodlePort"
Write-Host "3. phpMyAdmin: http://localhost:$PhpMyAdminPort"
