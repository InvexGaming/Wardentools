#if defined _wardentools_included
  #endinput
#endif
#define _wardentools_included

#include "warden.inc"

//Global Defines
#define WT_VERSION "2.03"
#define CHAT_TAG_PREFIX "[{pink}Warden Tools{default}] "

#define HIDE_RADAR_CSGO 1<<12
#define MAX_WEAPONS 44

//Returns true if round is a special day, false otherwise
native bool WardenTools_IsSpecialDay();

//Get Warden
stock int GetWarden()
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      if (view_as<bool>(warden_iswarden(i)))
        return i;
    }
  }
  
  return -1;
}

//Toggle unlockables from store
stock void toggleUnlockables(int team, int value)
{
  ConVar jetpack = null;
  ConVar bunnyhop = null;
  
  if (team == CS_TEAM_T) {
    jetpack = FindConVar("sm_store_jetpack_enabled_t");
    bunnyhop = FindConVar("sm_store_bunnyhop_enabled_t");
  }
  else if (team == CS_TEAM_CT) {
    jetpack = FindConVar("sm_store_jetpack_enabled_ct");
    bunnyhop = FindConVar("sm_store_bunnyhop_enabled_ct");
  }
  
  //Set value
  if (jetpack != null)
    SetConVarInt(jetpack, value);
  if (bunnyhop != null)
    SetConVarInt(bunnyhop, value); 
}

stock Action RemoveRadar(Handle timer, int client)
{
  if(client == 0)
    return;

  SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDE_RADAR_CSGO);
}

//Disble the medic (or anything that heals, negative valued trigger_hurt's) until the end of the round
stock void Disable_Medics()
{
  int entity = -1;
  while ((entity = FindEntityByClassname(entity, "trigger_hurt")) != INVALID_ENT_REFERENCE) {
    if (GetEntPropFloat(entity, Prop_Data, "m_flDamage") < 0) {
      AcceptEntityInput(entity, "Disable");
    }
  }
}

//From: https://forums.alliedmods.net/showthread.php?t=111684
stock void DealDamage(int victim, int damage, int attacker=0, int dmg_type=DMG_GENERIC, char weapon[] = "")
{
  if (victim>0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage>0) {
    char dmg_str[16];
    IntToString(damage, dmg_str, sizeof(dmg_str));
    char dmg_type_str[32];
    IntToString(dmg_type, dmg_type_str, sizeof(dmg_type_str));
    
    int  pointHurt = CreateEntityByName("point_hurt");
    
    if(pointHurt) {
      DispatchKeyValue(victim, "targetname", "war3_hurtme");
      DispatchKeyValue(pointHurt, "DamageTarget", "war3_hurtme");
      DispatchKeyValue(pointHurt, "Damage", dmg_str);
      DispatchKeyValue(pointHurt, "DamageType", dmg_type_str);
      if (!StrEqual(weapon,"")) {
        DispatchKeyValue(pointHurt,"classname",weapon);
      }
      DispatchSpawn(pointHurt);
      AcceptEntityInput(pointHurt, "Hurt", (attacker>0)?attacker:-1);
      DispatchKeyValue(pointHurt, "classname", "point_hurt");
      DispatchKeyValue(victim, "targetname", "war3_donthurtme");
      RemoveEdict(pointHurt);
    }
  }
}

stock void ShowOverlayToClient(int client, const char[] overlaypath)
{
  ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

stock Action RemoveOverlay(Handle timer, int client)
{
  //Remove overlay
  ShowOverlayToClient(client, "");
}

//Sets a new clan tag while preserving the previous clan tag
stock void setAndPreserveClanTag(int client, char[] newClanTag, char[][] clantagStorage)
{
  //Preserve current clan tag
  if (strlen(clantagStorage[client]) == 0)  //only if it hasn't already been preserved (due to multi respawns)
    CS_GetClientClanTag(client, clantagStorage[client], 32);
  
  //Set clan tag
  CS_SetClientClanTag(client, newClanTag);
}

//Strip weapons
stock void StripWeapons(int client) {
  for (int i = 0; i < MAX_WEAPONS; i++) { 
    int index = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
    
    if(index && IsValidEdict(index))
      RemoveWeaponDrop(client, index);
  }
}

stock void RemoveWeaponDrop(int client, int entity) 
{
  if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") != client) {
    LogAction(client, -1, "Weapon had incorrect owner. Entity was: %d. This may be an error.", entity);
    return;
  }
  
  if (IsClientInGame(client) && IsPlayerAlive(client) && IsValidEntity(entity)) {
    CS_DropWeapon(client, entity, true, true); 
    AcceptEntityInput(entity, "Kill");
  }
}