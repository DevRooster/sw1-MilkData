<#
.SYNOPSIS
    Mantiene el puente entre el móvil y la API de MilkData.

.DESCRIPTION
    El móvil habla con la API en `127.0.0.1:3000`. Esa dirección es SIEMPRE la
    del propio móvil: nunca es "la del ordenador". Lo que hace que llegue al PC
    es `adb reverse tcp:3000 tcp:3000`, que abre un túnel desde el móvil hasta
    el puerto 3000 de esta máquina.

    El problema es que ese túnel **vive en la sesión de adb**. Al desenchufar y
    volver a enchufar el cable, adb reconstruye la conexión y el túnel se
    pierde sin avisar. Por eso hay que ejecutar el comando a mano cada vez, y por
    eso la app dice que no puede contactar con el servidor justo después de
    reconectar.

    Este script quita ese paso: vigila el dispositivo y, en cuanto aparece (o en
    cuanto comprueba que el túnel ha desaparecido), lo vuelve a levantar.

.NOTES
    ¿Hace falta abrir el cortafuegos? NO, si usas el móvil por USB con este
    script. Todo el tráfico va por el túnel, y el túnel no entra por ninguna red:
    no lo inspecciona el cortafuegos de Windows.

    La regla de cortafuegos solo hace falta para lo contrario: trabajar por WiFi
    sin cable. En ese caso la app tendría que apuntar a la IP del PC y no a
    127.0.0.1, y además el perfil de red de la Ethernet está en "Público", que
    bloquea la entrada por defecto. Con la consola de PowerShell **como
    administrador**:

        New-NetFirewallRule -DisplayName "MilkData API" -Direction Inbound `
            -Action Allow -Protocol TCP -LocalPort 3000 -Profile Any

    Y la IP que hay que poner en la app es la del adaptador del punto de acceso
    de Windows, no la de la Ethernet. Medido en esta maquina:

        movil  ->  192.168.137.129
        PC     ->  192.168.137.1   ("Conexion de area local* 2")

    Esa IP la pone Windows siempre en el mismo sitio, asi que no hay problema de
    IP dinamica; pero ese adaptador solo existe mientras el punto de acceso este
    encendido.

.PARAMETER Vigilar
    No termina: se queda vigilando. Es el modo normal, el de "conéctame y ya no
    me vuelvas a preguntar".

.PARAMETER Intervalo
    Segundos entre comprobaciones. Por defecto 3.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\conectar-telefono.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\conectar-telefono.ps1 -Vigilar
#>
[CmdletBinding()]
param(
    [switch] $Vigilar,
    [int]    $Intervalo = 3
)

$ErrorActionPreference = 'Stop'

# --- Dónde está adb ---------------------------------------------------------
# No vale confiar en el PATH: si se abre el script desde el Explorador de
# archivos hereda un PATH de usuario que normalmente no incluye platform-tools,
# y el fallo que sale ("adb no se reconoce") no dice nada del problema real.
$rutasAdb = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
    (Join-Path $env:USERPROFILE  'AppData\Local\Android\Sdk\platform-tools\adb.exe')
    'C:\Android\platform-tools\adb.exe'
    (Join-Path $env:ProgramFiles 'Android\Android Studio\platform-tools\adb.exe')
)

$adb = $rutasAdb | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $adb) {
    $enPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($enPath) {
        $adb = $enPath.Source
    } else {
        Write-Host 'No encuentro adb.exe.' -ForegroundColor Red
        Write-Host 'Se ha buscado en:' -ForegroundColor Red
        $rutasAdb | ForEach-Object { Write-Host "  $_" }
        Write-Host 'Solucion: instala las platform-tools de Android o anade su carpeta al PATH.' -ForegroundColor Red
        exit 1
    }
}

Write-Host "adb: $adb" -ForegroundColor DarkGray

# --- El servidor de adb -----------------------------------------------------
# Si el servidor no está corriendo, `adb devices` responde con un error en
# lugar de una lista vacía, y el script se comería ese texto como si fueran
# dispositivos. Se arranca explícitamente una vez y se espera a que esté listo.
& $adb start-server | Out-Null
Start-Sleep -Seconds 1

$PUERTO = 3000

function Get-DispositivosConectados {
    <#
        Devuelve la lista de seriales en modo `device`.

        Filtra por `device` a propósito: un móvil en `unauthorized` u `offline`
        aparece en la lista pero no admite conexiones, y tratarlo como
        conectado daría un túnel que no funciona y ningún aviso de por qué.

        **Puede devolver más de uno, y no es un fallo.** El mismo móvil aparece
        dos veces si está enchufado por USB y además tiene la depuración por WiFi
        encendida: `R9WN40ABPYJ` y `192.168.137.129:5555` son el mismo teléfono
        por dos caminos distintos. Lo que sí falla es tratar eso como uno solo.
    #>
    $salida = & $adb devices 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }

    $seriales = @()

    foreach ($linea in $salida) {
        # Formato: "<serial>\t<estado>"
        if ($linea -match '^(\S+)\s+device\s*$') {
            $seriales += $Matches[1]
        }
    }

    return $seriales
}

function Test-Puente {
    param([Parameter(Mandatory)][string] $Dispositivo)

    <#
        ¿Está el túnel `tcp:3000 -> tcp:3000` montado en ESE dispositivo ahora mismo?

        Se pregunta a `adb reverse --list` y no se guarda estado propio, a
        propósito: adb puede tirar el túnel por su cuenta a mitad de sesión
        (reinicio del dispositivo, cambio de cable USB, adb que se reinicia), y
        un vigilante que confiara en su propia memoria no se enteraría.

        El `-s` no es opcional. Sin él, con dos dispositivos conectados adb contesta
        "more than one device/emulator", no monta nada y sale con codigo 0: el
        tunel se queda caido sin decir por que. Este script hacia justo eso.
    #>
    $lineas = & $adb -s $Dispositivo reverse --list 2>$null
    if (-not $lineas) { return $false }

    foreach ($linea in $lineas) {
        # Formato: "<serial> tcp:<puerto-remoto> tcp:<puerto-local>"
        if ($linea -match "tcp:$PUERTO\s+tcp:$PUERTO") {
            return $true
        }
    }

    return $false
}

function Set-Puente {
    param([Parameter(Mandatory)][string] $Dispositivo)

    <#
        Monta el túnel en un dispositivo concreto.

        Igual que en `Test-Puente`, el `-s` no es opcional: sin él, con dos
        dispositivos conectados, adb responde "more than one device/emulator" pero
        devuelve codigo 0, y el script dice "listo" con el puente caido.
    #>
    & $adb -s $Dispositivo reverse "tcp:$PUERTO" "tcp:$PUERTO" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("  adb reverse fallo en {0}: reintenta con el movil desbloqueado y 'Depuracion USB' activada." -f $Dispositivo) -ForegroundColor Red
        return $false
    }
    return $true
}

# --- Modo simple: una pasada y salir ----------------------------------------
if (-not $Vigilar) {
    $dispositivos = Get-DispositivosConectados

    if (-not $dispositivos) {
        Write-Host 'No hay ningun movil conectado por USB.' -ForegroundColor Yellow
        Write-Host 'Conectalo y ejecuta esto otra vez.' -ForegroundColor Yellow
        exit 1
    }

    # El mismo movil puede aparecer dos veces: enchufado por USB y ademas con la
    # depuracion por WiFi. El puente va en los dos, porque no sabemos por cual le
    # habla la app, y adb exige `-s` para no confundirse.
    if ($dispositivos.Count -gt 1) {
        Write-Host ("El movil aparece por $($dispositivos.Count) caminos: $($dispositivos -join ', ')") -ForegroundColor DarkGray
    }

    $fallos = 0

    foreach ($dispositivo in $dispositivos) {
        if (Test-Puente $dispositivo) {
            Write-Host "El puente ya estaba puesto ($dispositivo). No hacia falta nada." -ForegroundColor Green
        }
        elseif (Set-Puente $dispositivo) {
            Write-Host "Puente puesto en ${dispositivo}: el movil 127.0.0.1:$PUERTO ahora es este PC." -ForegroundColor Green
        }
        else {
            $fallos++
        }
    }

    exit ([int]($fallos -gt 0))
}

# --- Modo vigilar: quedarse esperando ---------------------------------------
Write-Host ''
Write-Host 'Vigilando el movil. Ctrl+C para salir.' -ForegroundColor Cyan
Write-Host 'Se levanta el puente solo al conectar y si adb lo pierde por el camino.' -ForegroundColor DarkGray
Write-Host ''

$ultimoEstado = ''

while ($true) {
    try {
        $dispositivos = Get-DispositivosConectados

        # Cuantos caminos del movil hay sin puente. Con dos transportes suele ser
        # uno de los dos: lo normal es que uno se levante solo y el otro no haga
        # falta, asi que se levanta el que falte y se deja el que ya estaba.
        $sinPuente = @($dispositivos | Where-Object { -not (Test-Puente $_) })

        $estado = if (-not $dispositivos)  { 'sin-movil' }
                  elseif ($sinPuente.Count -eq 0) { 'ok' }
                  else                        { 'sin-puente' }

        if ($estado -ne $ultimoEstado) {
            switch ($estado) {
                'ok' {
                    Write-Host ("[{0}] {1} conectado, puente en pie." -f (Get-Date -Format 'HH:mm:ss'), ($dispositivos -join ', ')) -ForegroundColor Green
                }
                'sin-puente' {
                    Write-Host ("[{0}] {1} conectado pero SIN puente: adb lo perdio." -f (Get-Date -Format 'HH:mm:ss'), ($sinPuente -join ', ')) -ForegroundColor Yellow
                }
                'sin-movil' {
                    Write-Host ("[{0}] Ningun movil por USB." -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkGray
                }
            }
            $ultimoEstado = $estado
        }

        # Solo se levanta el puente cuando falta de verdad. Refrescarlo sin
        # parar tantearia la conexion de la app en cada vuelta del bucle.
        foreach ($dispositivo in $sinPuente) {
            if (Set-Puente $dispositivo) {
                Write-Host ("[{0}] Puente levantado en {1}. App lista." -f (Get-Date -Format 'HH:mm:ss'), $dispositivo) -ForegroundColor Cyan
            }
        }
    } catch {
        # Un fallo puntual (adb se reinicia, el cable se mueve) no debe tumbar
        # el vigilante: se avisa y se sigue.
        Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $_.Exception.Message) -ForegroundColor Red
    }

    Start-Sleep -Seconds $Intervalo
}
