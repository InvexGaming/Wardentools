/*
* ESP Commands
* Prefix: Esp_
*
* Based on Advanced-Admin-Esp (https://github.com/MitchDizzle/Advanced-Admin-ESP/blob/1.3/scripting/csgo_advanced_esp.sp) by Mitch
*/

#if defined _wardentools_esp_included
  #endinput
#endif
#define _wardentools_esp_included

#include <wardentools>
#include <cstrike>

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_NORECEIVESHADOW          (1 << 6)

//Static globals
static bool s_IsUsingEsp[MAXPLAYERS+1] = {false, ...}; //if player has ESP
static int s_EspColour[MAXPLAYERS+1][4]; //clients esp colour
static bool s_EspCanSeeClient[MAXPLAYERS+1][MAXPLAYERS+1]; //true if player shows up for user

static int g_PlayerModels[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE,...};
static int g_PlayerModelsIndex[MAXPLAYERS+1] = {-1,...};

//ConVars
ConVar g_Cvar_sv_force_transmit_players;

//OnPluginStart
public void Esp_OnPluginStart()
{
  g_Cvar_sv_force_transmit_players = FindConVar("sv_force_transmit_players");
  Esp_Reset();
}

//Call this to show or unshow ESP
public void Esp_CheckGlows()
{
  int playersUsingEsp = 0;
  for(int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && s_IsUsingEsp[i])
      ++playersUsingEsp;
  }
  
  //Force transmit makes sure that the players can see the glow through wall correctly.
  //This is usually for alive players for the anti-wallhack made by valve.
  Esp_DestoryGlows();
  
  if (playersUsingEsp > 0) {
    g_Cvar_sv_force_transmit_players.SetString("1", true, false);
    Esp_CreateGlows();
  } else {
    g_Cvar_sv_force_transmit_players.SetString("0", true, false);
  }
}

//Completely reset the ESP state
public void Esp_Reset()
{
  for (int i = 1; i <= MaxClients; ++i) {
    s_IsUsingEsp[i] = false;
    for (int j = 1; j <= MaxClients; ++j) {
      s_EspCanSeeClient[i][j] = false;
    }
  }
  
  Esp_DestoryGlows();
}

public void Esp_CreateGlows()
{
  char model[PLATFORM_MAX_PATH];
  int skin = -1;
  
  //Loop and setup a glow on alive players.
  for(int client = 1; client <= MaxClients; client++) {
    if(!IsClientInGame(client) || !IsPlayerAlive(client))
      continue;
    
    int team = GetClientTeam(client);
    if (team == CS_TEAM_NONE || team == CS_TEAM_SPECTATOR)
      continue;
    
    //Create Skin
    GetClientModel(client, model, sizeof(model));
    skin = CreatePlayerModelProp(client, model);
    if(skin > MaxClients) {
      if(SDKHookEx(skin, SDKHook_SetTransmit, Esp_OnSetTransmit)) {
        Esp_SetupGlow(skin, s_EspColour[client]);
      }
    }
  }
}

public void Esp_DestoryGlows()
{
  for(int client = 1; client <= MaxClients; client++) {
    if(IsClientInGame(client)) {
      Esp_RemoveSkin(client);
    }
  }
}

public Action Esp_OnSetTransmit(int entity, int client)
{
  //Check to see if using esp or self entity
  if(!s_IsUsingEsp[client] || g_PlayerModelsIndex[client] == entity)
    return Plugin_Handled;
  
  //Check to see if client is allowed to see owner (target) of this entity
  for (int i = 1; i <= MaxClients; ++i) {
    if (g_PlayerModelsIndex[i] == entity) {
      if (!s_EspCanSeeClient[client][i])
        return Plugin_Handled;
        
      break;
    }
  }
  
  return Plugin_Continue;
}

public void Esp_SetupGlow(int entity, int colour[4])
{
  static int offset;
  // Get sendprop offset for prop_dynamic_override
  if (!offset && (offset = GetEntSendPropOffs(entity, "m_clrGlow")) == -1) {
    LogError("Unable to find property offset: \"m_clrGlow\"!");
    return;
  }

  // Enable glow for custom skin
  SetEntProp(entity, Prop_Send, "m_bShouldGlow", true);
  SetEntProp(entity, Prop_Send, "m_nGlowStyle", 0);
  SetEntPropFloat(entity, Prop_Send, "m_flGlowMaxDist", 10000.0);

  // So now setup given glow colours for the skin
  for(int i = 0; i < 3; i++) {
    SetEntData(entity, offset + i, colour[i], _, true); 
  }
}

public void Esp_RemoveSkin(int client)
{
  if(IsValidEntity(g_PlayerModels[client])) {
    AcceptEntityInput(g_PlayerModels[client], "Kill");
  }
  
  g_PlayerModels[client] = INVALID_ENT_REFERENCE;
  g_PlayerModelsIndex[client] = -1;
}

public int CreatePlayerModelProp(int client, char[] sModel)
{
  Esp_RemoveSkin(client);
  int skin = CreateEntityByName("prop_dynamic_override");
  DispatchKeyValue(skin, "model", sModel);
  DispatchKeyValue(skin, "disablereceiveshadows", "1");
  DispatchKeyValue(skin, "disableshadows", "1");
  DispatchKeyValue(skin, "solid", "0");
  DispatchKeyValue(skin, "spawnflags", "256");
  SetEntProp(skin, Prop_Send, "m_CollisionGroup", 0);
  DispatchSpawn(skin);
  SetEntityRenderMode(skin, RENDER_TRANSALPHA);
  SetEntityRenderColor(skin, 0, 0, 0, 0);
  SetEntProp(skin, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW);
  SetVariantString("!activator");
  AcceptEntityInput(skin, "SetParent", client, skin);
  SetVariantString("primary");
  AcceptEntityInput(skin, "SetParentAttachment", skin, skin, 0);
  g_PlayerModels[client] = EntIndexToEntRef(skin);
  g_PlayerModelsIndex[client] = skin;
  return skin;
}

//Getters/Setters
public void Esp_SetIsUsingEsp(int client, bool isUsingEsp)
{
  s_IsUsingEsp[client] = isUsingEsp;
  Esp_CheckGlows(); //refresh
}

public void Esp_SetEspColour(int client, int colour[4])
{
  s_EspColour[client] = colour;
  Esp_CheckGlows(); //refresh
}

public void Esp_SetEspCanSeeClient(int client, int target, bool canSee)
{
  s_EspCanSeeClient[client][target] = canSee;
  Esp_CheckGlows(); //refresh
}