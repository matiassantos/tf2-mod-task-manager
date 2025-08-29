# Transport Fever 2 API - Documentación Consolidada

## Introducción

Transport Fever 2 utiliza Lua para sus mods y scripts. La API está organizada en varios módulos principales que proporcionan acceso completo al estado del juego, comandos, interfaz gráfica y recursos.

## Enlaces Oficiales

- **API Reference Principal**: https://transportfever2.com/wiki/api/index.html
- **Wiki de Modding**: https://www.transportfever2.com/wiki/doku.php?id=modding:api
- **Comunidad**: https://www.transportfever.net/

## Estados de Lua (Lua States)

El juego ejecuta scripts en diferentes contextos:

### GUI State
- Acceso completo a funciones de GUI
- Los comandos tardan en ejecutarse (asíncronos)
- Funciones GUI de archivos `.script` se ejecutan aquí

### Engine State
- Estado de simulación (5 actualizaciones por segundo)
- Comandos se ejecutan inmediatamente
- Funciones no-GUI de archivos `.script` se ejecutan aquí

### Console State
- Disponible desde el inicio de la aplicación
- Similar al GUI State
- Acceso a todos los módulos app y api

## Módulos Principales de la API

## 1. api.cmd - Comandos del Juego

Módulo para enviar comandos al motor del juego.

### Funciones Principales

```lua
-- Enviar comando
api.cmd.sendCommand(command, callback)

-- Crear comandos específicos
api.cmd.make.replaceVehicle(vehicleEntity, config)
api.cmd.make.sendToDepot(vehicleEntity, sellOnArrival)
api.cmd.make.sendScriptEvent(fileName, id, data)
api.cmd.make.setAnimalState(animalEntity, movementType, ...)
api.cmd.make.spawnAnimal(modelPath, position)
```

### Ejemplo de Uso

```lua
-- Reemplazar un vehículo
local cfg = api.type.TransportVehicleConfig.new()
local cmd = api.cmd.make.replaceVehicle(66814, cfg)
api.cmd.sendCommand(cmd, function(cmd, valid)
    print("Comando ejecutado:", valid)
end)
```

## 2. api.engine - Estado del Motor

Acceso de solo lectura al estado completo del motor del juego.

### Funciones de Entidades

```lua
-- Verificar si existe una entidad
api.engine.entityExists(entity)

-- Obtener componente de una entidad
api.engine.getComponent(entity, componentType)

-- Iterar sobre todas las entidades
api.engine.forEachEntity(callback)

-- Iterar sobre entidades con componente específico
api.engine.forEachEntityWithComponent(callback, componentType)

-- Obtener revisión de entidad
api.engine.getEntityRevision(entity)
```

### Sistemas Disponibles

```lua
api.engine.system.aircraftMoveSystem      -- Movimiento de aviones
api.engine.system.transportNetworkSystem  -- Redes de transporte
api.engine.system.transportVehicleSystem  -- Vehículos de transporte
api.engine.system.simEntityAtStockSystem  -- Sistema de stock/inventario
```

### Utilidades

```lua
-- Pathfinding
api.engine.util.pathfinding.findPath(fromEdges, toNodes, options, maxDistance)

-- Terreno
api.engine.terrain.isValidCoordinate(coordinate)
```

## 3. api.gui - Interfaz Gráfica

Sistema completo de UI con componentes, layouts y utilidades.

### Componentes (api.gui.comp)

```lua
-- Slider
local slider = api.gui.comp.Slider.new("HORIZONTAL")
slider:onValueChanged(function(value)
    -- Manejar cambio de valor
end)

-- Ventana
local window = api.gui.comp.Window.new("Mi Ventana")
window:addDefaultHandler()  -- Handler para cerrar
window:setContent(content)

-- Componente base
component:setId("mi-id")
component:setName("mi-nombre")
component:setTooltip("Mi tooltip")
component:setVisible(true)
component:setStyleClass({"clase1", "clase2"})
```

### Layouts (api.gui.layout)

Organizan los componentes en la interfaz.

### Utilidades (api.gui.util)

```lua
-- Obtener elemento por ID
local element = api.gui.util.getById("menu.construction.rail.settings")

-- Rectángulo UI
local rect = api.gui.util.Rect.new(x, y, w, h)
rect:contains(pos)
rect:intersects(otherRect)
```

### Funciones del GameUI

```lua
api.gui.getGameUI()           -- Solo en GUI State
api.gui.getCommandTime()      -- Tiempo de procesamiento de comandos
api.gui.getSyncTime()         -- Tiempo de sincronización
api.gui.getSimulationTime()   -- Tiempo de simulación
```

## 4. api.type - Tipos y Estructuras

Contiene todos los tipos de datos, comandos y componentes del juego.

### ComponentType (Enum)

```lua
api.type.ComponentType.ACCOUNT = 0
api.type.ComponentType.AIRCRAFT = 1
api.type.ComponentType.ANIMAL = 2
api.type.ComponentType.CONSTRUCTION = 13
api.type.ComponentType.TRANSPORT_VEHICLE = 67
-- ... muchos más tipos
```

### Vectores y Matrices

```lua
-- Vector 2D (enteros)
local vec2i = api.type.Vec2i.new(x, y)

-- Vector 2D (flotantes)  
local vec2f = api.type.Vec2f.new(x, y)

-- Vector 3D
local vec3f = api.type.Vec3f.new(x, y, z)

-- Matriz 4x4
local mat4f = api.type.Mat4f.new()
```

### Configuraciones de Vehículos

```lua
local config = api.type.TransportVehicleConfig.new()
local part = api.type.TransportVehiclePart.new()
part.purchaseTime = 2933600
part.maintenanceState = 0.99
part.autoLoadConfig = { 1 }
```

### Propuestas (Proposals)

```lua
-- Para construcciones y modificaciones
local proposal = api.type.SimpleProposal.new()
proposal.constructionsToAdd = {}
proposal.constructionsToRemove = {}
```

## 5. api.res - Recursos del Juego

Repositorios que contienen recursos como modelos, tracks, calles, etc.

```lua
-- Obtener todas las construcciones
local constructions = api.res.constructionRep.getAll()

-- Otros repositorios disponibles (necesita más investigación)
api.res.modelRep
api.res.trackRep
api.res.streetRep
```

## 6. api.util - Utilidades Generales

Funciones utilitarias genéricas no asociadas a instancias específicas del juego.

```lua
-- Obtener configuración de la aplicación
local config = api.util.getAppConfig()
-- Contiene modParams y lista de mods activos
```

## 7. app - Control de Aplicación

Funciones de alto nivel para el control de la aplicación.

## Tipos de Archivos de Mod

### .script
Archivos principales que contienen lógica del mod. Se ejecutan parcialmente en diferentes estados.

### .con  
Archivos de construcción que definen estructuras constructibles.

### .mdl
Archivos de modelos 3D.

## Ejemplos Prácticos

### 1. Obtener Información de Industrias

```lua
-- Buscar edificios de simulación
local simBuildings = game.interface.getEntities(
    { pos = {0,0}, radius = math.huge }, 
    { type = "SIM_BUILDING" }
)

for i = 1, #simBuildings do
    local entity = game.interface.getEntity(simBuildings[i])
    local fileName = entity.fileName
    if string.match(fileName, "rail_industry.con") then
        local cargo = api.engine.system.simEntityAtStockSystem.getStockCount(entity.stockList, 0)
        print("Cargo:", cargo)
    end
end
```

### 2. Crear Animal

```lua
local cmd = api.cmd.make.spawnAnimal(
    "animal/bird_eagle.mdl", 
    api.type.Vec2f.new(50, 50)
)
api.cmd.sendCommand(cmd)
```

### 3. Pathfinding

```lua
local e1 = api.type.EdgeId.new(170679, 0)
local e2 = api.type.EdgeId.new(170679, 1)
local n1 = api.type.NodeId.new(171540, 0)

local path = api.engine.util.pathfinding.findPath(
    { api.type.EdgeIdDirAndLength.new(e1, true, 0.0) },
    { n1 },
    {},
    1000
)
```

## Consejos para el Desarrollo

### Debugging

```lua
-- Usar debugPrint para estructuras de tabla
debugPrint(someTable)

-- Usar console para probar comandos
-- El ID de elementos UI se puede obtener con "AltGr + D"
```

### Comunicación Entre Estados

- La comunicación entre estados es compleja
- Los comandos pueden ejecutarse múltiples veces
- Usar mecanismos de sincronización cuando sea necesario

### ModParams

```lua
-- Acceder a parámetros del mod
local appConfig = api.util.getAppConfig()
local modParams = appConfig.modParams
```

## Recursos Adicionales

- **CommonAPI**: Biblioteca de la comunidad para funcionalidades extendidas
- **Transport Fever Community**: Foro principal para desarrolladores
- **Steam Workshop**: Para distribución de mods

## Limitaciones Conocidas

- Documentación incompleta en algunas áreas
- Algunos APIs pueden cambiar entre versiones
- La comunicación entre estados GUI y Engine puede ser compleja
- Limitado soporte para Mac en algunas extensiones de la comunidad