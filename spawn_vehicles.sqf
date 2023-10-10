uiSleep 30;

diag_log ["ExileServer - Spawning persistent vehicle spawns"];
//["ExileServer - Spawning world persistent vehicles"] call MAR_fnc_log;

private ["_count","_uid","_debugForSP","_vehicle","_vehicleArray","_count","_vehicleClass","_position","_positionCount","_pinCode","_vehicleObject","_nearVehicles","_nearVechicleCount","_marker","_cancelSpawn","_isRandomRoadPos","_road","_scriptComplete"];

_scriptComplete = false;
_debugForSP = false;  // Если установлено значение true, при запуске скрипта в редакторе будут создаваться маркеры на местах появления транспортных средств.

_uid = "1234"; //Должен быть действительный UID, который существует в таблице учетных записей (лучше всего использовать UID владельца сервера).

/*
	Как работает массив транспортных средств -

	Выберите 0 - название класса транспортного средства
	Выберите 1 - Число - ограничение по количеству, на сервере будет храниться только это количество транспортных средств
	Выберите 2 - Массив позиций EG [[0,0,0].[0,0,0]]. - Случайным образом выбирает одну из позиций для каждого транспортного средства, если позиция занята, то пытается занять другие позиции
	Select 3 - Boolean - Если true, то автомобиль будет спауниться на случайной дороге, если false, то будет искать позиции выше.

*/

_vehicleArray = 
[
	["B_MRAP_01_hmg_F",1,[],true], // Хантер 12.7
	["O_MRAP_02_gmg_F",1,[],true], // Ифрит с GP
	["B_Heli_Light_01_dynamicLoadout_F",1,[],true], // Пауни
	["B_CTRG_Heli_Transport_01_sand_F",1,[],true], // Госхавк с миниганами
	["I_APC_tracked_03_cannon_F",1,[],true], // Мора
	["O_APC_Wheeled_02_rcws_v2_F",1,[],true] // Марид
];

{
	for "_i" from 0 to (_x select 1) do
	{	
		_cancelSpawn = false;
		_obj = _x select 0;
		_count = count allMissionObjects _obj;
		_positionCount = (count (_x select 2));
		_isRandomRoadPos = _x select 3;

		if !(_count >= _x select 1) then
		{
			_vehicleClass = _x select 0;
			_position = selectRandom (_x select 2);

			if !(_isRandomRoadPos) then
			{
				_foundSafePos = false;
				_failSafe = 15;
				_checks = 0;
				waitUntil 
				{ 
					_position = selectRandom (_x select 2);
					_nearVehicles = nearestObjects [_position, ["car","air","tank","APC"], 10];
					_nearVechicleCount = count _nearVehicles;
					if (_nearVechicleCount == 0) then
					{
						_foundSafePos = true;
					};
					_checks = _checks + 1;
					if (_checks >= _failSafe) then {_cancelSpawn = true; _foundSafePos = true;};
					_foundSafePos
				};		
			}
			else
			{
				_foundSafePos = false;
				waitUntil 
				{
					_spawnCenter = getArray(configFile >> "CfgWorlds" >> worldName >> "centerPosition"); //Центр вашей карты 
					_min = 15; // минимальное расстояние от центральной позиции (Number) в метрах
					_max = 30000; // максимальное расстояние от центрального положения (Число) в метрах
					_mindist = 5; //минимальное расстояние до ближайшего объекта (Number) в метрах, т.е. спаунить нужно как минимум на этом расстоянии от всего, что находится в пределах x метров.
					_water = 0; // водный режим 0: нельзя находиться в воде, 1: можно либо находиться в воде, либо нет, 2: обязательно находиться в воде
					_shoremode = 0; // 0: не обязательно на берегу, 1: обязательно на берегу
					_blackList = [[[0, 0],[0,0]]]; 

					_startPosRoad = [_spawnCenter,_min,_max,_mindist,_water,10,_shoremode,_blackList] call BIS_fnc_findSafePos; //Найти случайное место на карте
					_onRoadCheck = _startPosRoad nearRoads 100; //Найти дорожные объекты в 100 м от точки
					_countPossibleRoads = count _onRoadCheck; // подсчет дорожных объектов

					if (_countPossibleRoads == 0) then 
					{
					}
					else
					{
						_road = _onRoadCheck select 0;
						_position = getPos _road;
						_foundSafePos = true;
					};
					uiSleep 0.1;
					_foundSafePos
				};
			};	
			if !(_cancelSpawn) then
			{	
				if !(_debugForSP) then
				{
					_pinCode = format ["%1%2%3%4",round (random 8 +1),round (random 8 +1),round (random 8 +1),round (random 8 +1)];
					_vehicleObject = [_vehicleClass, _position, (random 360), true,_pinCode] call ExileServer_object_vehicle_createPersistentVehicle;
					_vehicleObject setDamage 0.8;
					_vehicleObject setFuel 0;

					if !((_x select 0) isKindOf "AIR") then
					{
						_wheels = [];
						{
							if (random 1 > 0.8) then
							{	
								_vehicleObject setHitPointDamage [_x,1];
							};	
						} forEach _wheels;
					};	
					_vehicleObject setVariable ["ExileOwnerUID", _uid];
					_vehicleObject setVariable ["ExileIsLocked",0];
					_vehicleObject lock 0;
					_vehicleObject call ExileServer_object_vehicle_database_insert;
					_vehicleObject call ExileServer_object_vehicle_database_update;

					diag_log format ["[Event: Persistent Spawns] -- Spawned a %1 at location: %2 -- Max allowed: %3",_x select 0,_position, _x select 1];
					//[format["[Event: Persistent Spawns] -- Spawned a %1 at location: %2 -- Max allowed: %3",_x select 0,_position, _x select 1]] call MAR_fnc_log;
				}
				else
				{
					_vehicleObject = createVehicle [_vehicleClass,_position,[], 0, "NONE"];

					if !((_x select 0) isKindOf "AIR") then
					{
						_wheels = [];
						{
							_vehicleObject setHitPointDamage [_x,1];
						} forEach _wheels;
					};

					_marker = createMarker [format["HeliCrash%1", diag_tickTime], _position];
					_marker setMarkerType "mil_dot";
					_marker setMarkerText "Vehicle";
				};
			}
			else
			{
				if !(_debugForSP) then
				{
					//[format["[Event: Persistent Spawns] -- Could not find valid spawn position for %1 at position %2 -- exiting try for this vehicle",_x select 0,_position]] call MAR_fnc_log;
					diag_log format["[Event: Persistent Spawns] -- Could not find valid spawn position for %1 at position %2 -- exiting try for this vehicle",_x select 0,_position];
				}
				else
				{
					hint format["[Event: Persistent Spawns] -- Could not find valid spawn position for %1 at position %2 -- exiting try for this vehicle",_x select 0,_position];
				};	
			};		
		};
	};		
	
} forEach _vehicleArray;

_scriptComplete = true;

waitUntil 
{
	diag_log format ["ExileServer - Finished spawning world vehicles"];
	//["ExileServer - Finished spawning world vehicles"] call MAR_fnc_log;
	_scriptComplete
};