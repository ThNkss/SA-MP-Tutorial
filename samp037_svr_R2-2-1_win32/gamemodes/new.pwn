#include <a_samp>
#include <zcmd>
#include <a_mysql>
#include <streamer>
//----------Colors-------
#define Red 0xFF0000FF
#define Green 0x00FF00FF
//----------consts-------

#define DB_Username "thnks"
#define DB_Password "ZzayMfn5(3u1Ee8r"
#define DB_Host "127.0.0.1"
#define DB_Database "sampdata"

#define MAX_HOUSES 10
#define MAX_HOUSE_TYPE 2
#define HOUSE_ENTER_MODEL 1318
#define HOUSE_LABEL_SOLD 19522
#define HOUSE_LABEL 1273


#define DEFAULT_X 2245.1165
#define DEFAULT_Y -1262.9821
#define DEFAULT_Z 23.9507
#define DEFAULT_A 180.0
//---------Dialogs------
#define DIALOG_LOGIN 1001
#define DIALOG_REGISTER 1002
//----------Enums--------
enum e_housedata
{
	house_owner[MAX_PLAYER_NAME],
	house_id,
	house_days,
	house_type,

	Float:house_exitposx,
	Float:house_exitposy,
	Float:house_exitposz,
	Float:house_exitposa,

	Float:house_enterx,
	Float:house_entery,
	Float:house_enterz,
	
	Float:house_labelx,
	Float:house_labely,
	Float:house_labelz,

	STREAMER_TAG_PICKUP:house_enterp,
	STREAMER_TAG_PICKUP:house_labelp,
	STREAMER_TAG_3D_TEXT_LABEL:house_labelt

}
enum e_housetemplate
{
	house_interior,

	Float:house_enterposx,
	Float:house_enterposy,
	Float:house_enterposz,
	Float:house_enterposa,

	Float:house_exitx,
	Float:house_exity,
	Float:house_exitz,
	STREAMER_TAG_PICKUP:house_exitp
}
enum e_player
{
	ORM:ORM_ID,
	Username[24],
	Password[65],
	Salt[17],
	p_ID,
	Float:X_Pos,
	Float:Y_Pos,
	Float:Z_Pos,
	Float:A_Pos,
	p_interior,
	p_world,
	p_money,
	p_skin,
	p_temphouse,
	bool:FirstSpawn,
}
enum e_vehicle 
{
	v_model,
	v_owner[24],
	bool:Spawned
}

//---------stocks--------
stock GetName(playerid)
{
	new tempstring[MAX_PLAYER_NAME];
	GetPlayerName(playerid, tempstring, sizeof tempstring);
	return tempstring;
}
//----------Variables----
new MySQL:g_SQL;
new Player[MAX_PLAYERS][e_player];
new Vehicle[MAX_VEHICLES][e_vehicle];
new House[MAX_HOUSES][e_housedata];
new HouseType[MAX_HOUSE_TYPE][e_housetemplate];
new HouseLoaded = 0;
//----------Callbacks----

main()
{
	print("\n----------------------------------");
	print(" This is our first Gamemode");
	print("----------------------------------\n");
}

public OnGameModeInit()
{
	g_SQL = mysql_connect(DB_Host, DB_Username, DB_Password, DB_Database);
	if(g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
	{
		print("could not connect to database");
		OnRconCommand("exit");
	}
	LoadServerVehicles();
	print("Connected to database.");
	SetGameModeText("Blank Script");
	mysql_log(INFO);
	new text[144];
	mysql_format(g_SQL, text, sizeof text,"SELECT * FROM `houses`");
	mysql_tquery(g_SQL, text, "OnHousesDownloaded");
	LoadHouseTypes();
	DisableInteriorEnterExits();
	AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);
	return 1;
}

public OnGameModeExit()
{
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	SpawnPlayer(playerid);
	return 1;
}
public OnPlayerConnect(playerid)
{
	new EmptyPlayerData[e_player];
	Player[playerid] = EmptyPlayerData;
	GetPlayerName(playerid, Player[playerid][Username], MAX_PLAYER_NAME);

	new ORM:ormid = Player[playerid][ORM_ID] = orm_create("players",g_SQL);

	orm_addvar_string(ormid, Player[playerid][Username],MAX_PLAYER_NAME , "username");
	orm_setkey(ormid, "username");
	orm_addvar_string(ormid, Player[playerid][Password],65, "password");
	orm_addvar_string(ormid, Player[playerid][Salt],17, "salt");

	orm_addvar_float(ormid, Player[playerid][X_Pos], "x");
	orm_addvar_float(ormid, Player[playerid][Y_Pos], "y");
	orm_addvar_float(ormid, Player[playerid][Z_Pos], "z");
	orm_addvar_float(ormid, Player[playerid][A_Pos], "a");

	orm_addvar_int(ormid, Player[playerid][p_interior], "interior");
	orm_addvar_int(ormid, Player[playerid][p_ID], "id");
	orm_addvar_int(ormid, Player[playerid][p_skin], "skin");
	orm_addvar_int(ormid, Player[playerid][p_money], "money");
	orm_addvar_int(ormid, Player[playerid][p_world], "virtualworld");

	orm_load(ormid, "OnPlayerDataLoaded","d",playerid);
	
	return 1;
}
forward OnPlayerDataLoaded(playerid);
public OnPlayerDataLoaded(playerid)
{
	SetPlayerCameraPos(playerid, 1924.6676,-1520.9697,69.4163);
	SetPlayerCameraLookAt(playerid, 1966.1248,-1481.6318,51.4163);

	orm_setkey(Player[playerid][ORM_ID], "id");

	switch(orm_errno(Player[playerid][ORM_ID]))
	{
		case ERROR_NO_DATA:
		{
			new text[144];
			format(text,sizeof text,"{FFFFFF}Welcome {FF0169}%s{FFFFFF}, enter your password in order to complete registration.",Player[playerid][Username]);
			ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registration", text, "{00FF00}Register", "{FF0000}Cancel");
		}
		case ERROR_OK:
		{
			new text[144];
			format(text,sizeof text,"Welcome %s, enter your password in order to continue.",Player[playerid][Username]);
			ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", text, "Login", "Cancel");
		}
	}
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	Player[playerid][p_world] = GetPlayerVirtualWorld(playerid);
	Player[playerid][p_interior] = GetPlayerInterior(playerid);

	GetPlayerPos(playerid, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos]);
	GetPlayerFacingAngle(playerid, Player[playerid][A_Pos]);
	orm_update(Player[playerid][ORM_ID]);
	return 1;
}

public OnPlayerSpawn(playerid)
{
	if(!Player[playerid][FirstSpawn])
	{
		Player[playerid][FirstSpawn] = true;
		SetPlayerPos(playerid, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos]);
		SetPlayerFacingAngle(playerid, Player[playerid][A_Pos]);
		SetCameraBehindPlayer(playerid);
		SetPlayerInterior(playerid, Player[playerid][p_interior]);
		SetPlayerVirtualWorld(playerid, Player[playerid][p_world]);
		SetPlayerSkin(playerid, Player[playerid][p_skin]);
		GivePlayerMoney(playerid, Player[playerid][p_money]);
	}

	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	return 1;
}

public OnVehicleSpawn(vehicleid)
{
	return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{

	return 1;
}

public OnPlayerText(playerid, text[])
{
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	return 0;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
	return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveCheckpoint(playerid)
{

	return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveRaceCheckpoint(playerid)
{
	return 1;
}

public OnRconCommand(cmd[])
{
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	return 1;
}

public OnObjectMoved(objectid)
{
	return 1;
}

public OnPlayerObjectMoved(playerid, objectid)
{
	return 1;
}
public OnPlayerPickUpDynamicPickup(playerid, STREAMER_TAG_PICKUP:pickupid)
{
	for(new i=0;i<HouseLoaded;i++)
	{
		if(pickupid == House[i][house_enterp])
		{
			if(!strcmp(GetName(playerid), House[i][house_owner]))
			{
				SetPlayerInterior(playerid, HouseType[House[i][house_type]][house_interior]);
				SetPlayerPos(playerid, HouseType[House[i][house_type]][house_enterposx], HouseType[House[i][house_type]][house_enterposy], HouseType[House[i][house_type]][house_enterposz]);
				SetPlayerFacingAngle(playerid, HouseType[House[i][house_type]][house_enterposa]);
				SetPlayerVirtualWorld(playerid, House[i][house_id]);
				SetCameraBehindPlayer(playerid);
			}
			return 1;
		}
		if(pickupid == House[i][house_labelp])
		{
			Player[playerid][p_temphouse] = i;
		}
	}
	for(new i=0;i<MAX_HOUSE_TYPE;i++)
	{
		if(pickupid == HouseType[i][house_exitp])
		{
			for(new r=0;r<HouseLoaded;r++)
			{
				if(House[r][house_id] == GetPlayerVirtualWorld(playerid))
				{
					SetPlayerInterior(playerid, 0);
					SetPlayerPos(playerid, House[r][house_exitposx], House[r][house_exitposy], House[r][house_exitposz]);
					SetPlayerFacingAngle(playerid, House[r][house_exitposa]);
					SetPlayerVirtualWorld(playerid, 0);
					SetCameraBehindPlayer(playerid);
				}
			}
			return 1;
		}
	}
	return 1;
}
public OnPlayerPickUpPickup(playerid, pickupid)
{
	return 1;
}

public OnVehicleMod(playerid, vehicleid, componentid)
{
	return 1;
}

public OnVehiclePaintjob(playerid, vehicleid, paintjobid)
{
	return 1;
}

public OnVehicleRespray(playerid, vehicleid, color1, color2)
{
	return 1;
}

public OnPlayerSelectedMenuRow(playerid, row)
{
	return 1;
}

public OnPlayerExitedMenu(playerid)
{
	return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	return 1;
}

public OnRconLoginAttempt(ip[], password[], success)
{
	return 1;
}

public OnPlayerUpdate(playerid)
{
	return 1;
}

public OnPlayerStreamIn(playerid, forplayerid)
{
	return 1;
}

public OnPlayerStreamOut(playerid, forplayerid)
{
	return 1;
}

public OnVehicleStreamIn(vehicleid, forplayerid)
{
	return 1;
}

public OnVehicleStreamOut(vehicleid, forplayerid)
{
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
		case DIALOG_REGISTER:
		{
			if(strlen(inputtext) <= 5) return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registration", "The password lenght must be more than 5.","Register","Cancel");

			for(new i=0;i<16;i++) Player[playerid][Salt][i] = random(94) + 33;
			SHA256_PassHash(inputtext, Player[playerid][Salt], Player[playerid][Password], 64);	
			orm_save(Player[playerid][ORM_ID]);
			OnPlayerRegister(playerid);
		}
		case DIALOG_LOGIN:
		{
			if(strlen(inputtext) <= 5) return ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "{FF0000}Wrong password!","Login","Cancel");

			new temppass[65];
			SHA256_PassHash(inputtext, Player[playerid][Salt], temppass, 64);
			if(!strcmp(temppass, Player[playerid][Password]))
			{//login
				OnPlayerLogin(playerid);
			}	
			else 
			{//wrong pass
				return ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "{FF0000}Wrong password!","Login","Cancel");
			}

		}
	}
	return 1;
}

public OnPlayerClickPlayer(playerid, clickedplayerid, source)
{
	return 1;
}

//------------Custom Functions-------
forward LoadServerVehicles();
public LoadServerVehicles()
{
	new TempData = CreateVehicle(541, 2077.2307,1392.6534,10.6719,0.0911, -1, -1, 300);
	Vehicle[TempData][v_model] = 541;
	Vehicle[TempData][Spawned] = true;
	return 1;
}
forward OnPlayerLogin(playerid);
public OnPlayerLogin(playerid)
{
	SpawnPlayer(playerid);
	SendClientMessage(playerid, 0xFF0000FF, "You are logged in.");
	return 1;
}
forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
	new NoobSkins[] = {4, 6, 7};
	Player[playerid][X_Pos] = DEFAULT_X;
	Player[playerid][Y_Pos] = DEFAULT_Y;
	Player[playerid][Z_Pos] = DEFAULT_Z;
	Player[playerid][A_Pos] = DEFAULT_A;
	Player[playerid][p_skin] = NoobSkins[random(sizeof NoobSkins)];
	SpawnPlayer(playerid);
	SendClientMessage(playerid, 0xFF0000FF, "You are registered.");
	Player[playerid][p_money] = 100000;
	return 1;
}
forward LoadHouseTypes();
public LoadHouseTypes()
{
	//The Johnson house
	HouseType[0][house_interior] = 3;

	HouseType[0][house_enterposx] = 2495.8882;
	HouseType[0][house_enterposy] = -1694.9662;
	HouseType[0][house_enterposz] = 1014.7422;
	HouseType[0][house_enterposa] = 180;

	HouseType[0][house_exitx] = 2496.0051;
	HouseType[0][house_exity] = -1692.0834;
	HouseType[0][house_exitz] = 1014.7422;

	HouseType[0][house_exitp] = CreateDynamicPickup(HOUSE_ENTER_MODEL, 1, HouseType[0][house_exitx], HouseType[0][house_exity], HouseType[0][house_exitz], -1, 3);

	return 1;
}
forward OnHousesDownloaded();
public OnHousesDownloaded()
{
	HouseLoaded = 0;
	new rows;
	cache_get_row_count(rows);
	for(new i=0;i<rows;i++)
	{
		cache_get_value_name(i,"house_owner",House[i][house_owner], MAX_PLAYER_NAME);

		cache_get_value_name_int(i,"house_id",House[i][house_id]);
		cache_get_value_name_int(i,"house_type",House[i][house_type]);
		cache_get_value_name_int(i,"house_days",House[i][house_days]);
		
		cache_get_value_name_float(i,"house_exitposx",House[i][house_exitposx]);
		cache_get_value_name_float(i,"house_exitposy",House[i][house_exitposy]);
		cache_get_value_name_float(i,"house_exitposz",House[i][house_exitposz]);
		cache_get_value_name_float(i,"house_exitposa",House[i][house_exitposa]);
		
		cache_get_value_name_float(i,"house_enterx",House[i][house_enterx]);
		cache_get_value_name_float(i,"house_entery",House[i][house_entery]);
		cache_get_value_name_float(i,"house_enterz",House[i][house_enterz]);
		
		cache_get_value_name_float(i,"house_labelx",House[i][house_labelx]);
		cache_get_value_name_float(i,"house_labely",House[i][house_labely]);
		cache_get_value_name_float(i,"house_labelz",House[i][house_labelz]);
		HouseLoaded++;
		House[i][house_enterp] = CreateDynamicPickup(HOUSE_ENTER_MODEL, 1, House[i][house_enterx], House[i][house_entery], House[i][house_enterz],0, 0);
		UpdateHousePickups(i);
		
	}
	return 1;
}
forward UpdateHousePickups(i);
public UpdateHousePickups(i)
{
	if(House[i][house_labelp])
	{
		DestroyDynamicPickup(House[i][house_labelp]);
	}
	if(House[i][house_labelt])
	{
		DestroyDynamic3DTextLabel(House[i][house_labelt]);
	}
	if(!strcmp(House[i][house_owner],"server"))
	{//server
		House[i][house_labelp] = CreateDynamicPickup(HOUSE_LABEL, 1, House[i][house_labelx], House[i][house_labely], House[i][house_labelz], 0, 0);
		new text[144];
		format(text,sizeof text, "House ID: %d\nOwner: None\n",House[i][house_id]);
		House[i][house_labelt] = CreateDynamic3DTextLabel(text,Green, House[i][house_labelx], House[i][house_labely], House[i][house_labelz]+1.0, 30.0);
	}
	else 
	{//has owner
		House[i][house_labelp] = CreateDynamicPickup(HOUSE_LABEL_SOLD, 1, House[i][house_labelx], House[i][house_labely], House[i][house_labelz], 0, 0);
		new text[144];
		format(text,sizeof text, "House ID: %d\nOwner: %s\n",House[i][house_id], House[i][house_owner]);
		House[i][house_labelt] = CreateDynamic3DTextLabel(text,Red, House[i][house_labelx], House[i][house_labely], House[i][house_labelz]+1.0, 30.0);
	}
	return 1;
}
forward MoveHouseOwnership(i, playerid);
public MoveHouseOwnership(i, playerid)
{
	format(House[i][house_owner],MAX_PLAYER_NAME, "%s",GetName(playerid));
	new text[144];
	mysql_format(g_SQL, text, sizeof text, "UPDATE `houses` SET `house_owner` = '%s' WHERE `houses`.`house_id` = %d;",House[i][house_owner], House[i][house_id]);
	mysql_tquery(g_SQL, text);
	UpdateHousePickups(i);
	return 1;
}

new HouseCreating = 0;
new Float:House_label[3];
new Float:House_enter[3];
new Float:House_exitpos[4];
forward CreateHouse(playerid);
public CreateHouse(playerid)
{
	new ORM:ormid = orm_create("houses",g_SQL);

	new houseindex = HouseLoaded;

	if(HouseLoaded)
	{
		House[houseindex][house_id] = House[houseindex - 1][house_id] + 1;
	}
	else 
	{
		House[houseindex][house_id] = 1;
	}
	format(House[houseindex][house_owner],MAX_PLAYER_NAME, "server");
	House[houseindex][house_days] = 1000;
	House[houseindex][house_type] = 0;
	House[houseindex][house_enterx] = House_enter[0];
	House[houseindex][house_entery] = House_enter[1];
	House[houseindex][house_enterz] = House_enter[2];

	House[houseindex][house_labelx] = House_label[0];
	House[houseindex][house_labely] = House_label[1];
	House[houseindex][house_labelz] = House_label[2];

	House[houseindex][house_exitposx] = House_exitpos[0];
	House[houseindex][house_exitposy] = House_exitpos[1];
	House[houseindex][house_exitposz] = House_exitpos[2];
	House[houseindex][house_exitposa] = House_exitpos[3];

	orm_addvar_string(ormid, House[houseindex][house_owner],MAX_PLAYER_NAME, "house_owner");
	orm_addvar_int(ormid, House[houseindex][house_id], "house_id");
	orm_setkey(ormid, "house_id");
	orm_addvar_float(ormid, House[houseindex][house_labelx], "house_labelx");
	orm_addvar_float(ormid, House[houseindex][house_labely], "house_labely");
	orm_addvar_float(ormid, House[houseindex][house_labelz], "house_labelz");

	orm_addvar_float(ormid, House[houseindex][house_enterx], "house_enterx");
	orm_addvar_float(ormid, House[houseindex][house_entery], "house_entery");
	orm_addvar_float(ormid, House[houseindex][house_enterz], "house_enterz");

	orm_addvar_float(ormid, House[houseindex][house_exitposx], "house_exitposx");
	orm_addvar_float(ormid, House[houseindex][house_exitposy], "house_exitposy");
	orm_addvar_float(ormid, House[houseindex][house_exitposz], "house_exitposz");
	orm_addvar_float(ormid, House[houseindex][house_exitposa], "house_exitposa");

	orm_insert(ormid,"TellUser","d",playerid);
	House[houseindex][house_enterp] = CreateDynamicPickup(HOUSE_ENTER_MODEL, 1, House[houseindex][house_enterx], House[houseindex][house_entery], House[houseindex][house_enterz],0, 0);
	UpdateHousePickups(houseindex);
	HouseLoaded++;

	return 1;
}
forward TellUser(playerid);
public TellUser(playerid)
{
	SendClientMessage(playerid, 0xFFFF00FF, "House Was Made");
	return 1;
}
// Commands

CMD:help(playerid, params[])
{
    SendClientMessage(playerid, 0xFFFF00FF, "This is the help command");
    return 1;
}

CMD:bullet(playerid, params[])
{
	new Float:PlayerPos[4];
 	GetPlayerPos(playerid, PlayerPos[0], PlayerPos[1], PlayerPos[2]);
 	GetPlayerFacingAngle(playerid, PlayerPos[3]);
	CreateVehicle(541, PlayerPos[0], PlayerPos[1], PlayerPos[2], PlayerPos[3], 1, 1, 300);
	return 1;
}
CMD:jump(playerid, params[])
{
    new Float:PlayerPos[3];
    GetPlayerPos(playerid, PlayerPos[0], PlayerPos[1], PlayerPos[2]);
   	SetPlayerPos(playerid, PlayerPos[0], PlayerPos[1], PlayerPos[2]+10.0);
	return 1;
}
CMD:buyhouse(playerid, params[])
{
	MoveHouseOwnership(Player[playerid][p_temphouse],playerid);
	return 1;
}
CMD:createhouse(playerid, params[])
{
	GetPlayerPos(playerid,House_label[0],House_label[1],House_label[2]);
	HouseCreating++;
	SendClientMessage(playerid, Red, "Now type setenter to save enterpickup position.");
	return 1;
}
CMD:setener(playerid, params[])
{
	GetPlayerPos(playerid, House_enter[0],House_enter[1],House_enter[2]);
	HouseCreating++;
	SendClientMessage(playerid, Red, "Now type setexit to save exit position.");
	return 1;
}
CMD:setexit(playerid, params[])
{
	GetPlayerPos(playerid, House_exitpos[0],House_exitpos[1],House_exitpos[2]);
	GetPlayerFacingAngle(playerid, House_exitpos[3]);
	HouseCreating++;
	if(HouseCreating % 3 == 0)
	{
		CreateHouse(playerid);
	}
	return 1;
}