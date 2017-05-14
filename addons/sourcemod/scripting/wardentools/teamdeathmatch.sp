/*
* Highlighted team deathmatch
* Prefix: TeamDeathmatch_
*/

#if defined _wardentools_teamdeathmatch_included
  #endinput
#endif
#define _wardentools_teamdeathmatch_included

#include <wardentools>
#include <cstrike>

#include "wardentools/highlights.sp"

static bool s_IsInHighlightTeamDM = false;

//OnPluginStart
public void TeamDeathmatch_OnPluginStart()
{
  HookEvent("player_death", TeamDeathmatch_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("round_prestart", TeamDeathmatch_Reset, EventHookMode_Post);
}

//OnClientPutInServer
public void TeamDeathmatch_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_OnTakeDamage, TeamDeathmatch_OnTakeDamage);
}

//Player death hook
public Action TeamDeathmatch_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  bool isWarden = view_as<bool>(warden_iswarden(client));
  
  //Warden just died
  if (isWarden) {
    //Cancel any active team DM's
    if (s_IsInHighlightTeamDM) {
      //Warden died so stop team DM
      TeamDeathmatch_TurnOff();
    }
  }
  
  //Check if team DM should be stopped
  if (s_IsInHighlightTeamDM) {
    //Check team counts
    int teamsLeft = TeamDeathmatch_GetNumTTeamsAlive();

    if (teamsLeft <= 1) {
      //Last team left or everybody has died, auto turn off team DM
      TeamDeathmatch_TurnOff();
    }
  }
}

//Get number of teams left alive in team DM (T Only)
int TeamDeathmatch_GetNumTTeamsAlive()
{
  //Check if at least two teams exist
  ArrayList teamsArray = new ArrayList();

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T) {
        if (Highlights_IsHighlighted(i)) {
          int index = teamsArray.FindValue(Highlights_GetHighlightedColour(i));
          
          if (index == -1)
            teamsArray.Push(Highlights_GetHighlightedColour(i));
        }
      }
    }
  }
  
  int teamsArrayLength = teamsArray.Length;
  delete teamsArray;
  
  return teamsArrayLength;
}

//Called when a player takes damage
public Action TeamDeathmatch_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim > 0 && victim <= MaxClients) || !(attacker > 0 && attacker <= MaxClients))
    return Plugin_Continue;

  if (s_IsInHighlightTeamDM) {
    
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
public void TeamDeathmatch_TurnOff()
{
  FindConVar("mp_friendlyfire").BoolValue = false;
  FindConVar("mp_teammates_are_enemies").BoolValue = false;

  s_IsInHighlightTeamDM = false;

  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Turned Off");
}

//Turn ON Team DM
public void TeamDeathmatch_TurnOn()
{
  FindConVar("mp_friendlyfire").BoolValue = true;
  FindConVar("mp_teammates_are_enemies").BoolValue = true;

  s_IsInHighlightTeamDM = true;

  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Turned On");
}

//Getters/Setters

public bool TeamDeathmatch_IsInHighlightTeamDM()
{
  return s_IsInHighlightTeamDM;
}

//Round pre start
public void TeamDeathmatch_Reset(Event event, const char[] name, bool dontBroadcast)
{
  s_IsInHighlightTeamDM = false;
}