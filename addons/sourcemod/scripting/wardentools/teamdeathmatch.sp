/*
* Highlighted team deathmatch
* Prefix: teamdeathmatch_
*/

#if defined _wardentools_teamdeathmatch_included
  #endinput
#endif
#define _wardentools_teamdeathmatch_included

#include <wardentools>
#include <cstrike>

#include "wardentools/highlights.sp"

static bool isInHighlightTeamDM = false;

//OnPluginStart
public void Teamdeathmatch_OnPluginStart()
{
  HookEvent("player_death", Teamdeathmatch_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("round_prestart", Teamdeathmatch_Reset, EventHookMode_Post);
  
  //SDKHooks
  int iMaxClients = GetMaxClients();
  
  for (int i = 1; i <= iMaxClients; ++i) {
    if (IsClientInGame(i)) {
      Teamdeathmatch_OnClientPutInServer(i);
    }
  }
}

//OnClientPutInServer
public void Teamdeathmatch_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_OnTakeDamage, Teamdeathmatch_OnTakeDamage);
}

//Player death hook
public Action Teamdeathmatch_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  bool isWarden = view_as<bool>(warden_iswarden(client));
  
  //Warden just died
  if (isWarden) {
    //Cancel any active team DM's
    if (isInHighlightTeamDM) {
      //Warden died so stop team DM
      Teamdeathmatch_TurnOff();
    }
  }
  
  //Check if team DM should be stopped
  if (isInHighlightTeamDM) {
    //Check team counts
    int teamsLeft = Teamdeathmatch_GetNumTTeamsAlive();

    if (teamsLeft <= 1) {
      //Last team left or everybody has died, auto turn off team DM
      Teamdeathmatch_TurnOff();
    }
  }
}

//Get number of teams left alive in team DM (T Only)
int Teamdeathmatch_GetNumTTeamsAlive()
{
  //Check if at least two teams exist
  ArrayList teamsArray = CreateArray(MaxClients);

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T) {
        if (Highlights_IsHighlighted(i)) {
          int index = FindValueInArray(teamsArray, Highlights_GetHighlightedColour(i));
          
          if (index == -1)
            PushArrayCell(teamsArray, Highlights_GetHighlightedColour(i));
        }
      }
    }
  }
  
  return GetArraySize(teamsArray);
}

//Called when a player takes damage
public Action Teamdeathmatch_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim > 0 && victim <= MaxClients) || !(attacker > 0 && attacker <= MaxClients))
    return Plugin_Continue;

  if (isInHighlightTeamDM) {
    
    //Check for CT's trying to kill each other
    if (GetClientTeam(victim) == CS_TEAM_CT && GetClientTeam(attacker) == CS_TEAM_CT) {
      return Plugin_Handled;
    }
    
    //Check for T's trying to kill team mates
    if (GetClientTeam(victim) == CS_TEAM_T && GetClientTeam(attacker) == CS_TEAM_T) {
      if (Highlights_IsHighlighted(victim) && Highlights_IsHighlighted(attacker)) {
        if (Highlights_GetHighlightedColour(victim) == Highlights_GetHighlightedColour(attacker)) {
          return Plugin_Handled;
        }
      }
      
      //Check for T's killing non highlighted T's
      if (!Highlights_IsHighlighted(attacker)) {
        return Plugin_Handled;
      }
      
      if (Highlights_IsHighlighted(attacker) && !Highlights_IsHighlighted(victim)) {
        return Plugin_Handled;
      }
    }
  }
  
  return Plugin_Continue;
}

//Turn off Team DM
public void Teamdeathmatch_TurnOff()
{
  SetConVarBool(FindConVar("mp_friendlyfire"), false);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), false);

  isInHighlightTeamDM = false;

  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Turned Off");
}

//Turn ON Team DM
public void Teamdeathmatch_TurnOn()
{
  SetConVarBool(FindConVar("mp_friendlyfire"), true);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);

  isInHighlightTeamDM = true;

  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Turned On");
}

//Getters/Setters

public bool Teamdeathmatch_IsInHighlightTeamDM()
{
  return isInHighlightTeamDM;
}

//Round pre start
public void Teamdeathmatch_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  isInHighlightTeamDM = false;
}